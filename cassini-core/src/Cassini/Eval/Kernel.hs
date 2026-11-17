{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

-- | The 'Kernel' effect, the kernel state, and the two interpreters
-- (DESIGN.md §4.3, §4.13).
--
-- The kernel is a custom, dynamically dispatched @effectful@ effect. Kernel
-- code is constraint-polymorphic over it, so the matcher and the builtins can
-- evaluate through 'evaluate' without importing the evaluation sequence,
-- which lives above them in "Cassini.Eval". The interpreters therefore take
-- the sequence as an argument; "Cassini.Eval" ties the knot.
--
-- 'runKernelPure' has no 'IOE', so under 'Effectful.runPureEff' the type
-- checker guarantees the evaluator under test is a pure function from a state
-- and an expression to a state and an expression.
module Cassini.Eval.Kernel
  ( -- * The effect
    Kernel (..),
    Sequence (..),
    BuiltinFn (..),
    Unwind (..),
    Abort (..),

    -- * Operations
    lookupSymbol,
    lookupAttributes,
    modifySymbol,
    emitMessage,
    evaluate,
    evaluateRhs,
    evaluatePart,
    iterations,
    spendIteration,
    withFuel,
    unwind,
    catchUnwind,
    lookupBuiltin,
    traceStep,
    kernelConfig,
    terminated,

    -- * State and configuration
    KernelState (..),
    emptyState,
    symbolEntry,
    TraceEntry (..),
    EvalConfig (..),
    defaultConfig,

    -- * Interpreters
    runKernelPure,
    runKernelIO,
    runKernelInterruptible,
  )
where

import Cassini.Attributes (AttributeSet)
import Cassini.Core.Expr (Expr, apply, pattern Int_, pattern Str)
import Cassini.Core.Symbol (Symbol, systemSymbol)
import Cassini.Eval.Message (Message (..), MessageTag)
import Cassini.Rules (BuiltinId (..), SymbolInfo (..), emptyInfo)
import Data.IntMap.Strict qualified as IntMap
import Data.Map.Strict qualified as Map
import Data.Sequence ((|>))
import Effectful (Eff, Effect, IOE, (:>))
import Effectful.Dispatch.Dynamic (EffectHandler, LocalEnv, localSeqUnlift, reinterpret)
import Effectful.Error.Static (Error, runErrorNoCallStack, throwError_, tryError)
import Effectful.Reader.Static (Reader, ask, asks, local, runReader)
import Effectful.State.Static.Local (State, evalState, get, modify, put, runState)
import Effectful.TH (makeEffect)
import Optics.Core (Lens', at, lens, view, (%), (%~))

-- | The kernel's operations.
data Kernel :: Effect where
  -- | A symbol's attributes and rules; 'emptyInfo' for an unknown symbol.
  LookupSymbol :: Symbol -> Kernel m SymbolInfo
  -- | Change a symbol's attributes or rules.
  ModifySymbol :: Symbol -> (SymbolInfo -> SymbolInfo) -> Kernel m ()
  -- | Emit @symbol::tag@ with its arguments.
  EmitMessage :: Symbol -> MessageTag -> [Expr] -> Kernel m ()
  -- | Evaluate a subterm. This is the knot: the interpreter runs the
  -- evaluation sequence, counting depth. All subterm evaluation goes
  -- through here or its two variants below, never straight into the
  -- sequence, so the depth count cannot be bypassed. To the recursion
  -- limit's unwinding, an evaluation that asks for another by this
  -- operation has left the standard chain (§4.3).
  Evaluate :: Expr -> Kernel m Expr
  -- | Evaluate the head or an unheld argument of an evaluation that is still
  -- on the standard chain (steps 2 and 3, and the top-level input). It
  -- does not count as leaving it, as 'Evaluate' does (§4.3).
  EvaluatePart :: Expr -> Kernel m Expr
  -- | Evaluate a user rule's instantiated right-hand side, as the
  -- continuation of the evaluation whose rule fired rather than as a new
  -- one: it counts depth as 'Evaluate' does, but to the recursion limit's
  -- unwinding it is the same evaluation, which has left the chain (§4.3).
  EvaluateRhs :: Expr -> Kernel m Expr
  -- | Remaining fuel in this fixed point.
  Iterations :: Kernel m Int
  -- | Spend one iteration.
  SpendIteration :: Kernel m ()
  -- | Run with a fresh budget, then restore the caller's, however the inner
  -- computation exits.
  WithFuel :: Int -> m a -> Kernel m a
  -- | Exit to the nearest handler: @Throw@, @Break@, @Continue@, @Return@,
  -- @Abort[]@ (§4.13).
  Unwind :: Unwind -> Kernel m a
  -- | Run, observing any unwind, to catch it or to restore state and
  -- rethrow.
  CatchUnwind :: m a -> Kernel m (Either Unwind a)
  -- | Resolve a 'Cassini.Rules.Native' rule's id. 'Nothing' is a
  -- construction bug in the registry, never a user error.
  LookupBuiltin :: BuiltinId -> Kernel m (Maybe BuiltinFn)
  -- | Record one step of the evaluation sequence, when tracing is on.
  TraceStep :: Text -> Expr -> Kernel m ()
  -- | The knobs fixed during evaluation.
  KernelConfig :: Kernel m EvalConfig

-- | The evaluation sequence, supplied by "Cassini.Eval".
newtype Sequence = Sequence (forall es. (Kernel :> es) => Expr -> Eff es Expr)

-- | A builtin's implementation: 'Nothing' when it does not apply, so that
-- the next rule, or none, gets its turn.
newtype BuiltinFn = BuiltinFn (forall es. (Kernel :> es) => Expr -> Eff es (Maybe Expr))

-- | A non-local exit (§4.13).
data Unwind
  = -- | value, tag, and @Throw@'s third argument
    UThrow !Expr !(Maybe Expr) !(Maybe Expr)
  | UBreak
  | UContinue
  | -- | caught by the innermost loop or user-rule application (D23)
    UReturn !Expr
  | -- | a limit, by name, and how many evaluations enclosing the one it
    -- last left had left the standard chain: caught where the recursion
    -- limit's unwinding rule says, and at the top (§4.3, D30)
    UTerminated !Text !Int
  | -- | nothing handles it; it stops evaluation
    UAbort !Abort
  deriving stock (Show)

-- | Why evaluation was aborted.
data Abort
  = -- | @Abort[]@
    AbortCall
  | -- | a user interrupt, raised at a safe point
    Interrupt
  deriving stock (Eq, Show)

-- | One entry of a golden trace: which step changed the expression, at which
-- evaluation depth, and what it became.
data TraceEntry = TraceEntry
  { teDepth :: !Int,
    teStep :: !Text,
    teExpr :: !Expr
  }
  deriving stock (Show)

-- | The symbol table, the builtin implementations, and what evaluation has
-- produced for the front end to drain: messages and the trace.
data KernelState = KernelState
  { ksSymbols :: !(Map Symbol SymbolInfo),
    ksBuiltins :: !(IntMap BuiltinFn),
    ksMessages :: !(Seq Message),
    ksTrace :: !(Seq TraceEntry)
  }
  deriving stock (Generic)

-- | No symbols, no builtins.
emptyState :: KernelState
emptyState = KernelState Map.empty IntMap.empty mempty mempty

-- | A symbol's entry: 'emptyInfo' for an unknown symbol, and a write always
-- stores, so a symbol once written stays in the table even if its entry
-- returns to empty. INLINE, for the reason 'Cassini.Rules.rulesAt' gives.
symbolEntry :: Symbol -> Lens' KernelState SymbolInfo
symbolEntry s = #ksSymbols % at s % lens (fromMaybe emptyInfo) (const Just)
{-# INLINE symbolEntry #-}

-- | The knobs fixed during evaluation.
data EvalConfig = EvalConfig
  { -- | @$RecursionLimit@: the maximum depth of the evaluation stack.
    recursionLimit :: !Int,
    -- | @$IterationLimit@: the maximum length of one fixed point.
    iterationLimit :: !Int,
    -- | Whether 'traceStep' records.
    trace :: !Bool
  }
  deriving stock (Show)

-- | The language's defaults, 1024 and 4096, with tracing off.
defaultConfig :: EvalConfig
defaultConfig = EvalConfig {recursionLimit = 1024, iterationLimit = 4096, trace = False}

-- The operations, one per constructor, each documented by its constructor's
-- comment.
makeEffect ''Kernel

-- | @TerminatedEvaluation[reason]@: what a limit leaves where it cut (§4.3).
terminated :: Text -> Expr
terminated reason = apply (systemSymbol "TerminatedEvaluation") [Str reason]

-- | A symbol's attributes; none for an unknown symbol.
lookupAttributes :: (Kernel :> es) => Symbol -> Eff es AttributeSet
lookupAttributes s = (.siAttributes) <$> lookupSymbol s
{-# INLINE lookupAttributes #-}

-- The interpreters.

-- | The handler's own environment: the configuration, the evaluation depth,
-- and where the evaluation stands on the standard chain. All are a 'Reader'
-- changed with 'local', which restores them however the inner evaluation
-- exits, a caught unwind included (§4.13).
--
-- Where the evaluation stands on the standard chain (§4.3) is two fields:
-- how many of the evaluations enclosing it have left the chain, up to 2, and
-- whether it has itself, which only a rule's right-hand side starts out
-- having done. The recursion limit replaces the evaluation that leaves the
-- chain with 'envOff' 1: the second on the path to the cut to leave it.
data Env = Env
  { envConfig :: !EvalConfig,
    envDepth :: !Int,
    envOff :: !Int,
    envLeft :: !Bool
  }

-- | Fuel is the handler's own state, not 'KernelState': it belongs to the
-- fixed point being run, not to the session.
newtype Fuel = Fuel Int

type HandlerEs base = Reader Env : State Fuel : Error Unwind : base

-- | Where the kernel state lives: 'State' for the pure interpreter, the
-- caller's 'IORef' for the 'IO' one.
data Store es = Store
  { load :: Eff es KernelState,
    store :: (KernelState -> KernelState) -> Eff es (),
    -- | Whether an interrupt is pending, clearing it: polled at every
    -- 'Evaluate', the safe point where it becomes @UAbort Interrupt@
    -- (§4.13).
    poll :: Eff es Bool
  }

handler :: Sequence -> Store (HandlerEs base) -> EffectHandler Kernel (HandlerEs base)
handler (Sequence sq) st env = \case
  LookupSymbol s -> symbolInfo st s
  ModifySymbol s f ->
    st.store (symbolEntry s %~ f)
  EmitMessage s t as -> message st s t as
  -- A new evaluation, from one that has left the chain by asking for it.
  Evaluate e -> ask @Env >>= \en -> descend sq st env e en (min 2 (en.envOff + 1)) False
  -- A new evaluation, from one still on the chain; or, from one that has
  -- left it, as 'Evaluate'.
  EvaluatePart e -> ask @Env >>= \en -> descend sq st env e en (if en.envLeft then min 2 (en.envOff + 1) else en.envOff) False
  -- The same evaluation, continued.
  EvaluateRhs e -> ask @Env >>= \en -> descend sq st env e en en.envOff True
  Iterations -> coerce <$> get @Fuel
  SpendIteration -> modify @Fuel (\(Fuel n) -> Fuel (n - 1))
  WithFuel n m -> do
    old <- get @Fuel
    put (Fuel n)
    r <- tryError @Unwind (localSeqUnlift env $ \unlift -> unlift m)
    put old
    either (throwError_ . snd) pure r
  Unwind u -> throwError_ u
  CatchUnwind m -> first snd <$> tryError @Unwind (localSeqUnlift env $ \unlift -> unlift m)
  LookupBuiltin (BuiltinId i) -> IntMap.lookup i . (.ksBuiltins) <$> st.load
  TraceStep name e -> do
    en <- ask @Env
    when en.envConfig.trace $ st.store (#ksTrace %~ (|> TraceEntry en.envDepth name e))
  KernelConfig -> asks @Env (.envConfig)

-- | Evaluate, a step deeper, entered where the chain is as given. At the
-- limit, the message once, and an unwind that an enclosing evaluation or
-- the top-level entry turns into TerminatedEvaluation.
--
-- The evaluation that catches it is the second on the path to leave the
-- chain (§4.3): one entered with one enclosing evaluation off the chain,
-- which has since left it itself. It has left it if the unwind comes out of
-- an evaluation it asked for with two off the chain, since what it asks for
-- before it leaves has one. So only an evaluation entered with one installs
-- a catch, and the unwind carries the count it came out of.
--
-- Top-level, as 'message' is: a helper in the handler's @where@ is a
-- closure allocated on every operation the handler runs, which cost 7% of
-- the end-to-end workload's allocation.
descend ::
  (Kernel :> localEs) =>
  (forall es. (Kernel :> es) => Expr -> Eff es Expr) ->
  Store (HandlerEs base) ->
  LocalEnv localEs (HandlerEs base) ->
  Expr ->
  Env ->
  Int ->
  Bool ->
  Eff (HandlerEs base) Expr
descend sq st env e en off left = do
  interrupted <- st.poll
  when interrupted $ throwError_ (UAbort Interrupt)
  if
    | en.envDepth >= en.envConfig.recursionLimit -> do
        message st (systemSymbol "$RecursionLimit") "reclim" [Int_ (toInteger en.envConfig.recursionLimit)]
        throwError_ (UTerminated "RecursionLimit" off)
    | off == 1 && not left ->
        tryError @Unwind run >>= \case
          Right v -> pure v
          Left (_, UTerminated reason from)
            | from >= 2 -> pure (terminated reason)
            | otherwise -> throwError_ (UTerminated reason 1)
          Left (_, u) -> throwError_ u
    | otherwise -> run
  where
    run = local (const en {envDepth = en.envDepth + 1, envOff = off, envLeft = left}) (localSeqUnlift env $ \unlift -> unlift (sq e))

-- | Queue a message for the front end.
message :: Store es -> Symbol -> MessageTag -> [Expr] -> Eff es ()
message st s t as = st.store (#ksMessages %~ (|> Message s t as))

-- | A symbol's entry in the stored state; 'emptyInfo' for an unknown one.
--
-- This, 'runHandlerEs' and 'ioStore' are INLINE: out of line, the handler
-- calls through an unknown 'Store' on every 'LookupSymbol', and the
-- end-to-end benchmark runs 7% slower, with no change in allocation.
symbolInfo :: Store es -> Symbol -> Eff es SymbolInfo
symbolInfo st s = view (symbolEntry s) <$> st.load
{-# INLINE symbolInfo #-}

-- | Discharge the handler's own effects: depth from 0, a fresh fuel budget,
-- and the unwind channel, which every interpreter returns.
runHandlerEs :: EvalConfig -> Eff (HandlerEs base) a -> Eff base (Either Unwind a)
runHandlerEs cfg = runErrorNoCallStack . evalState (Fuel cfg.iterationLimit) . runReader (Env cfg 0 0 False)
{-# INLINE runHandlerEs #-}

-- | The pure interpreter: introduces and discharges 'Reader', 'State' and
-- 'Error', and returns the final state beside the result. State changes made
-- before an unwind persist (§4.13).
runKernelPure ::
  Sequence ->
  EvalConfig ->
  KernelState ->
  Eff (Kernel : es) a ->
  Eff es (Either Unwind a, KernelState)
runKernelPure sq cfg s0 =
  reinterpret
    (runState s0 . runHandlerEs cfg)
    (handler sq Store {load = get, store = modify, poll = pure False})

-- | The 'IO' interpreter: the state is the caller's 'IORef', so it returns
-- none. The REPL's session state.
runKernelIO ::
  (IOE :> es) =>
  Sequence ->
  EvalConfig ->
  IORef KernelState ->
  Eff (Kernel : es) a ->
  Eff es (Either Unwind a)
runKernelIO sq cfg ref =
  reinterpret (runHandlerEs cfg) (handler sq (ioStore ref (pure False)))

-- | 'runKernelIO' that polls an interrupt flag at every evaluation step. The
-- REPL's handler for Ctrl-C only sets the flag, and the next 'Evaluate'
-- clears it and raises @UAbort Interrupt@ through the ordinary channel, so
-- an interrupt is an @Abort[]@ at a safe point (§4.13).
runKernelInterruptible ::
  (IOE :> es) =>
  Sequence ->
  EvalConfig ->
  IORef KernelState ->
  IORef Bool ->
  Eff (Kernel : es) a ->
  Eff es (Either Unwind a)
runKernelInterruptible sq cfg ref flag =
  reinterpret (runHandlerEs cfg) (handler sq (ioStore ref poll))
  where
    -- A plain read at every step, and the atomic clear only when one is
    -- pending.
    poll = readIORef flag >>= \pending -> if pending then atomicModifyIORef' flag (False,) else pure False

-- | The state in the caller's 'IORef', with the given interrupt poll.
ioStore :: (IOE :> es) => IORef KernelState -> Eff es Bool -> Store es
ioStore ref poll = Store {load = readIORef ref, store = modifyIORef' ref, poll}
{-# INLINE ioStore #-}
