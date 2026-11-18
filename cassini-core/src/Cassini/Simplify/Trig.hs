{-# LANGUAGE PatternSynonyms #-}

-- | Trigonometric expansion, contraction and simplification, circular and
-- hyperbolic (DESIGN.md §4.12).
--
-- Source: @references/papers/textbooks/cohen2002_*.pdf@ §7.1 (Fig. 7.3,
-- @Expand_trig@ and @Expand_trig_rules@, the multiple-angle formulas
-- (7.20)–(7.21), Exercises 5, 8 and 9), §7.2 (Figs. 7.6–7.8,
-- @Contract_trig@, @Contract_trig_rules@ and @Contract_trig_product@; the
-- power reductions (7.35)–(7.36), Exercises 7 and 9; Fig. 7.10,
-- @Simplify_trig@), §5.2 (@Trig_substitute@) and §4.2 Exercise 12
-- (@Separate_sin_cos@).
--
-- The hyperbolic extension (Exercises 9 of §7.1 and §7.2) separates a
-- product's operands three ways — circular, hyperbolic, the rest — and
-- contracts each group alone, so nothing contracts @Sin[x] Sinh[y]@.
--
-- Every intermediate is built with "Cassini.Simplify.Elementary"'s 'nodeE',
-- so a @Cos[π/6]@ that expansion exposes becomes a number mid-algorithm,
-- which Example 7.17 needs. An argument a formula builds is algebraically
-- expanded before the function is applied: Definitions 7.4 and 7.11 require
-- every complete subexpression to be expanded, and @Cos[2 (x + y)]@ and
-- @Cos[2 x + 2 y]@ would otherwise be two spellings that do not cancel.
module Cassini.Simplify.Trig
  ( expandTrig,
    contractTrig,
    expandTrigRules,
    trigSubstitute,
    simplifyTrig,
    isTrigExpanded,
    isTrigContracted,
  )
where

import Cassini.Core.Expr (Expr, exprArgs, mkNumber, pattern App, pattern Call, pattern Int_, pattern Num, pattern Sym)
import Cassini.Core.Symbol (sPlus, sPower, sTimes)
import Cassini.Number (Number (NInt), fromRational')
import Cassini.Simplify.Automatic (Undefined (..))
import Cassini.Simplify.Elementary (Fn (..), fnOf, fnSymbol, nodeE)
import Cassini.Simplify.Rational (algebraicExpand, algebraicExpandFrom, choose, denominator', expandMainOp, isAlgebraicExpanded, numerator', rationalizeExpression)
import Data.HashSet qualified as HashSet
import Data.Vector qualified as V

-- $setup
-- >>> import Cassini.Core.Expr (apply, mkSymbol)
-- >>> import Cassini.Core.Symbol (globalSymbol)
-- >>> let x = mkSymbol (globalSymbol "x"); y = mkSymbol (globalSymbol "y")

-- | Which family a sine or cosine belongs to.
data Family = Circular | Hyperbolic
  deriving stock (Eq)

-- | The sine and cosine of a family.
sinOf, cosOf :: Family -> Fn
sinOf = \case
  Circular -> Sin
  Hyperbolic -> Sinh
cosOf = \case
  Circular -> Cos
  Hyperbolic -> Cosh

-- | A sine or cosine of either family: its family, whether it is the sine,
-- and its argument.
sinCos :: Expr -> Maybe (Family, Bool, Expr)
sinCos = \case
  Call f [a] -> case fnOf f of
    Just Sin -> Just (Circular, True, a)
    Just Cos -> Just (Circular, False, a)
    Just Sinh -> Just (Hyperbolic, True, a)
    Just Cosh -> Just (Hyperbolic, False, a)
    _ -> Nothing
  _ -> Nothing

-- | Cohen's @Trig_substitute@ and its hyperbolic counterpart: @Tan@, @Cot@,
-- @Sec@ and @Csc@ in terms of @Sin@ and @Cos@, at every node. Each node is
-- normalized as it is rebuilt, so a denominator that becomes 0 on the way
-- is 'Undefined', as in the procedures that call it.
--
-- >>> trigSubstitute (apply (fnSymbol Tan) [x])
-- Right Times[Power[Cos[x], -1], Sin[x]]
trigSubstitute :: Expr -> Either Undefined Expr
trigSubstitute = go
  where
    go v = case v of
      App h as -> do
        h' <- case h of
          App _ _ -> go h
          _ -> Right h
        as' <- traverse go as
        w <- nodeE h' as'
        substitute w
      _ -> Right v
    substitute w = case w of
      Call f [a] | Just fn <- fnOf f -> case fn of
        Tan -> quotient Sin Cos a
        Cot -> quotient Cos Sin a
        Sec -> reciprocal Cos a
        Csc -> reciprocal Sin a
        Tanh -> quotient Sinh Cosh a
        Coth -> quotient Cosh Sinh a
        Sech -> reciprocal Cosh a
        Csch -> reciprocal Sinh a
        _ -> Right w
      _ -> Right w
    quotient f g a = do
      n <- call f a
      d <- call g a >>= (`power` Int_ (-1))
      times [n, d]
    reciprocal g a = call g a >>= (`power` Int_ (-1))

-- | Cohen's @Expand_trig@ (Fig. 7.3), strengthened as §7.1 Exercise 8 asks
-- so that every complete subexpression is also algebraically expanded, and
-- extended to @Sinh@ and @Cosh@ (Exercise 9). @Tan@ and the others are
-- substituted first.
--
-- >>> expandTrig (apply (fnSymbol Sin) [apply sPlus [x, y]])
-- Right Plus[Times[Cos[y], Sin[x]], Times[Cos[x], Sin[y]]]
expandTrig :: Expr -> Either Undefined Expr
expandTrig = trigSubstitute >=> go
  where
    go u = case u of
      App h as -> do
        h' <- case h of
          App _ _ -> go h
          _ -> Right h
        as' <- traverse go as
        v <- nodeE h' as'
        w <- case sinCos v of
          Just (fam, isSin, a) -> pick isSin <$> rulesFor fam a
          Nothing -> Right v
        algebraicExpandFrom (expanded as') w
      _ -> Right u
    pick isSin (s, c) = if isSin then s else c
    -- The operands, and theirs: each is a result of go, so expanded, and a
    -- rebuilt node reuses them, a sum's terms spliced in a level down.
    expanded as' = HashSet.fromList (concatMap (\a -> a : V.toList (exprArgs a)) (V.toList as'))

-- | Cohen's @Expand_trig_rules@: the pair @(sin A, cos A)@, so that a sum of
-- @n@ terms costs @2 (n - 1)@ rule applications (§7.1 Exercise 6). Not
-- algebraically expanded.
expandTrigRules :: Expr -> Either Undefined (Expr, Expr)
expandTrigRules = rulesFor Circular

-- | @Expand_trig_rules@ for either family.
rulesFor :: Family -> Expr -> Either Undefined (Expr, Expr)
rulesFor fam a = case a of
  Call p ts@(_ : _ : _) | p == sPlus -> sumRules fam ts
  Call t (Int_ n : _ : _) | t == sTimes -> do
    theta <- times [mkNumber (fromRational' (1 / fromInteger n)), a]
    (s1, c1) <- rulesFor fam theta
    let m = abs n
    sinN <- multiple fam True m s1 c1
    cosN <- multiple fam False m s1 c1
    -- sin and sinh are odd, cos and cosh even (§7.1 Exercise 5)
    sinN' <- if n < 0 then times [Int_ (-1), sinN] else Right sinN
    pure (sinN', cosN)
  _ -> (,) <$> call (sinOf fam) a <*> call (cosOf fam) a

-- | Lines 1–6 of @Expand_trig_rules@, on the terms of the sum: the first
-- term's pair, and the pair of the rest by recursion. Cohen's line 3 forms
-- the rest as the sum @A - Operand(A, 1)@; recursing on the list of terms
-- instead gives the same pairs without building a sum of the remaining terms
-- at every level, which would make the construction quadratic in the
-- number of terms (§8.4).
sumRules :: Family -> [Expr] -> Either Undefined (Expr, Expr)
sumRules fam = \case
  [t] -> rulesFor fam t
  t : rest -> do
    (sf, cf) <- rulesFor fam t
    (sr, cr) <- sumRules fam rest
    s <- sequence [times [sf, cr], times [cf, sr]] >>= plus
    c <- case fam of
      Circular -> sequence [times [cf, cr], times [Int_ (-1), sf, sr]] >>= plus
      Hyperbolic -> sequence [times [cf, cr], times [sf, sr]] >>= plus
    pure (s, c)
  [] -> (,) <$> call (sinOf fam) (Int_ 0) <*> call (cosOf fam) (Int_ 0)

-- | The multiple-angle formulas (7.20)–(7.21), and their hyperbolic
-- counterparts from §7.1 Exercise 9: @sin(nθ)@ or @cos(nθ)@ for @n ≥ 1@ in
-- terms of @s = sin θ@ and @c = cos θ@.
multiple :: Family -> Bool -> Integer -> Expr -> Expr -> Either Undefined Expr
multiple fam isSin n s c = do
  terms <- forM [j | j <- [0 .. n], odd j == isSin] $ \j -> do
    let sign = case fam of
          Circular -> if isSin then (-1) ^ ((j - 1) `div` 2) else (-1) ^ (j `div` 2)
          Hyperbolic -> 1
    cj <- power c (Int_ (n - j))
    sj <- power s (Int_ j)
    times [Int_ (sign * choose n j), cj, sj]
  plus terms

-- | Cohen's @Contract_trig@ (Fig. 7.6), for both families.
--
-- >>> contractTrig (apply sTimes [apply (fnSymbol Sin) [x], apply (fnSymbol Cos) [x]])
-- Right Times[Rational[1, 2], Sin[Times[2, x]]]
contractTrig :: Expr -> Either Undefined Expr
contractTrig u = case u of
  App h as -> do
    h' <- case h of
      App _ _ -> contractTrig h
      _ -> Right h
    as' <- traverse contractTrig as
    v <- nodeE h' as'
    if isProductOrPower v then contractRules v else Right v
  _ -> Right u

isProductOrPower :: Expr -> Bool
isProductOrPower = \case
  Call f _ -> f == sTimes || f == sPower
  _ -> False

-- | Cohen's @Contract_trig_rules@ (Fig. 7.7), with the three-way separation.
contractRules :: Expr -> Either Undefined Expr
contractRules u = do
  v <- expandMainOp u
  case v of
    Call p _ | p == sPower -> contractPower v
    Call t fs | t == sTimes -> do
      let (c, circ, hyp) = separate fs
      circ' <- contractGroup circ
      hyp' <- contractGroup hyp
      case (circ', hyp') of
        (Nothing, Nothing) -> Right v
        _ -> do
          rest <- times c
          d1 <- maybe (times circ) Right circ'
          d2 <- maybe (times hyp) Right hyp'
          times [rest, d1, d2] >>= expandMainOp
    Call p ys | p == sPlus -> traverse (\y -> if isProductOrPower y then contractRules y else Right y) ys >>= plus
    _ -> Right v

-- | One family's factors, contracted: 'Nothing' when there is nothing to
-- contract (no factor, or a single sine or cosine).
contractGroup :: [Expr] -> Either Undefined (Maybe Expr)
contractGroup = \case
  [] -> Right Nothing
  [d]
    | isJust (sinCos d) -> Right Nothing
    | otherwise -> Just <$> contractPower d
  ds -> times ds >>= fmap Just . contractProduct

-- | @Separate_sin_cos@, three ways: the other factors, the circular ones and
-- the hyperbolic ones, where a sine or cosine to a positive integer power
-- counts as its family's.
separate :: [Expr] -> ([Expr], [Expr], [Expr])
separate = foldr place ([], [], [])
  where
    place f (c, circ, hyp) = case family f of
      Just Circular -> (c, f : circ, hyp)
      Just Hyperbolic -> (c, circ, f : hyp)
      Nothing -> (f : c, circ, hyp)
    family f = case f of
      Call p [b, Int_ n] | p == sPower, n > 0 -> (\(fam, _, _) -> fam) <$> sinCos b
      _ -> (\(fam, _, _) -> fam) <$> sinCos f

-- | Cohen's @Contract_trig_power@ (§7.2 Exercise 7, and Exercise 9 for the
-- hyperbolic pair): a positive integer power of a sine or cosine by the
-- power reductions, unfolded, one formula per parity; anything else as it is.
contractPower :: Expr -> Either Undefined Expr
contractPower v = case v of
  Call p [b, Int_ n]
    | p == sPower,
      n > 0,
      Just (fam, isSin, theta) <- sinCos b -> do
        let half = n `div` 2
            signOf j = case (fam, isSin) of
              (_, False) -> 1
              (Circular, True) -> (-1) ^ half * (-1) ^ j
              (Hyperbolic, True) -> (-1) ^ j
            fn
              | isSin && odd n = sinOf fam
              | otherwise = cosOf fam
        terms <- forM [0 .. n] $ \j -> do
          arg <- times [Int_ (n - 2 * j), theta] >>= algebraicExpand
          f <- call fn arg
          times [mkNumber (fromRational' (fromInteger (signOf j * choose n j) / 2 ^ n)), f]
        plus terms
  _ -> Right v

-- | Cohen's @Contract_trig_product@ (Fig. 7.8): a product of sines and
-- cosines of one family and their positive integer powers.
contractProduct :: Expr -> Either Undefined Expr
contractProduct u = case u of
  Call t [a, b] | t == sTimes -> case (a, b) of
    (Call p _, _) | p == sPower -> do
      a' <- contractPower a
      times [a', b] >>= contractRules
    (_, Call p _) | p == sPower -> do
      b' <- contractPower b
      times [a, b'] >>= contractRules
    _
      | Just (fam, sinA, theta) <- sinCos a,
        Just (_, sinB, phi) <- sinCos b -> do
          sumArg <- plus [theta, phi] >>= algebraicExpand
          diffArg <- difference theta phi
          revArg <- difference phi theta
          let half f x = call f x >>= \y -> times [mkNumber (fromRational' (1 / 2)), y]
              neg x = x >>= \y -> times [Int_ (-1), y]
          terms <- case (fam, sinA, sinB) of
            (Circular, True, True) -> sequence [half Cos diffArg, neg (half Cos sumArg)]
            (Circular, False, False) -> sequence [half Cos sumArg, half Cos diffArg]
            (Circular, True, False) -> sequence [half Sin sumArg, half Sin diffArg]
            (Circular, False, True) -> sequence [half Sin sumArg, half Sin revArg]
            (Hyperbolic, True, True) -> sequence [half Cosh sumArg, neg (half Cosh diffArg)]
            (Hyperbolic, False, False) -> sequence [half Cosh sumArg, half Cosh diffArg]
            (Hyperbolic, True, False) -> sequence [half Sinh sumArg, half Sinh diffArg]
            (Hyperbolic, False, True) -> sequence [half Sinh sumArg, half Sinh revArg]
          plus terms
    _ -> Right u
  Call t (a : rest@(_ : _ : _)) | t == sTimes -> do
    b <- times rest >>= contractProduct
    times [a, b] >>= contractRules
  _ -> Right u
  where
    difference x y = times [Int_ (-1), y] >>= \ny -> plus [x, ny] >>= algebraicExpand

-- | Cohen's @Simplify_trig@ (Fig. 7.10): substitute, rationalize, then
-- expand and contract the numerator and the denominator separately. A
-- denominator that contracts to 0 is 'ZeroDenominator', or 'ZeroOverZero'
-- when the numerator does too; one that contracts to a number is
-- distributed over the numerator.
simplifyTrig :: Expr -> Either Undefined Expr
simplifyTrig u = do
  w <- trigSubstitute u >>= rationalizeExpression
  n <- numerator' w >>= expandTrig >>= contractTrig
  d <- denominator' w >>= expandTrig >>= contractTrig
  case d of
    Int_ 0 -> Left (if n == Int_ 0 then ZeroOverZero else ZeroDenominator)
    -- A numeric denominator is distributed over the numerator: a number does
    -- not distribute over a sum on its own (D29), and rationalization gave
    -- the numerator integer coefficients, so n/16 would otherwise stay
    -- (1/16)·(16 a + 16 b).
    Num _ -> do
      r <- power d (Int_ (-1))
      times [n, r] >>= expandMainOp
    _ -> do
      r <- power d (Int_ (-1))
      times [n, r]

-- | Definition 7.4, strengthened per §7.1 Exercise 8 and extended to the
-- hyperbolic pair: no argument of a sine or cosine is a sum or a product with
-- an integer operand, and every complete subexpression is algebraically
-- expanded.
isTrigExpanded :: Expr -> Bool
isTrigExpanded u = isAlgebraicExpanded u && everyNode ok u
  where
    ok v = case sinCos v of
      Just (_, _, a) -> not (isSumOrIntegerProduct a)
      Nothing -> True
    isSumOrIntegerProduct = \case
      Call p _ | p == sPlus -> True
      Call t fs | t == sTimes -> any isInteger fs
      _ -> False
    isInteger = \case
      Num (NInt _) -> True
      _ -> False

-- | Definition 7.11, extended to the hyperbolic pair: every product has at
-- most one circular and at most one hyperbolic sine or cosine operand, no
-- power with a positive integer exponent has one as its base, and every
-- complete subexpression is algebraically expanded.
isTrigContracted :: Expr -> Bool
isTrigContracted u = isAlgebraicExpanded u && everyNode ok u
  where
    ok v = case v of
      Call t fs | t == sTimes -> count Circular fs <= 1 && count Hyperbolic fs <= 1
      Call p [b, Int_ n] | p == sPower, n > 0 -> isNothing (sinCos b)
      _ -> True
    count fam = length . filter (\f -> fmap (\(g, _, _) -> g) (sinCos f) == Just fam)

-- | Whether the predicate holds at every node, heads included.
everyNode :: (Expr -> Bool) -> Expr -> Bool
everyNode p u =
  p u && case u of
    App h as -> everyNode p h && all (everyNode p) (V.toList as)
    _ -> True

-- Construction, each node to normal form.

call :: Fn -> Expr -> Either Undefined Expr
call fn a = nodeE (Sym (fnSymbol fn)) (V.singleton a)

times, plus :: [Expr] -> Either Undefined Expr
times = nodeE (Sym sTimes) . V.fromList
plus = nodeE (Sym sPlus) . V.fromList

power :: Expr -> Expr -> Either Undefined Expr
power v w = nodeE (Sym sPower) (V.fromList [v, w])
