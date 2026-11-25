{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE PatternSynonyms #-}

-- | Pure functions, sequencing, conditionals, scoping, non-local exits,
-- loops and iterators (DESIGN.md §4.13), and @Print@ (§4.7).
--
-- Source: @references/papers/wolfram-language/wolfram_ref_evaluation_of_expressions.html@
-- ("Conditionals", "Loops and Control Structures", "Evaluation in Iteration
-- Functions"), @wolfram_ref_modularity_and_naming.html@ ("How Modules
-- Work", "Blocks and Local Values", "Variables in Pure Functions and
-- Rules"), and the reference pages @wolfram_ref_function.html@,
-- @_module.html@, @_block.html@, @_with.html@, @_return.html@,
-- @_throw.html@, @_catch.html@ and @_break.html@, all in
-- @references/papers/wolfram-language/@.
--
-- @Function[params, body][args]@ and @Function[body][args]@ apply as a
-- built-in subvalue on @Function@ (step 13's @h[…][…]@), by substituting into
-- the held body with 'Cassini.Structure.substituteFree'. A pure function is
-- applied by a built-in rung, so it does not catch @Return@ (§4.4).
--
-- The non-local exits are the kernel's 'unwind'; a construct that handles
-- one runs its body under 'catchUnwind' and rethrows what is not its own.
-- @Block@ and the iterators localize symbols as @Block@ does, and restore
-- them on every exit, unwinds and @Abort[]@ included: the one place state
-- changes are undone (§4.13).
module Cassini.Builtins.Control (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Attributes qualified as Attributes
import Cassini.Builtins.Define (Definition, args, curried, define, down, inLevel, levelParts, levelSpec, message, own, sNullE, sTrueE, settled, sub)
import Cassini.Core.Expr (Expr, apply, mkApp, mkNumber, pattern App, pattern Call, pattern Int_, pattern Num, pattern Sym)
import Cassini.Core.Symbol (Symbol, sFunction, sList, sPlus, sSet, sSetDelayed, sSlot, sSlotSequence, sTimes, symContext, symName, symbol, systemSymbol)
import Cassini.Eval.Kernel (Abort (..), EvalConfig (..), Kernel, Unwind (..), catchUnwind, emitMessage, emitOutput, evaluate, kernelConfig, lookupSymbol, modifySymbol, unwind)
import Cassini.Number (fromRational', toRational')
import Cassini.Pattern.Match (matchOne)
import Cassini.Rules (Origin (..), RuleBody (..), SymbolInfo (..), ValueKind (..), emptyInfo, insertRule, mkRule, modifyRules)
import Cassini.Structure (Binding (..), Parameters (..), Scoping (Shielding), Slots (..), functionForm, substituteFree)
import Data.List (unsnoc)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V
import Effectful (Eff, (:>))
import Optics.Core ((%~))

-- | The control builtins, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "Function" [HoldAll, Protected] [sub functionRule],
    define "Slot" [NHoldAll, Protected] [],
    define "SlotSequence" [NHoldAll, Protected] [],
    define "CompoundExpression" [HoldAll, Protected, ReadProtected] [down compoundRule],
    define "If" [HoldRest, Protected] [down ifRule],
    define "Which" [HoldAll, Protected] [down whichRule],
    define "Switch" [HoldRest, Protected] [down switchRule],
    define "Module" [HoldAll, Protected] [down moduleRule],
    define "With" [HoldAll, Protected] [down withRule],
    define "Block" [HoldAll, Protected] [down blockRule],
    define "$ModuleNumber" [] [own (const (pure (Just (Int_ 1))))],
    define "Catch" [HoldFirst, Protected] [down catchRule],
    define "Throw" [Protected] [down throwRule],
    define "Break" [Protected] [down (exit 0 UBreak)],
    define "Continue" [Protected] [down (exit 0 UContinue)],
    define "Return" [Protected] [down returnRule],
    define "Abort" [Protected] [down (exit 0 (UAbort AbortCall))],
    define "Do" [HoldAll, Protected] [down doRule],
    define "While" [HoldAll, Protected] [down whileRule],
    define "For" [HoldAll, Protected] [down forRule],
    define "Until" [HoldAll, Protected] [down untilRule],
    define "Scan" [Protected] [down scanRule, sub (curried (\as xs -> if length as == 1 && length xs == 1 then Just (as <> xs) else Nothing))],
    define "Table" [HoldAll, Protected] [down tableRule],
    define "Sum" [HoldAll, Protected, ReadProtected] [down (accumulate sPlus)],
    define "Product" [HoldAll, Protected, ReadProtected] [down (accumulate sTimes)],
    define "Nest" [Protected] [down (nest False)],
    define "NestList" [Protected] [down (nest True)],
    define "Fold" [Protected] [down (folding False), sub (curried foldForm)],
    define "FoldList" [Protected] [down (folding True), sub (curried foldForm)],
    define "FixedPoint" [Protected] [down (fixedPoint False)],
    define "FixedPointList" [Protected] [down (fixedPoint True)],
    define "Print" [Protected] [down printRule]
  ]

-- | @Function[…][args]@. In slot form, @#n@ is the @n@th argument and
-- arguments beyond the highest slot are ignored; a slot with no argument
-- stays, with @Function::slotn@, and so does a @##n@ with none after the
-- one before it, with @Function::slots@. With named parameters, each takes its
-- argument and any further arguments are ignored; too few arguments is
-- @Function::fpct@, and the application stays unevaluated.
functionRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
functionRule e = case e of
  App f@(Call h fargs@(ps : _)) as
    | h == sFunction,
      Just (params, body) <- functionForm fargs -> case params of
        SlotParameters -> slotForm f body as
        NamedParameters xs
          | length xs > V.length as -> Nothing <$ message "Function" "fpct" [ps, e]
          | otherwise -> pure (Just (substituteFree Shielding (Map.fromList (zip xs (map BOne (V.toList as)))) Nothing body))
  _ -> pure Nothing
  where
    slotForm f body as = do
      for_ (unfilled (V.length as) body) $ \case
        Left n -> message "Function" "slotn" [Int_ n, e]
        Right n -> message "Function" "slots" [Int_ n, e]
      pure (Just (substituteFree Shielding Map.empty (Just (Slots as f)) body))

-- | The slots in a slot-form body that @k@ arguments cannot fill, each
-- once, outside any slot-form @Function@ inside it, whose slots are its own:
-- 'Left' a slot @#n@ beyond the arguments, 'Right' a @##n@ beyond one past
-- them (@wolfram/SlotSequence/PossibleIssues/1@).
unfilled :: Int -> Expr -> [Either Integer Integer]
unfilled k = ordNub . go
  where
    -- Each guard tests the head before it lists the arguments: this runs on
    -- every node of the body, at every application (DESIGN.md §3.3, @Call@).
    go = \case
      App (Sym h) xs
        | h == sSlot, [Int_ n] <- V.toList xs, n > toInteger k -> [Left n]
        | h == sSlotSequence, [Int_ n] <- V.toList xs, n > toInteger k + 1 -> [Right n]
        | h == sFunction, Just (SlotParameters, _) <- functionForm (V.toList xs) -> []
      App h xs -> go h <> concatMap go (V.toList xs)
      _ -> []

-- | @CompoundExpression[e1, …, en]@ evaluates each @ei@ in turn and gives
-- the last. The last is returned unevaluated, for the fixed point to
-- evaluate once, so a message it emits is emitted once. With no arguments
-- it is @Null@.
compoundRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
compoundRule e = case unsnoc (args e) of
  Nothing -> pure (Just sNullE)
  Just (before, lastE) -> Just lastE <$ traverse_ evaluate before

-- | @Fold[f][list]@ and @Fold[f][x, list]@ are @Fold[f, list]@ and
-- @Fold[f, x, list]@.
foldForm :: [Expr] -> [Expr] -> Maybe [Expr]
foldForm as xs
  | [_] <- as, length xs `elem` [1, 2] = Just (as <> xs)
  | otherwise = Nothing

-- * Conditionals

-- | @If[test, t]@, @If[test, t, f]@ and @If[test, t, f, u]@: the branch the
-- test selects, unevaluated, for the fixed point to evaluate once. A test
-- that is neither @True@ nor @False@ takes @u@, or leaves the @If@ as it is:
-- an undecided test is never @False@ (§4.13). @If[False, t]@ is @Null@.
ifRule :: Expr -> Eff es (Maybe Expr)
ifRule e = pure $ case args e of
  [c, t] -> decide c t sNullE Nothing
  [c, t, f] -> decide c t f Nothing
  [c, t, f, u] -> decide c t f (Just u)
  _ -> Nothing
  where
    decide c t f u
      | isSym "True" c = Just t
      | isSym "False" c = Just f
      | otherwise = u

-- | Whether the expression is the @System`@ symbol named.
isSym :: Text -> Expr -> Bool
isSym n = \case
  Sym s -> s == systemSymbol n
  _ -> False

-- | @Which[test₁, v₁, …]@: the value of the first test that is @True@,
-- unevaluated; @Null@ if every test is @False@. A test that is neither
-- stops the search, and the @Which@ stays from there, with that test
-- evaluated.
whichRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
whichRule e
  | odd (length (args e)) = Nothing <$ message "Which" "argct" [Int_ (toInteger (length (args e)))]
  | otherwise = go (args e)
  where
    go = \case
      c : v : rest ->
        evaluate c >>= \c' ->
          if
            | isSym "True" c' -> pure (Just v)
            | isSym "False" c' -> go rest
            | otherwise -> pure (Just (apply (systemSymbol "Which") (c' : v : rest)))
      _ -> pure (Just sNullE)

-- | @Switch[expr, form₁, v₁, …]@: the value of the first form @expr@
-- matches, unevaluated; the @Switch@ stays if none does.
switchRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
switchRule e = case args e of
  x : cases | even (length cases), not (null cases) -> go x cases
  _ -> pure Nothing
  where
    go x = \case
      form : v : rest -> matchOne form x >>= maybe (go x rest) (const (pure (Just v)))
      _ -> pure Nothing

-- * Scoping

-- | One local of @Module@, @With@ or @Block@: its name, and its initial
-- value, @x = v@ (evaluated) or @x := v@ (not), if it has one.
data Local = Local !Symbol !(Maybe (Bool, Expr))

-- | Read @{x, y = v, z := w, …}@: 'Nothing' if it is not a list, and
-- 'Left' the first entry that is not a local.
locals :: Expr -> Maybe (Either Expr [Local])
locals = \case
  Call l xs | l == sList -> Just (traverse one xs)
  _ -> Nothing
  where
    one = \case
      Sym x -> Right (Local x Nothing)
      Call s [Sym x, v]
        | s == sSet -> Right (Local x (Just (True, v)))
        | s == sSetDelayed -> Right (Local x (Just (False, v)))
      x -> Left x

-- | A scoping construct's locals, or its message for the first entry that
-- is not one: @lvset@ for an assignment to something other than a symbol,
-- @lvsym@ otherwise, and the construct stays (wolfram/Module/PossibleIssues/3).
scoping :: (Kernel :> es) => Text -> Expr -> Expr -> ([Local] -> Eff es (Maybe Expr)) -> Eff es (Maybe Expr)
scoping name e spec k = case locals spec of
  Just (Right ls) -> k ls
  Just (Left x) -> Nothing <$ message name (if isAssignment x then "lvset" else "lvsym") [x, e]
  Nothing -> Nothing <$ message name "lvlist" [spec]
  where
    isAssignment = \case
      Call s [_, _] -> s == sSet || s == sSetDelayed
      _ -> False

-- | A local's initial value: @x = v@'s evaluated, @x := v@'s as written.
initial :: (Kernel :> es) => Local -> Eff es (Maybe Expr)
initial (Local _ v) = case v of
  Just (True, x) -> Just <$> evaluate x
  Just (False, x) -> pure (Just x)
  Nothing -> pure Nothing

-- | @Module[{x, …}, body]@: each local becomes a fresh @x$n@, @n@ the
-- session's @$ModuleNumber@, which counts every use of a module; it is
-- @Temporary@, and takes the local's initial value. The body, renamed, is
-- returned to be evaluated; occurrences bound by a scoping construct inside
-- are not renamed. @$ModuleNumber@ is a symbol in the kernel state, never
-- the intern table's counter, so the names are a function of the initial
-- state (§4.13).
moduleRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
moduleRule e = case args e of
  [spec, body] -> scoping "Module" e spec $ \ls -> do
    n <-
      evaluate (Sym sModuleNumber) <&> \case
        Int_ k -> k
        _ -> 1
    setOwn sModuleNumber (Int_ (n + 1))
    renamed <- forM ls $ \l@(Local x _) -> do
      let x' = symbol x.symContext (x.symName <> "$" <> show n)
      v <- initial l
      modifySymbol x' (#siAttributes %~ Attributes.insert Temporary)
      for_ v $ \val -> modifySymbol x' (modifyRules OwnValue (insertRule (mkRule User (Sym x') (if isInitial l then Immediate val else Delayed val))))
      pure (x, BOne (Sym x'))
    pure (Just (substituteFree Shielding (Map.fromList renamed) Nothing body))
  _ -> pure Nothing
  where
    isInitial (Local _ v) = maybe True fst v

sModuleNumber :: Symbol
sModuleNumber = systemSymbol "$ModuleNumber"

-- | Give a symbol one own value, replacing any it had.
setOwn :: (Kernel :> es) => Symbol -> Expr -> Eff es ()
setOwn s v = modifySymbol s (modifyRules OwnValue (insertRule (mkRule User (Sym s) (Immediate v))))

-- | @With[{x = v, …}, body]@: the evaluated @v@ (or, for @x := v@, @v@ as
-- written) substituted into the held body, with the same scoping-aware
-- substitution as @Function@; the body is then evaluated.
-- @With[d₁, d₂, body]@ is @With[d₁, With[d₂, body]]@.
withRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
withRule e = case args e of
  [spec, body] -> scoping "With" e spec $ \ls -> do
    vs <- forM ls $ \l@(Local x _) -> fmap (\v -> (x, BOne v)) <$> initial l
    case sequence vs of
      Just bound -> pure (Just (substituteFree Shielding (Map.fromList bound) Nothing body))
      Nothing -> pure Nothing
  spec : rest@(_ : _ : _) -> pure (Just (apply (systemSymbol "With") [spec, apply (systemSymbol "With") rest]))
  _ -> pure Nothing

-- | @Block[{x, …}, body]@: the initial values are evaluated first; then
-- each symbol's attributes and its four kinds of values, built-in ones
-- included, are saved and cleared (its message text is not), the initial
-- values set, the body evaluated, and everything restored on every exit
-- (§4.13).
blockRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
blockRule e = case args e of
  [spec, body] -> scoping "Block" e spec $ \ls -> do
    vs <- traverse initial ls
    Just <$> localized [(x, v) | (Local x _, v) <- zip ls vs] (evaluate body)
  _ -> pure Nothing

-- | Run with each symbol cleared, and given the value if there is one, as
-- @Block@ does; restore each as it was, however the computation exits.
localized :: (Kernel :> es) => [(Symbol, Maybe Expr)] -> Eff es a -> Eff es a
localized vars m = do
  saved <- forM vars $ \(x, _) -> (x,) <$> lookupSymbol x
  for_ vars $ \(x, v) -> do
    modifySymbol x (\i -> emptyInfo {siMessages = i.siMessages})
    for_ v (setOwn x)
  r <- catchUnwind m
  for_ (reverse saved) $ \(x, info) -> modifySymbol x (\i -> info {siMessages = i.siMessages})
  either unwind pure r

-- * Non-local exits

-- | A builtin that only unwinds, when called with the given number of
-- arguments.
exit :: (Kernel :> es) => Int -> Unwind -> Expr -> Eff es (Maybe Expr)
exit k u e
  | length (args e) == k = unwind u
  | otherwise = pure Nothing

-- | @Return[]@ returns @Null@, @Return[v]@ returns @v@ (D23).
returnRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
returnRule e = case args e of
  [] -> unwind (UReturn sNullE)
  [v] -> unwind (UReturn v)
  _ -> pure Nothing

-- | @Throw[value]@, @Throw[value, tag]@ and @Throw[value, tag, f]@.
throwRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
throwRule e = case args e of
  [v] -> unwind (UThrow v Nothing Nothing)
  [v, t] -> unwind (UThrow v (Just t) Nothing)
  [v, t, f] -> unwind (UThrow v (Just t) (Just f))
  _ -> pure Nothing

-- | @Catch[expr]@ catches only an untagged @Throw[value]@;
-- @Catch[expr, form]@ only a tagged one whose tag, evaluated again each
-- time it is compared, matches @form@; @Catch[expr, form, f]@ gives
-- @f[value, tag]@ for it. What it does not catch passes by. The value is
-- settled: evaluating it again outside the @Catch@ must not throw again.
catchRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
catchRule e = case args e of
  [x] -> run x Nothing Nothing
  [x, form] -> run x (Just form) Nothing
  [x, form, f] -> run x (Just form) (Just f)
  _ -> pure Nothing
  where
    run x form f =
      catchUnwind (evaluate x) >>= \case
        Right v -> pure (Just (settled v))
        Left u@(UThrow v tag _) -> case (form, tag) of
          (Nothing, Nothing) -> pure (Just (settled v))
          (Just p, Just t) -> do
            t' <- evaluate t
            matchOne p t' >>= \case
              Just _ -> pure (Just (maybe (settled v) (\g -> mkApp g (V.fromList [v, t'])) f))
              Nothing -> unwind u
          _ -> unwind u
        Left u -> unwind u

-- * Loops

-- | How a loop's body ended: normally, or by @Continue[]@, which goes on
-- with the next iteration; by @Break[]@, which ends the loop with @Null@;
-- or by @Return[v]@, which ends it with @v@.
data Step = Next | Stop !Expr

-- | Evaluate a loop's body once, catching what a loop catches.
body1 :: (Kernel :> es) => Expr -> Eff es Step
body1 x =
  catchUnwind (evaluate x) >>= \case
    Right _ -> pure Next
    Left UContinue -> pure Next
    Left UBreak -> pure (Stop sNullE)
    Left (UReturn v) -> pure (Stop v)
    Left u -> unwind u

-- | @While[test, body]@: while the test evaluates to @True@, the body;
-- anything but @True@ ends it (§4.13). @Null@.
whileRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
whileRule e = case args e of
  [t] -> Just <$> loop t sNullE
  [t, b] -> Just <$> loop t b
  _ -> pure Nothing
  where
    loop t b =
      evaluate t >>= \c ->
        if c == sTrueE
          then
            body1 b >>= \case
              Next -> loop t b
              Stop v -> pure v
          else pure sNullE

-- | @For[start, test, incr, body]@: @start@, then while the test is @True@,
-- the body and the increment; @Continue[]@ goes on to the increment.
forRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
forRule e = case args e of
  [start, t, incr] -> run start t incr sNullE
  [start, t, incr, b] -> run start t incr b
  _ -> pure Nothing
  where
    run start t incr b = evaluate start >> (Just <$> loop t incr b)
    loop t incr b =
      evaluate t >>= \c ->
        if c == sTrueE
          then
            body1 b >>= \case
              Next -> evaluate incr >> loop t incr b
              Stop v -> pure v
          else pure sNullE

-- | @Until[test, body]@: the body, then the test, until it is @True@.
untilRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
untilRule e = case args e of
  [t, b] -> Just <$> loop t b
  _ -> pure Nothing
  where
    loop t b =
      body1 b >>= \case
        Stop v -> pure v
        Next -> evaluate t >>= \c -> if c == sTrueE then pure sNullE else loop t b

-- | @Scan[f, expr]@ evaluates @f[x]@ for each part of @expr@ at level 1,
-- or at the levels given, and is @Null@; @Return[v]@ ends it with @v@.
scanRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
scanRule e = case args e of
  [f, x] -> Just <$> go f (args x)
  [f, x, spec] | Just ls <- levelSpec spec -> Just <$> go f (levelParts (inLevel ls) x)
  _ -> pure Nothing
  where
    go f = \case
      [] -> pure sNullE
      p : ps ->
        catchUnwind (evaluate (mkApp f (V.singleton p))) >>= \case
          Right _ -> go f ps
          Left (UReturn v) -> pure v
          Left u -> unwind u

-- * Iterators

-- | An iterator, read and its bounds evaluated: how many times, and for a
-- variable, the values it takes in turn.
--
-- An iterator to @Infinity@ has an endless list of values, which only
-- @Do@ takes, to be left by @Break[]@ or @Return[v]@.
data Iterator = Iterator !(Maybe Symbol) ![Expr] !Bool

-- | Read and evaluate an iterator specification (§4.13): @{n}@, @{i, imax}@,
-- @{i, imin, imax}@, @{i, imin, imax, di}@ and @{i, list}@. The bounds are
-- evaluated with the variable localized, as the source says. 'Nothing' if
-- the specification is not one, or its bounds do not give a number of
-- steps: a symbolic bound, which @Table@ reports and @Sum@ and @Product@
-- leave for §6.3.
iterator :: (Kernel :> es) => Expr -> Eff es (Maybe Iterator)
iterator spec = case spec of
  Call l [n]
    | l == sList ->
        evaluate n <&> \case
          Int_ k -> Just (Iterator Nothing (replicate (fromInteger (max 0 k)) sNullE) False)
          Num r -> Just (Iterator Nothing (replicate (max 0 (floor (toRational' r))) sNullE) False)
          _ -> Nothing
  Call l [Sym i, xs]
    | l == sList ->
        localized [(i, Nothing)] (evaluate xs) >>= \case
          Call l' vs | l' == sList -> pure (Just (Iterator (Just i) vs False))
          imax -> range i (Int_ 1) imax (Int_ 1)
  Call l [Sym i, lo, hi]
    | l == sList ->
        bounds i [lo, hi] >>= \case
          [lo', hi'] -> range i lo' hi' (Int_ 1)
          _ -> pure Nothing
  Call l [Sym i, lo, hi, d]
    | l == sList ->
        bounds i [lo, hi, d] >>= \case
          [lo', hi', d'] -> range i lo' hi' d'
          _ -> pure Nothing
  -- a bare count, Table[x, 10]; anything else is not an iterator
  Call l _ | l == sList -> pure Nothing
  n ->
    evaluate n <&> \case
      Int_ k -> Just (Iterator Nothing (replicate (fromInteger (max 0 k)) sNullE) False)
      _ -> Nothing
  where
    bounds i = localized [(i, Nothing)] . traverse evaluate
    range i lo hi d = do
      steps <- evaluate (apply sTimes [apply sPlus [hi, apply sTimes [Int_ (-1), lo]], apply (systemSymbol "Power") [d, Int_ (-1)]])
      case steps of
        Num r
          | Num _ <- lo,
            Num _ <- d,
            toRational' r >= 0 ->
              let lo' = numberOf lo
                  d' = numberOf d
               in pure (Just (Iterator (Just i) [mkNumber (fromRational' (lo' + fromInteger k * d')) | k <- [0 .. floor (toRational' r)]] False))
          | toRational' r >= 0 -> do
              vs <- traverse (\k -> evaluate (apply sPlus [lo, apply sTimes [Int_ k, d]])) [0 .. floor (toRational' r)]
              pure (Just (Iterator (Just i) vs False))
          | otherwise -> pure (Just (Iterator (Just i) [] False))
        Call di [Int_ 1]
          | di == systemSymbol "DirectedInfinity",
            Num _ <- lo,
            Num _ <- d ->
              pure (Just (Iterator (Just i) [mkNumber (fromRational' (numberOf lo + fromInteger k * numberOf d)) | k <- [0 ..]] True))
        _ -> pure Nothing
    numberOf = \case
      Num n -> toRational' n
      _ -> 0

-- | Run over an iterator's values, with its variable localized as @Block@
-- localizes it, given the way to set it to each value in turn.
iterate' :: (Kernel :> es) => Iterator -> ((Expr -> Eff es ()) -> Eff es b) -> Eff es b
iterate' (Iterator v _ _) go = case v of
  Nothing -> go (const pass)
  Just i -> localized [(i, Nothing)] (go (setOwn i))

-- | The values each iteration of nested iterators takes, outermost first,
-- the body evaluated for each with every variable set: the results nested
-- as the iterators are. 'Nothing' if an iterator does not read.
nested :: (Kernel :> es) => [Expr] -> (Expr -> Eff es a) -> Expr -> Eff es (Maybe (Tree a))
nested specs f b = case specs of
  [] -> Just . Leaf <$> f b
  spec : rest ->
    iterator spec >>= \case
      Nothing -> pure Nothing
      Just (Iterator _ _ True) -> pure Nothing
      Just it@(Iterator _ vs _) ->
        iterate' it $ \set ->
          fmap (fmap Node . sequence) . forM vs $ \v -> set v >> nested rest f b

-- | Results nested as iterators are.
data Tree a = Leaf a | Node [Tree a]

-- | @Table[expr, iter…]@: @expr@ evaluated for each value, nested lists for
-- nested iterators. An iterator that does not read leaves the @Table@, with
-- @Table::iterb@.
tableRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
tableRule e = case args e of
  b : specs@(_ : _) ->
    nested specs evaluate b >>= \case
      Just t -> pure (Just (toList' t))
      Nothing
        -- an iterator that is not a list: Table[x^2, p] does not evaluate p
        -- into one (wolfram/Table/PossibleIssues/2)
        | i : _ <- [i | (i, sp) <- zip [2 :: Integer ..] specs, not (isListE sp)] -> Nothing <$ message "Table" "nliter" [specs `at` (i - 2), Int_ i, e]
        | otherwise -> Nothing <$ message "Table" "iterb" [e]
  _ -> pure Nothing
  where
    at xs k = fromMaybe e (viaNonEmpty head (drop (fromInteger k) xs))
    isListE = \case
      Call l _ -> l == sList
      _ -> False
    toList' = \case
      Leaf x -> x
      Node ts -> apply sList (map toList' ts)

-- | @Do[expr, iter…]@: @expr@ evaluated for each value, and @Null@; each
-- evaluation is a loop body, so @Break[]@, @Continue[]@ and @Return[v]@ act
-- on it.
doRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
doRule e = case args e of
  b : specs@(_ : _) ->
    go specs b >>= \case
      Just Next -> pure (Just sNullE)
      Just (Stop v) -> pure (Just v)
      Nothing -> Nothing <$ message "Do" "iterb" [e]
  _ -> pure Nothing
  where
    -- A Break[] or Return[v] at any depth of nested iterators ends them all.
    go specs b = case specs of
      [] -> Just <$> body1 b
      spec : rest ->
        iterator spec >>= \case
          Nothing -> pure Nothing
          Just it@(Iterator _ vs _) ->
            iterate' it $ \set ->
              let loop = \case
                    [] -> pure (Just Next)
                    v : more ->
                      set v >> go rest b >>= \case
                        Just Next -> loop more
                        r -> pure r
               in loop vs

-- | @Sum@ and @Product@ over iterators with numeric bounds: every term,
-- evaluated, then their sum or product. A symbolic bound leaves the call to
-- §6.3, which Stage 3 builds.
accumulate :: (Kernel :> es) => Symbol -> Expr -> Eff es (Maybe Expr)
accumulate op e = case args e of
  b : specs@(_ : _) ->
    nested specs evaluate b <&> fmap (apply op . flatten)
  _ -> pure Nothing
  where
    flatten = \case
      Leaf x -> [x]
      Node ts -> concatMap flatten ts

-- * Iteration of functions

-- | A non-negative integer argument.
count :: Expr -> Maybe Int
count = \case
  Int_ n | n >= 0 -> Just (fromInteger n)
  _ -> Nothing

-- | @Nest[f, x, n]@ is @f@ applied @n@ times; @NestList@ gives every
-- stage, @x@ first.
nest :: (Kernel :> es) => Bool -> Expr -> Eff es (Maybe Expr)
nest listed e = case args e of
  [f, x, n] | Just k <- count n -> do
    xs <- go f k x
    pure (Just (if listed then apply sList xs else fromMaybe x (viaNonEmpty last xs)))
  _ -> pure Nothing
  where
    go f k x
      | k <= 0 = pure [x]
      | otherwise = evaluate (mkApp f (V.singleton x)) >>= fmap (x :) . go f (k - 1)

-- | @Fold[f, x, {a, b, …}]@ is @f[f[x, a], b]…@, and @Fold[f, {a, b, …}]@
-- starts from @a@; @FoldList@ gives every stage.
folding :: (Kernel :> es) => Bool -> Expr -> Eff es (Maybe Expr)
folding listed e = case args e of
  [f, x, App h ys] -> Just <$> go f x h (V.toList ys)
  [f, App h ys] -> case V.toList ys of
    y : rest -> Just <$> go f y h rest
    [] -> pure (if listed then Just (mkApp h V.empty) else Nothing)
  _ -> pure Nothing
  where
    go f x h ys = do
      stages <- scanM (\acc y -> evaluate (mkApp f (V.fromList [acc, y]))) x ys
      pure (if listed then mkApp h (V.fromList stages) else fromMaybe x (viaNonEmpty last stages))
    scanM g z = \case
      [] -> pure [z]
      y : rest -> g z y >>= \z' -> (z :) <$> scanM g z' rest

-- | @FixedPoint[f, x]@ applies @f@ until the result no longer changes, by
-- @SameQ@, at most @n@ times if given, and never more than
-- @$IterationLimit@ times: past that, @$IterationLimit::itlim@ and the last
-- value (§4.13). @FixedPointList@ gives every stage.
fixedPoint :: (Kernel :> es) => Bool -> Expr -> Eff es (Maybe Expr)
fixedPoint listed e = case args e of
  [f, x] -> run f x Nothing
  [f, x, n] | Just k <- count n -> run f x (Just k)
  _ -> pure Nothing
  where
    run f x bound = do
      cfg <- kernelConfig
      xs <- go f cfg.iterationLimit bound x
      pure (Just (if listed then apply sList xs else fromMaybe x (viaNonEmpty last xs)))
    go f budget bound x
      | bound == Just 0 = pure [x]
      | budget <= 0 = [x] <$ emitMessage (systemSymbol "$IterationLimit") "itlim" [Int_ 0]
      | otherwise =
          evaluate (mkApp f (V.singleton x)) >>= \y ->
            if y == x then pure [x, y] else (x :) <$> go f (budget - 1) (subtract 1 <$> bound) y

-- * Output

-- | @Print[e₁, …]@ queues its evaluated arguments for the front end, beside
-- the messages, and is @Null@ (§4.7, D40).
printRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
printRule e = Just sNullE <$ emitOutput (args e)
