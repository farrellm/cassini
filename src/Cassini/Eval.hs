{-# LANGUAGE PatternSynonyms #-}

-- | The standard evaluation sequence, the fixed-point loop, and the
-- knot-tied interpreters (DESIGN.md §4.4).
--
-- Source: @references/papers/wolfram-language/wolfram_ref_evaluation.html@,
-- "The Standard Evaluation Sequence". The numbering is this repository's;
-- @references/papers/wolfram-language/CLAUDE.md@ relates it to the page's
-- unnumbered bullets.
--
-- Each step is a named function, applied in a fixed order, so the easy
-- mistakes (attribute order, @Sequence@ before @Unevaluated@, the four-way
-- ladder) are structurally impossible. Where the code is not the list read
-- literally, §4.4 says why: steps 1 and 0 are guards; steps 3 and 4 are one
-- pass; "the attributes of @h@" is 'headAttributes'; 'evalStepIndet' sits
-- between steps 9 and 10; and a user rule evaluates its own right-hand side.
module Cassini.Eval
  ( -- * Evaluation
    evalSequence,
    evaluateTop,
    runEvalPure,
    runEvalIO,

    -- * The steps, exported for their unit tests
    Node (..),
    nodeExpr,
    headAttributes,
    evalStep1Raw,
    evalStep0Own,
    evalStep2Head,
    evalStep4Hold,
    evalStep3Args,
    evalStep34ArgsHold,
    evalStep5Seq,
    evalStep6Uneval,
    evalStep7Flat,
    evalStep8List,
    evalStep9Order,
    evalStepIndet,
    evalStep10UserUp,
    evalStep11BuiltinUp,
    evalStep12UserDown,
    evalStep13BuiltinDown,
    restoreUneval,
    fixpoint,
  )
where

import Cassini.Attributes
  ( AttributeSet,
    attributeFromName,
    attributeSet,
    holdAllComplete,
    holdsArgument,
    isFlat,
    isListable,
    isNumericFunction,
    isOrderless,
    sequenceHold,
  )
import Cassini.Core.Expr (Expr, apply, exprArgs, mkApp, pattern App, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Order (compareCanonical)
import Cassini.Core.Symbol
  ( Symbol,
    sEvaluate,
    sFunction,
    sHold,
    sIndeterminate,
    sList,
    sSequence,
    sUnevaluated,
    symName,
    systemSymbol,
  )
import Cassini.Eval.Kernel
  ( BuiltinFn (..),
    EvalConfig (..),
    Kernel,
    KernelState,
    Sequence (..),
    Unwind (..),
    catchUnwind,
    emitMessage,
    evaluate,
    iterations,
    kernelConfig,
    lookupBuiltin,
    lookupSymbol,
    runKernelIO,
    runKernelPure,
    spendIteration,
    traceStep,
    unwind,
    withFuel,
  )
import Cassini.Pattern (applySubst)
import Cassini.Pattern.Match (matchOne)
import Cassini.Rules (BuiltinId, Origin (..), Rule (..), RuleBody (..), SymbolInfo (..), ValueKind (..), applicableRules, ladder)
import Data.Vector qualified as V
import Effectful (Eff, IOE, (:>))

-- | An application part-way through the sequence: its evaluated head, its
-- arguments as the steps leave them, the head's attributes, and the values
-- step 6 stripped of their @Unevaluated@ wrappers.
data Node = Node
  { nodeHead :: !Expr,
    nodeArgs :: !(V.Vector Expr),
    nodeAttrs :: !AttributeSet,
    nodeStripped :: ![Expr]
  }

-- | The expression the node stands for now.
nodeExpr :: Node -> Expr
nodeExpr n = mkApp n.nodeHead n.nodeArgs

-- | The evaluation sequence, to a fixed point: every time the expression
-- changes, start over.
evalSequence :: (Kernel :> es) => Expr -> Eff es Expr
evalSequence = fixpoint step
  where
    -- Steps 1 and 0 are guards on the other twelve, not stages before them.
    step e
      | evalStep1Raw e = pure e
      | Sym s <- e = evalStep0Own s
      | App h as <- e = do
          n <-
            evalStep2Head h as
              >>= evalStep34ArgsHold
              >>= evalStep5Seq
              >>= evalStep6Uneval
              >>= evalStep7Flat
          evalStep8List n >>= \case
            Left threaded -> pure threaded
            Right n' ->
              evalStep9Order n' >>= evalStepIndet >>= \case
                Left indeterminate -> pure indeterminate
                Right n'' -> do
                  fired <- firstJustM ($ n'') [evalStep10UserUp, evalStep11BuiltinUp, evalStep12UserDown, evalStep13BuiltinDown]
                  pure (fromMaybe (restoreUneval n'') fired)
      | otherwise = pure e

-- | The fixed point, fuelled: one iteration per round, from a fresh budget
-- restored on exit. On exhaustion, @$IterationLimit::itlim@ and the
-- expression in @Hold@: non-termination is a user error, so it gets a
-- message, not an exception (§4.4).
fixpoint :: (Kernel :> es) => (Expr -> Eff es Expr) -> Expr -> Eff es Expr
fixpoint f e0 = do
  cfg <- kernelConfig
  let go e = do
        left <- iterations
        if left <= 0
          then do
            emitMessage (systemSymbol "$IterationLimit") "itlim" [Int_ (toInteger cfg.iterationLimit)]
            pure (apply sHold [e])
          else do
            spendIteration
            e' <- f e
            if e' == e then pure e else go e'
  withFuel cfg.iterationLimit (go e0)

-- | Step 1: a raw object (number, string) is left unchanged.
evalStep1Raw :: Expr -> Bool
evalStep1Raw = \case
  Num _ -> True
  Str _ -> True
  _ -> False

-- | "Step 0": a bare symbol takes its first applicable @OwnValue@, user
-- before built-in. The fixed point re-enters with the result, so
-- @x = y; y = 5; x@ reaches 5.
evalStep0Own :: (Kernel :> es) => Symbol -> Eff es Expr
evalStep0Own s = do
  let e = Sym s
  info <- lookupSymbol s
  fired <- firstJustM (\o -> firstJustM (ownRule e) (toList (applicableRules info (OwnValue, o) e))) [User, Builtin]
  case fired of
    Just v -> v <$ traceStep "0 OwnValue" v
    Nothing -> pure e
  where
    ownRule e r = case r.ruleBody of
      Native bid -> runNative bid e
      Immediate body -> fmap (`applySubst` body) <$> matchOne r.ruleLhs e
      Delayed body -> fmap (`applySubst` body) <$> matchOne r.ruleLhs e

-- | Step 2: evaluate the head, and read its attributes.
evalStep2Head :: (Kernel :> es) => Expr -> V.Vector Expr -> Eff es Node
evalStep2Head h as = do
  h' <- evaluate h
  when (h' /= h) $ traceStep "2 Head" (mkApp h' as)
  attrs <- headAttributes h'
  pure Node {nodeHead = h', nodeArgs = as, nodeAttrs = attrs, nodeStripped = []}

-- | "The attributes of @h@" for steps 4–9: a symbol's own; for
-- @Function[_, _, attrs]@, @attrs@, one attribute or a list (§4.13); none
-- for any other compound head.
headAttributes :: (Kernel :> es) => Expr -> Eff es AttributeSet
headAttributes = \case
  Sym s -> (\si -> si.siAttributes) <$> lookupSymbol s
  App (Sym f) as | f == sFunction, [_, _, attrs] <- V.toList as -> pure (functionAttributes attrs)
  _ -> pure mempty
  where
    functionAttributes = \case
      Sym a -> attributeSet (maybeToList (attributeFromName a.symName))
      App (Sym l) xs | l == sList -> attributeSet [a | Sym x <- V.toList xs, Just a <- [attributeFromName x.symName]]
      _ -> mempty

-- | Step 4: which arguments are held, by 1-based position.
evalStep4Hold :: Node -> V.Vector Bool
evalStep4Hold n = V.generate k (\i -> holdsArgument n.nodeAttrs (i + 1) k)
  where
    k = V.length n.nodeArgs

-- | Step 3: evaluate each argument the mask does not hold, in turn. A held
-- argument wrapped in @Evaluate@ is evaluated anyway, unless @h@ has
-- @HoldAllComplete@: what @Evaluate@ is for.
evalStep3Args :: (Kernel :> es) => V.Vector Bool -> Node -> Eff es Node
evalStep3Args held n = do
  as' <- V.zipWithM arg held n.nodeArgs
  let n' = n {nodeArgs = as'}
  when (as' /= n.nodeArgs) $ traceStep "3 Arguments" (nodeExpr n')
  pure n'
  where
    arg h a
      | not h = evaluate a
      | not (holdAllComplete n.nodeAttrs), App (Sym s) _ <- a, s == sEvaluate = evaluate a
      | otherwise = pure a

-- | Steps 3 and 4, one pass: step 4 is a gate on step 3, not a stage after
-- it. Evaluating everything and then deciding what was held would give
-- @Hold[2]@ for @Hold[1+1]@.
evalStep34ArgsHold :: (Kernel :> es) => Node -> Eff es Node
evalStep34ArgsHold n = do
  let held = evalStep4Hold n
  when (V.or held) $ traceStep "4 Hold" (nodeExpr n)
  evalStep3Args held n

-- | Step 5: unless @SequenceHold@ or @HoldAllComplete@, splice @Sequence@
-- arguments.
evalStep5Seq :: (Kernel :> es) => Node -> Eff es Node
evalStep5Seq n
  | sequenceHold n.nodeAttrs || not (V.any isSequence n.nodeArgs) = pure n
  | otherwise = changed "5 Sequence" n {nodeArgs = V.concatMap splice n.nodeArgs}
  where
    isSequence = \case
      App (Sym s) _ -> s == sSequence
      _ -> False
    splice a = if isSequence a then exprArgs a else V.singleton a

-- | Step 6: unless @HoldAllComplete@, strip the outermost @Unevaluated@ from
-- each argument, recording the value. If no rule fires, 'restoreUneval' puts
-- the wrappers back, so @f[Unevaluated[1+1]]@ evaluates to itself.
evalStep6Uneval :: (Kernel :> es) => Node -> Eff es Node
evalStep6Uneval n
  | holdAllComplete n.nodeAttrs || null stripped = pure n
  | otherwise = changed "6 Unevaluated" n {nodeArgs = V.map strip n.nodeArgs, nodeStripped = stripped}
  where
    unevaluated = \case
      App (Sym s) xs | s == sUnevaluated, [x] <- V.toList xs -> Just x
      _ -> Nothing
    strip a = fromMaybe a (unevaluated a)
    stripped = mapMaybe unevaluated (V.toList n.nodeArgs)

-- | Step 7: if @h@ has @Flat@, flatten nested expressions with head @h@.
-- Traced whenever the attribute applies, so a trace shows the step order
-- even where flattening changes nothing.
evalStep7Flat :: (Kernel :> es) => Node -> Eff es Node
evalStep7Flat n
  | not (isFlat n.nodeAttrs) = pure n
  | otherwise = changed "7 Flat" n {nodeArgs = if V.any nested n.nodeArgs then V.concatMap flatten n.nodeArgs else n.nodeArgs}
  where
    nested = \case
      App h _ -> h == n.nodeHead
      _ -> False
    flatten a = if nested a then V.concatMap flatten (exprArgs a) else V.singleton a

-- | Step 8: if @h@ has @Listable@, thread over list arguments, which must
-- all have one length. The threaded list is a new expression, and the fixed
-- point evaluates it next round. Lists of different lengths are
-- @Thread::tdlen@, and the expression is left as it is.
evalStep8List :: (Kernel :> es) => Node -> Eff es (Either Expr Node)
evalStep8List n
  | not (isListable n.nodeAttrs) = pure (Right n)
  | otherwise = case ordNub (mapMaybe listLength (V.toList n.nodeArgs)) of
      [] -> pure (Right n)
      [k] -> do
        let threaded = apply sList [mkApp n.nodeHead (V.map (nth i) n.nodeArgs) | i <- [0 .. k - 1]]
        Left threaded <$ traceStep "8 Listable" threaded
      _ -> Right n <$ emitMessage (systemSymbol "Thread") "tdlen" [nodeExpr n]
  where
    listLength = \case
      App (Sym l) xs | l == sList -> Just (V.length xs)
      _ -> Nothing
    nth i a = case a of
      App (Sym l) xs | l == sList, Just x <- xs V.!? i -> x
      _ -> a

-- | Step 9: if @h@ has @Orderless@, sort the arguments into canonical order.
-- Traced whenever the attribute applies, as step 7 is.
evalStep9Order :: (Kernel :> es) => Node -> Eff es Node
evalStep9Order n
  | not (isOrderless n.nodeAttrs) = pure n
  | otherwise = changed "9 Orderless" n {nodeArgs = sorted}
  where
    sorted = V.fromList (sortBy compareCanonical (V.toList n.nodeArgs))

-- | Between steps 9 and 10, and not on the source's list: a
-- @NumericFunction@ with an @Indeterminate@ argument is @Indeterminate@
-- (§4.15). After step 8, so threading happens first; before every rung, so
-- no rule sees an @Indeterminate@ argument of a numeric function.
evalStepIndet :: (Kernel :> es) => Node -> Eff es (Either Expr Node)
evalStepIndet n
  | isNumericFunction n.nodeAttrs && V.elem indeterminate n.nodeArgs =
      Left indeterminate <$ traceStep "Indeterminate" indeterminate
  | otherwise = pure (Right n)
  where
    indeterminate = Sym sIndeterminate

-- | Step 10: unless @HoldAllComplete@, user upvalues.
evalStep10UserUp :: (Kernel :> es) => Node -> Eff es (Maybe Expr)
evalStep10UserUp = rung 0 "10 UserUpValue"

-- | Step 11: unless @HoldAllComplete@, built-in upvalues.
evalStep11BuiltinUp :: (Kernel :> es) => Node -> Eff es (Maybe Expr)
evalStep11BuiltinUp = rung 1 "11 BuiltinUpValue"

-- | Step 12: user downvalues, or subvalues for @h[…][…]@.
evalStep12UserDown :: (Kernel :> es) => Node -> Eff es (Maybe Expr)
evalStep12UserDown = rung 2 "12 UserDownValue"

-- | Step 13: built-in downvalues, or subvalues for @h[…][…]@.
evalStep13BuiltinDown :: (Kernel :> es) => Node -> Eff es (Maybe Expr)
evalStep13BuiltinDown = rung 3 "13 BuiltinDownValue"

-- | The @i@th rung of 'ladder', which is the only list of rungs: each named
-- step reads its rung from it rather than restating it (§4.2).
rung :: (Kernel :> es) => Int -> Text -> Node -> Eff es (Maybe Expr)
rung i name n = case drop i (ladder e) of
  (UpValue, _) : _ | holdAllComplete n.nodeAttrs -> pure Nothing
  (UpValue, o) : _ -> firstJustM (\s -> fromTable s (UpValue, o)) (ordNub (mapMaybe tagSymbol (V.toList n.nodeArgs)))
  (k, o) : _ -> maybe (pure Nothing) (\s -> fromTable s (k, o)) (tagSymbol e)
  [] -> pure Nothing
  where
    e = nodeExpr n
    fromTable s r = do
      info <- lookupSymbol s
      firstJustM (\rule -> applyRule name rule e) (toList (applicableRules info r e))

-- | The symbol an expression's rules are keyed on: the symbol itself, or the
-- innermost head symbol of an application (@f@ for @f[x][y]@).
tagSymbol :: Expr -> Maybe Symbol
tagSymbol = \case
  Sym s -> Just s
  App h _ -> tagSymbol h
  _ -> Nothing

-- | Apply one rule, if it matches. A user rule evaluates its own
-- instantiated right-hand side, inside 'catchUnwind', and turns a caught
-- @Return@ into its value: this is where @Return@ is caught (§4.4, §4.13). A
-- built-in rule is Haskell, and returns as the list says. The trace records
-- what the rule produced: a built-in's result, a user rule's right-hand side
-- before it is evaluated.
applyRule :: (Kernel :> es) => Text -> Rule -> Expr -> Eff es (Maybe Expr)
applyRule name r e = case r.ruleBody of
  Native bid -> runNative bid e >>= \fired -> fired <$ for_ fired (traceStep name)
  Immediate body -> user body
  Delayed body -> user body
  where
    user body =
      matchOne r.ruleLhs e >>= \case
        Nothing -> pure Nothing
        Just sigma -> do
          let rhs = applySubst sigma body
          traceStep name rhs
          catchUnwind (evaluate rhs) >>= \case
            Right v -> pure (Just v)
            Left (UReturn v) -> pure (Just v)
            Left u -> unwind u

-- | Run a builtin. It fires only if it changes the expression, so step 6's
-- restoration and the trace stay honest.
runNative :: (Kernel :> es) => BuiltinId -> Expr -> Eff es (Maybe Expr)
runNative bid e =
  lookupBuiltin bid >>= \case
    Nothing -> pure Nothing
    Just (BuiltinFn f) -> (\r -> r >>= \x -> if x == e then Nothing else Just x) <$> f e

-- | No rung fired: put back the @Unevaluated@ wrappers step 6 stripped, by
-- value, since steps 7–9 may have moved the arguments.
restoreUneval :: Node -> Expr
restoreUneval n
  | null n.nodeStripped = nodeExpr n
  | otherwise = mkApp n.nodeHead (V.fromList (go n.nodeStripped (V.toList n.nodeArgs)))
  where
    go [] as = as
    go _ [] = []
    go pending (a : as) = case break (== a) pending of
      (before, _ : after) -> apply sUnevaluated [a] : go (before ++ after) as
      (_, []) -> a : go pending as

-- | Trace a step that applied, with the node it left.
changed :: (Kernel :> es) => Text -> Node -> Eff es Node
changed name n = n <$ traceStep name (nodeExpr n)

firstJustM :: (Monad m) => (a -> m (Maybe b)) -> [a] -> m (Maybe b)
firstJustM f = \case
  [] -> pure Nothing
  x : xs -> f x >>= maybe (firstJustM f xs) (pure . Just)

-- | Evaluate one top-level input. An unwind that escapes every handler is
-- converted here, where there is an expression to build: an uncaught @Throw@
-- becomes @Hold[Throw[…]]@ with @Throw::nocatch@, and a stray @Break[]@,
-- @Continue[]@ or @Return[…]@ comes back @Hold@-wrapped, so evaluating the
-- result again does not unwind again (§4.13). An abort passes through.
evaluateTop :: (Kernel :> es) => Expr -> Eff es Expr
evaluateTop e =
  catchUnwind (evaluate e) >>= \case
    Right v -> pure v
    Left u -> case u of
      UThrow v tag f -> do
        let thrown = apply sThrow (v : maybeToList tag)
        emitMessage sThrow "nocatch" [thrown]
        pure $ case (f, tag) of
          (Just g, Just t) -> mkApp g (V.fromList [v, t])
          _ -> apply sHold [thrown]
      UBreak -> pure (apply sHold [apply (systemSymbol "Break") []])
      UContinue -> pure (apply sHold [apply (systemSymbol "Continue") []])
      UReturn v -> pure (apply sHold [apply (systemSymbol "Return") [v]])
      UAbort a -> unwind (UAbort a)
  where
    sThrow = systemSymbol "Throw"

-- | The pure evaluator: 'runKernelPure' with the knot tied.
runEvalPure :: EvalConfig -> KernelState -> Eff (Kernel : es) a -> Eff es (Either Unwind a, KernelState)
runEvalPure = runKernelPure (Sequence evalSequence)

-- | The 'IO' evaluator over a session's state.
runEvalIO :: (IOE :> es) => EvalConfig -> IORef KernelState -> Eff (Kernel : es) a -> Eff es (Either Unwind a)
runEvalIO = runKernelIO (Sequence evalSequence)
