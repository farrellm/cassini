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
    runEvalInterruptible,

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
    Round (..),
    firstJustM,
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
import Cassini.Core.Expr (Expr, apply, exprArgs, mkApp, symbolOf, pattern App, pattern Call, pattern Int_, pattern Num, pattern Str, pattern Sym)
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
    evaluatePart,
    evaluateRhs,
    iterations,
    kernelConfig,
    lookupBuiltin,
    lookupSymbol,
    runKernelIO,
    runKernelInterruptible,
    runKernelPure,
    spendIteration,
    terminated,
    traceStep,
    unwind,
    withFuel,
  )
import Cassini.Pattern.Match (matchRuleOrRun, observeFirst)
import Cassini.Rules (BuiltinId, Origin (..), Rule (..), RuleBody (..), SymbolInfo (..), ValueKind (..), applicableRules, ladder)
import Data.Vector qualified as V
import Effectful (Eff, IOE, (:>))

-- | An application part-way through the sequence: its evaluated head, its
-- arguments as the steps leave them, the head's attributes, the 0-based
-- positions of the held arguments step 3 evaluated anyway because they were
-- wrapped in @Evaluate@ (read by step 5 only), the values step 6 stripped of
-- their @Unevaluated@ wrappers, with their 0-based positions, and whether
-- step 5 moved an unevaluated argument into an unheld position, and whether
-- the steps record a trace, read once per fixed point rather than asked of
-- the kernel at every step (D31), and whether the evaluation has left the
-- standard chain, which decides how steps 2 and 3 evaluate (§4.3).
data Node = Node
  { nodeHead :: !Expr,
    nodeArgs :: !(V.Vector Expr),
    nodeAttrs :: !AttributeSet,
    nodeForced :: ![Int],
    nodeStripped :: ![(Int, Expr)],
    nodeUnheld :: !Bool,
    nodeTrace :: !Bool,
    nodeLeft :: !Bool
  }

-- | The expression the node stands for now.
nodeExpr :: Node -> Expr
nodeExpr n = mkApp n.nodeHead n.nodeArgs

-- | The evaluation sequence, to a fixed point: every time the expression
-- changes, start over, unless the round's result is known to be a fixed point
-- already (see 'Round').
--
-- The recursion limit replaces the second evaluation on the path to the cut
-- that leaves the standard chain (§4.3). An evaluation leaves it when it
-- asks for an evaluation other than of its head or an unheld argument (a
-- rule's condition or right-hand side, a builtin evaluating a held
-- argument), and when it goes round again after a rewrite. The first round
-- evaluates the head and arguments with 'evaluatePart', and the later ones
-- with 'evaluate'; the kernel does the rest.
evalSequence :: (Kernel :> es) => Expr -> Eff es Expr
evalSequence e0 = kernelConfig >>= \cfg -> fixpoint cfg (step cfg.trace) e0
  where
    -- Steps 1 and 0 are guards on the other twelve, not stages before them.
    -- The flags: whether to trace, and whether this is a round after a
    -- rewrite, which has left the standard chain.
    step tr left e
      | evalStep1Raw e = pure (Round e True)
      | Sym s <- e = (`Round` False) <$> evalStep0Own s
      | App h as <- e = do
          n <-
            evalStep2Head tr left h as
              >>= evalStep34ArgsHold
              >>= evalStep5Seq
              >>= evalStep6Uneval
              >>= evalStep7Flat
          evalStep8List n >>= \case
            Left threaded -> pure (Round threaded False)
            Right n' ->
              evalStep9Order n' >>= evalStepIndet >>= \case
                Left indeterminate -> pure (Round indeterminate False)
                Right n'' -> do
                  -- Built once for the four rungs, not once per rung.
                  let e' = nodeExpr n''
                  lk <- rungLookups n'' e'
                  fired <- firstJustM (\r -> r lk e') [userUp, builtinUp, userDown, builtinDown]
                  pure (fromMaybe (Round (if null n''.nodeStripped then e' else restoreUneval n'') (not n''.nodeUnheld)) fired)
      | otherwise = pure (Round e True)

-- | One round's result, and whether it is already a fixed point of the
-- sequence. It is when no rule fired: steps 2–9 only evaluated the parts and
-- rearranged them, and another round would evaluate the same parts and try
-- the same rules on the same expression. Unless step 5 moved a held argument
-- into an unheld position, as splicing a @Sequence@ under @HoldFirst@ or
-- @HoldRest@ can: the next round evaluates it there, so @f[Sequence[1+1,
-- 2+2], 3+3]@ with @HoldFirst@ is @f[1+1, 4, 6]@. It is when a user rule fired: its
-- rung evaluated the right-hand side to a fixed point itself (§4.4). A
-- built-in's result, an own value, a threaded list and @Indeterminate@ are
-- new expressions, and go round again.
--
-- Skipping the round that can change nothing is not D14's marker. It keeps
-- an unevaluated subterm that emits a message, such as @Part[{1, 2}, 3]@,
-- from emitting it again each time a sibling changes its parent.
data Round = Round
  { roundExpr :: !Expr,
    roundSettled :: !Bool
  }

-- | The fixed point, fuelled: one iteration per round, from a fresh budget
-- restored on exit. On exhaustion, @$IterationLimit::itlim@ and
-- @TerminatedEvaluation["IterationLimit"]@ in place of the expression:
-- non-termination is a user error, so it gets a message, not an exception
-- (§4.4).
--
-- The configuration comes in already read, and each round is told whether
-- it follows a rewrite, which has left the standard chain (§4.3).
fixpoint :: (Kernel :> es) => EvalConfig -> (Bool -> Expr -> Eff es Round) -> Expr -> Eff es Expr
fixpoint cfg f e0 = withFuel cfg.iterationLimit (go False e0)
  where
    go left e = do
      fuel <- iterations
      if fuel <= 0
        then do
          emitMessage (systemSymbol "$IterationLimit") "itlim" [Int_ (toInteger cfg.iterationLimit)]
          pure (terminated "IterationLimit")
        else do
          spendIteration
          Round e' settled <- f left e
          if settled || e' == e then pure e' else go True e'

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
  fired <- firstJustM (\o -> firstJustM (ownRule e) (applicableRules info (OwnValue, o) e)) [User, Builtin]
  case fired of
    Just v -> v <$ traceStep "0 OwnValue" v
    Nothing -> pure e
  where
    ownRule e r = case r.ruleBody of
      Native bid -> runNative bid e
      _ -> instantiate r e

-- | Step 2: evaluate the head, and read its attributes. The flags are whether
-- the steps record a trace, and whether the evaluation has left the
-- standard chain in a round after a rewrite (§4.3).
evalStep2Head :: (Kernel :> es) => Bool -> Bool -> Expr -> V.Vector Expr -> Eff es Node
evalStep2Head tr left h as = do
  h' <- (if left then evaluate else evaluatePart) h
  when (tr && h' /= h) $ traceStep "2 Head" (mkApp h' as)
  attrs <- headAttributes h'
  pure Node {nodeHead = h', nodeArgs = as, nodeAttrs = attrs, nodeForced = [], nodeStripped = [], nodeUnheld = False, nodeTrace = tr, nodeLeft = left}

-- | "The attributes of @h@" for steps 4–9: a symbol's own; for
-- @Function[_, _, attrs]@, @attrs@, one attribute or a list (§4.13); none
-- for any other compound head.
headAttributes :: (Kernel :> es) => Expr -> Eff es AttributeSet
headAttributes = \case
  -- lookupSymbol, not lookupAttributes, as in the matcher's headAttributes.
  Sym s -> (.siAttributes) <$> lookupSymbol s
  App (Sym f) as | f == sFunction, [_, _, attrs] <- V.toList as -> pure (functionAttributes attrs)
  _ -> pure mempty
  where
    functionAttributes = \case
      Call l xs | l == sList -> attributeSet (mapMaybe attribute xs)
      x -> attributeSet (maybeToList (attribute x))
    attribute x = symbolOf x >>= attributeFromName . (.symName)

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
  let n' = n {nodeArgs = as', nodeForced = forcedAt}
  when (as' /= n.nodeArgs) $ traceIf n' "3 Arguments" (nodeExpr n')
  pure n'
  where
    -- Evaluate[x] in a held position is x evaluated, not Evaluate[x]
    -- evaluated: step 6 would strip an Unevaluated inside it otherwise.
    -- Several arguments become their Sequence, which step 5 splices.
    arg h a
      | not h = sub a
      | forced a = case V.toList (exprArgs a) of
          [x] -> sub x
          ys -> sub (apply sSequence ys)
      | otherwise = pure a
    sub = if n.nodeLeft then evaluate else evaluatePart
    forced = \case
      App (Sym s) _ -> s == sEvaluate && not (holdAllComplete n.nodeAttrs)
      _ -> False
    forcedAt
      | V.or held = [i | (i, True, a) <- zip3 [0 ..] (V.toList held) (V.toList n.nodeArgs), forced a]
      | otherwise = []

-- | Steps 3 and 4, one pass: step 4 is a gate on step 3, not a stage after
-- it. Evaluating everything and then deciding what was held would give
-- @Hold[2]@ for @Hold[1+1]@.
evalStep34ArgsHold :: (Kernel :> es) => Node -> Eff es Node
evalStep34ArgsHold n = do
  let held = evalStep4Hold n
  when (V.or held) $ traceIf n "4 Hold" (nodeExpr n)
  evalStep3Args held n

-- | Step 5: unless @SequenceHold@ or @HoldAllComplete@, splice @Sequence@
-- arguments. Splicing shifts positions, so it records whether an argument
-- step 3 left unevaluated now sits where step 4 would not hold it ('Round').
-- One that @Evaluate@ forced was evaluated, and does not count.
evalStep5Seq :: (Kernel :> es) => Node -> Eff es Node
evalStep5Seq n
  | sequenceHold n.nodeAttrs || not (V.any isSequence n.nodeArgs) = pure n
  | otherwise = changed "5 Sequence" n {nodeArgs = V.map fst spliced, nodeForced = [], nodeUnheld = unheld}
  where
    isSequence = \case
      App (Sym s) _ -> s == sSequence
      _ -> False
    k = V.length n.nodeArgs
    -- Each spliced argument, with whether step 3 left it unevaluated: its
    -- position held it, and no Evaluate forced it.
    spliced = V.concat [V.map (,unevaluated i) (splice a) | (i, a) <- zip [0 ..] (V.toList n.nodeArgs)]
    unevaluated i = holdsArgument n.nodeAttrs (i + 1) k && i `notElem` n.nodeForced
    splice a = if isSequence a then exprArgs a else V.singleton a
    k' = V.length spliced
    unheld = V.or (V.imap (\j (_, wasHeld) -> wasHeld && not (holdsArgument n.nodeAttrs (j + 1) k')) spliced)

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
    stripped = [(i, x) | (i, a) <- zip [0 ..] (V.toList n.nodeArgs), Just x <- [unevaluated a]]

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
        Left threaded <$ traceIf n "8 Listable" threaded
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
      Left indeterminate <$ traceIf n "Indeterminate" indeterminate
  | otherwise = pure (Right n)
  where
    indeterminate = Sym sIndeterminate

-- | Step 10: unless @HoldAllComplete@, user upvalues.
evalStep10UserUp :: (Kernel :> es) => Node -> Eff es (Maybe Round)
evalStep10UserUp = alone userUp

-- | Step 11: unless @HoldAllComplete@, built-in upvalues.
evalStep11BuiltinUp :: (Kernel :> es) => Node -> Eff es (Maybe Round)
evalStep11BuiltinUp = alone builtinUp

-- | Step 12: user downvalues, or subvalues for @h[…][…]@.
evalStep12UserDown :: (Kernel :> es) => Node -> Eff es (Maybe Round)
evalStep12UserDown = alone userDown

-- | Step 13: built-in downvalues, or subvalues for @h[…][…]@.
evalStep13BuiltinDown :: (Kernel :> es) => Node -> Eff es (Maybe Round)
evalStep13BuiltinDown = alone builtinDown

-- | One rung run by itself, with its own lookups.
alone :: (Kernel :> es) => (RungLookups -> Expr -> Eff es (Maybe Round)) -> Node -> Eff es (Maybe Round)
alone r n = let e = nodeExpr n in rungLookups n e >>= \lk -> r lk e

-- | The symbols the four rungs look up, looked up once a round rather than
-- once a rung (D32): each upvalue tag among the arguments, for rungs 10 and
-- 11, and the symbol the expression's own rules are keyed on, for 12 and
-- 13. After steps 2–9, so that a definition made while evaluating the
-- arguments is seen.
data RungLookups = RungLookups
  { rlUp :: ![SymbolInfo],
    rlDown :: !(Maybe SymbolInfo)
  }

-- | Look up what the rungs need.
rungLookups :: (Kernel :> es) => Node -> Expr -> Eff es RungLookups
rungLookups n e = do
  ups <-
    if holdAllComplete n.nodeAttrs
      then pure []
      else traverse lookupSymbol (ordNub (mapMaybe tagSymbol (V.toList n.nodeArgs)))
  down <- traverse lookupSymbol (tagSymbol e)
  pure (RungLookups ups down)

-- | Steps 10–13 on the expression a node stands for, which the
-- sequence builds once for all four.
userUp, builtinUp, userDown, builtinDown :: (Kernel :> es) => RungLookups -> Expr -> Eff es (Maybe Round)
userUp = rung 0 "10 UserUpValue"
builtinUp = rung 1 "11 BuiltinUpValue"
userDown = rung 2 "12 UserDownValue"
builtinDown = rung 3 "13 BuiltinDownValue"

-- | The @i@th rung of 'ladder', which is the only list of rungs: each named
-- step reads its rung from it rather than restating it (§4.2).
rung :: (Kernel :> es) => Int -> Text -> RungLookups -> Expr -> Eff es (Maybe Round)
rung i name lk e = case drop i (ladder e) of
  -- Under HoldAllComplete, 'rungLookups' gives no upvalue tags.
  (UpValue, o) : _ -> firstJustM (fromTable (UpValue, o)) lk.rlUp
  (k, o) : _ -> maybe (pure Nothing) (fromTable (k, o)) lk.rlDown
  [] -> pure Nothing
  where
    fromTable r info = firstJustM (\rule -> applyRule name rule e) (applicableRules info r e)

-- | The symbol an expression's rules are keyed on: the symbol itself, or the
-- innermost head symbol of an application (@f@ for @f[x][y]@).
tagSymbol :: Expr -> Maybe Symbol
tagSymbol = \case
  App h _ -> tagSymbol h
  e -> symbolOf e

-- | Apply one rule, if it matches. A user rule evaluates its own
-- instantiated right-hand side, inside 'catchUnwind', and turns a caught
-- @Return@ into its value: this is where @Return@ is caught (§4.4, §4.13). A
-- built-in rule is Haskell, and returns as the list says. The trace records
-- what the rule produced: a built-in's result, a user rule's right-hand side
-- before it is evaluated.
applyRule :: (Kernel :> es) => Text -> Rule -> Expr -> Eff es (Maybe Round)
applyRule name r e = case r.ruleBody of
  Native bid -> runNative bid e >>= \fired -> (`Round` False) <$> fired <$ for_ fired (traceStep name)
  _ -> instantiate r e >>= traverse fire
  where
    fire rhs = do
      traceStep name rhs
      catchUnwind (evaluateRhs rhs) >>= \case
        Right v -> pure (Round v True)
        Left (UReturn v) -> pure (Round v True)
        Left u -> unwind u

-- | A user rule's right-hand side, instantiated by the first match under
-- which it applies. @lhs :> rhs /; test@ applies only where the test, under
-- the match's bindings, evaluates to @True@; where it does not, the next
-- match is tried, as a condition on the left-hand side would be. Under a
-- @Flat@ head a rule also applies to a run of the arguments
-- ('matchRuleOrRun'). 'Nothing' for a 'Native' rule, which is never matched.
instantiate :: (Kernel :> es) => Rule -> Expr -> Eff es (Maybe Expr)
instantiate r e = maybe (pure Nothing) (\p -> observeFirst (matchRuleOrRun p e)) r.rulePrepared

-- | Run a builtin. It fires only if it changes the expression, so step 6's
-- restoration and the trace stay honest.
runNative :: (Kernel :> es) => BuiltinId -> Expr -> Eff es (Maybe Expr)
runNative bid e =
  lookupBuiltin bid >>= \case
    Nothing -> pure Nothing
    Just (BuiltinFn f) -> (\r -> r >>= \x -> if x == e then Nothing else Just x) <$> f e

-- | No rung fired: put back the @Unevaluated@ wrappers step 6 stripped. By
-- position while every stripped value is still where step 6 found it, so
-- @f[a, Unevaluated[a]]@ keeps its wrapper on the second argument; by value
-- once steps 7–9 have moved the arguments.
restoreUneval :: Node -> Expr
restoreUneval n
  | null n.nodeStripped = nodeExpr n
  | all (\(i, x) -> n.nodeArgs V.!? i == Just x) n.nodeStripped =
      mkApp n.nodeHead (n.nodeArgs V.// [(i, apply sUnevaluated [x]) | (i, x) <- n.nodeStripped])
  | otherwise = mkApp n.nodeHead (V.fromList (go (map snd n.nodeStripped) (V.toList n.nodeArgs)))
  where
    go [] as = as
    go _ [] = []
    go pending (a : as) = case break (== a) pending of
      (before, _ : after) -> apply sUnevaluated [a] : go (before ++ after) as
      (_, []) -> a : go pending as

-- | Trace a step that applied, with the node it left.
changed :: (Kernel :> es) => Text -> Node -> Eff es Node
changed name n = n <$ traceIf n name (nodeExpr n)

-- | Trace a step, if the node's evaluation records a trace: steps 3–9 trace
-- through here, so none asks the kernel when it does not (D31).
traceIf :: (Kernel :> es) => Node -> Text -> Expr -> Eff es ()
traceIf n name e = when n.nodeTrace (traceStep name e)

-- | The first 'Just' of an effectful search, trying no more than it needs.
firstJustM :: (Monad m) => (a -> m (Maybe b)) -> [a] -> m (Maybe b)
firstJustM f = \case
  [] -> pure Nothing
  x : xs -> f x >>= maybe (firstJustM f xs) (pure . Just)

-- | Evaluate one top-level input. An unwind that escapes every handler is
-- converted here, where there is an expression to build: an uncaught @Throw@
-- becomes @Hold[Throw[…]]@ with @Throw::nocatch@, and a stray @Break[]@,
-- @Continue[]@ or @Return[…]@ comes back @Hold@-wrapped, so evaluating the
-- result again does not unwind again (§4.13). A limit that no evaluation
-- on the way out was replaced for leaves @TerminatedEvaluation[…]@ for the
-- whole input (§4.3). An abort passes through.
evaluateTop :: (Kernel :> es) => Expr -> Eff es Expr
evaluateTop e =
  catchUnwind (evaluatePart e) >>= \case
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
      UTerminated reason _ -> pure (terminated reason)
      UAbort a -> unwind (UAbort a)
  where
    sThrow = systemSymbol "Throw"

-- | The pure evaluator: 'runKernelPure' with the knot tied.
runEvalPure :: EvalConfig -> KernelState -> Eff (Kernel : es) a -> Eff es (Either Unwind a, KernelState)
runEvalPure = runKernelPure (Sequence evalSequence)

-- | The 'IO' evaluator over a session's state.
runEvalIO :: (IOE :> es) => EvalConfig -> IORef KernelState -> Eff (Kernel : es) a -> Eff es (Either Unwind a)
runEvalIO = runKernelIO (Sequence evalSequence)

-- | The 'IO' evaluator, polling an interrupt flag at every step: the
-- interactive loop's.
runEvalInterruptible :: (IOE :> es) => EvalConfig -> IORef KernelState -> IORef Bool -> Eff (Kernel : es) a -> Eff es (Either Unwind a)
runEvalInterruptible = runKernelInterruptible (Sequence evalSequence)
