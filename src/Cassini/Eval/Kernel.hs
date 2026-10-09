{-# LANGUAGE PatternSynonyms #-}
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
    modifySymbol,
    emitMessage,
    evaluate,
    iterations,
    spendIteration,
    withFuel,
    unwind,
    catchUnwind,
    lookupBuiltin,
    traceStep,
    kernelConfig,

    -- * State and configuration
    KernelState (..),
    emptyState,
    TraceEntry (..),
    EvalConfig (..),
    defaultConfig,

    -- * Interpreters
    runKernelPure,
    runKernelIO,
  )
where

import Cassini.Core.Expr (Expr, apply, pattern App, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Symbol (Symbol, sHold, systemSymbol)
import Cassini.Eval.Message (Message (..), MessageTag)
import Cassini.Rules (BuiltinId (..), SymbolInfo, ValueKind (OwnValue), emptyInfo, ruleSetToList, rulesOf)
import Data.IntMap.Strict qualified as IntMap
import Data.Map.Strict qualified as Map
import Data.Sequence ((|>))
import Effectful (Dispatch (Dynamic), DispatchOf, Eff, Effect, IOE, (:>))
import Effectful.Dispatch.Dynamic (EffectHandler, localSeqUnlift, reinterpret, send)
import Effectful.Error.Static (Error, runErrorNoCallStack, throwError_, tryError)
import Effectful.Reader.Static (Reader, ask, local, runReader)
import Effectful.State.Static.Local (State, evalState, get, modify, put, runState)

-- | The kernel's operations.
data Kernel :: Effect where
  -- | A symbol's attributes and rules; 'emptyInfo' for an unknown symbol.
  LookupSymbol :: Symbol -> Kernel m SymbolInfo
  ModifySymbol :: Symbol -> (SymbolInfo -> SymbolInfo) -> Kernel m ()
  EmitMessage :: Symbol -> MessageTag -> [Expr] -> Kernel m ()
  -- | The knot: the interpreter runs the evaluation sequence, counting depth.
  Evaluate :: Expr -> Kernel m Expr
  -- | Remaining fuel in this fixed point.
  Iterations :: Kernel m Int
  SpendIteration :: Kernel m ()
  -- | Run with a fresh budget, then restore the caller's, however the inner
  -- computation exits.
  WithFuel :: Int -> m a -> Kernel m a
  -- | @Throw@, @Break@, @Continue@, @Return@, @Abort[]@ (§4.13).
  Unwind :: Unwind -> Kernel m a
  -- | Observe an unwind, to catch it or to restore state and rethrow.
  CatchUnwind :: m a -> Kernel m (Either Unwind a)
  -- | Resolve a 'Cassini.Rules.Native' rule's id. 'Nothing' is a
  -- construction bug in the registry, never a user error.
  LookupBuiltin :: BuiltinId -> Kernel m (Maybe BuiltinFn)
  -- | Record one step of the evaluation sequence, when tracing is on.
  TraceStep :: Text -> Expr -> Kernel m ()
  -- | The knobs fixed during evaluation.
  KernelConfig :: Kernel m EvalConfig

type instance DispatchOf Kernel = Dynamic

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

-- | No symbols, no builtins.
emptyState :: KernelState
emptyState = KernelState Map.empty IntMap.empty mempty mempty

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

-- | A symbol's attributes and rules.
lookupSymbol :: (Kernel :> es) => Symbol -> Eff es SymbolInfo
lookupSymbol = send . LookupSymbol

-- | Change a symbol's attributes or rules.
modifySymbol :: (Kernel :> es) => Symbol -> (SymbolInfo -> SymbolInfo) -> Eff es ()
modifySymbol s = send . ModifySymbol s

-- | Emit @symbol::tag@ with its arguments.
emitMessage :: (Kernel :> es) => Symbol -> MessageTag -> [Expr] -> Eff es ()
emitMessage s t = send . EmitMessage s t

-- | Evaluate a subterm. All subterm evaluation goes through here, never
-- straight into the sequence, so the depth count cannot be bypassed.
evaluate :: (Kernel :> es) => Expr -> Eff es Expr
evaluate = send . Evaluate

-- | Remaining fuel in this fixed point.
iterations :: (Kernel :> es) => Eff es Int
iterations = send Iterations

-- | Spend one iteration.
spendIteration :: (Kernel :> es) => Eff es ()
spendIteration = send SpendIteration

-- | Run with a fresh budget of iterations, restoring the caller's after.
withFuel :: (Kernel :> es) => Int -> Eff es a -> Eff es a
withFuel n = send . WithFuel n

-- | Exit to the nearest handler.
unwind :: (Kernel :> es) => Unwind -> Eff es a
unwind = send . Unwind

-- | Run, observing any unwind.
catchUnwind :: (Kernel :> es) => Eff es a -> Eff es (Either Unwind a)
catchUnwind = send . CatchUnwind

-- | Resolve a builtin id.
lookupBuiltin :: (Kernel :> es) => BuiltinId -> Eff es (Maybe BuiltinFn)
lookupBuiltin = send . LookupBuiltin

-- | Record a step of the evaluation sequence, if tracing is on.
traceStep :: (Kernel :> es) => Text -> Expr -> Eff es ()
traceStep name = send . TraceStep name

-- | The configuration.
kernelConfig :: (Kernel :> es) => Eff es EvalConfig
kernelConfig = send KernelConfig

-- The interpreters.

-- | The handler's own environment: the configuration, and the evaluation
-- depth. Depth is a 'Reader' changed with 'local', which restores it however
-- the inner evaluation exits, a caught unwind included (§4.13).
data Env = Env {envConfig :: !EvalConfig, envDepth :: !Int}

-- | Fuel is the handler's own state, not 'KernelState': it belongs to the
-- fixed point being run, not to the session.
newtype Fuel = Fuel Int

type HandlerEs base = Reader Env : State Fuel : Error Unwind : base

-- | Where the kernel state lives: 'State' for the pure interpreter, the
-- caller's 'IORef' for the 'IO' one.
data Store es = Store
  { load :: Eff es KernelState,
    store :: (KernelState -> KernelState) -> Eff es ()
  }

handler :: Sequence -> Store (HandlerEs base) -> EffectHandler Kernel (HandlerEs base)
handler (Sequence sq) st env = \case
  LookupSymbol s -> fromMaybe emptyInfo . Map.lookup s . (.ksSymbols) <$> st.load
  ModifySymbol s f ->
    st.store $ \k -> k {ksSymbols = Map.alter (Just . f . fromMaybe emptyInfo) s k.ksSymbols}
  EmitMessage s t as -> message s t as
  Evaluate e -> do
    Env cfg d <- ask @Env
    if d >= cfg.recursionLimit
      then
        -- The cut is idempotent: what is already a cut, and what evaluates
        -- to itself (a raw atom, a symbol with no own value), comes back as
        -- it is. Otherwise every fixed point near the limit re-wraps its own
        -- result, heads included, each round, and the cuts compound.
        settled e >>= \case
          True -> pure e
          False -> do
            message (systemSymbol "$RecursionLimit") "reclim" [Int_ (toInteger cfg.recursionLimit)]
            pure (apply sHold [e])
      else local (\en -> en {envDepth = d + 1}) (localSeqUnlift env $ \unlift -> unlift (sq e))
  Iterations -> (\(Fuel n) -> n) <$> get @Fuel
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
    Env cfg d <- ask @Env
    when cfg.trace $ st.store $ \k -> k {ksTrace = k.ksTrace |> TraceEntry d name e}
  KernelConfig -> (\en -> en.envConfig) <$> ask @Env
  where
    settled = \case
      Num _ -> pure True
      Str _ -> pure True
      Sym s -> null . ruleSetToList . rulesOf OwnValue . fromMaybe emptyInfo . Map.lookup s . (.ksSymbols) <$> st.load
      App (Sym h) _ -> pure (h == sHold)
      App _ _ -> pure False
    message s t as = st.store $ \k -> k {ksMessages = k.ksMessages |> Message s t as}

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
    (runState s0 . runErrorNoCallStack . evalState (Fuel cfg.iterationLimit) . runReader (Env cfg 0))
    (handler sq Store {load = get, store = modify})

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
  reinterpret
    (runErrorNoCallStack . evalState (Fuel cfg.iterationLimit) . runReader (Env cfg 0))
    (handler sq Store {load = readIORef ref, store = modifyIORef' ref})
