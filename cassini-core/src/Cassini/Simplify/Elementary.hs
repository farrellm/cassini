{-# LANGUAGE PatternSynonyms #-}

-- | Automatic rules for the elementary functions: special values, parity,
-- periodicity, inverses and @E^(c·Log[z]) → z^c@ (DESIGN.md §4.11).
--
-- Source: @references/papers/textbooks/cohen2002_*.pdf@ §7.2 ("Automatic
-- Simplification of Trigonometric Functions", transformations 1–5 and
-- Fig. 7.9), with the periodicity rule read off WL 15.0.1 (D39).
--
-- These are a second pure layer above Cohen's automatic simplification,
-- which has no function transformations ("Cassini.Simplify.Automatic"'s
-- 'simplifyFunction' is the identity). 'simplifyE' is Cohen's procedure
-- with this layer and §4.15's radical normalization at every node, so it
-- agrees with the evaluator on every built-in; §4.12's algorithms build
-- every intermediate with it.
--
-- Every rule is an identity over ℂ. Not here, because each holds only for
-- some arguments: @Log[E^x] → x@ for symbolic @x@, log expansion,
-- @ArcSin[Sin[x]] → x@ (D18).
module Cassini.Simplify.Elementary
  ( -- * The elementary heads
    Fn (..),
    fnSymbol,
    fnOf,

    -- * One node
    simplifyElementary,
    simplifyExpPower,
    simplifyPowerE,
    simplifyProductE,
    nodeE,
    rebuildE,
    rebuildArgs,
    subterms,

    -- * The procedure
    simplifyE,
    isElementaryNormal,
    everyNode,

    -- * Construction, each node to normal form
    call,
    times,
    plus,
    power,
    negateE,
  )
where

import Cassini.Core.Expr (Expr, apply, exprArgs, mkApp, mkNumber, pattern App, pattern Call, pattern Infinity, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Order (compareCanonical)
import Cassini.Core.Symbol (Symbol, sDivide, sE, sFactorial, sIndeterminate, sMinus, sPi, sPlus, sPower, sSubtract, sTimes, systemSymbol)
import Cassini.Number (Number (NInt), fromRational', normalize, toRational')
import Cassini.Number.Integer (multiplicity)
import Cassini.Simplify.Automatic (Undefined (..), isASAE, simplifyDifference, simplifyFactorial, simplifyPower, simplifyQuotient, simplifySum)
import Cassini.Simplify.Numeric (simplifyProductE, simplifyRadical)
import Data.HashMap.Strict qualified as HashMap
import Data.HashSet qualified as HashSet
import Data.Vector qualified as V

-- $setup
-- >>> import Cassini.Core.Expr (mkSymbol)
-- >>> import Cassini.Core.Symbol (globalSymbol)
-- >>> import Cassini.Number (Number (..))
-- >>> import Data.Ratio ((%))
-- >>> let x = mkSymbol (globalSymbol "x")

-- | The elementary heads of §4.11.
data Fn
  = Sin
  | Cos
  | Tan
  | Cot
  | Sec
  | Csc
  | Sinh
  | Cosh
  | Tanh
  | Coth
  | Sech
  | Csch
  | ArcSin
  | ArcCos
  | ArcTan
  | ArcCot
  | ArcSec
  | ArcCsc
  | Exp
  | Log
  deriving stock (Eq, Show, Enum, Bounded)

instance Hashable Fn where
  hashWithSalt salt = hashWithSalt salt . fromEnum

-- | The head's @System`@ symbol, from a table built once: every rule and
-- every node the procedures build asks for one, and 'systemSymbol' is a
-- lookup in the global symbol table.
fnSymbol :: Fn -> Symbol
fnSymbol fn = fromMaybe (systemSymbol (show fn)) (fnSymbols V.!? fromEnum fn)

fnSymbols :: V.Vector Symbol
fnSymbols = V.fromList [systemSymbol (show fn) | fn <- universe @Fn]
{-# NOINLINE fnSymbols #-}

-- | The elementary head a symbol names, if any.
fnOf :: Symbol -> Maybe Fn
fnOf s = HashMap.lookup s fnTable

fnTable :: HashMap Symbol Fn
fnTable = HashMap.fromList [(fnSymbol fn, fn) | fn <- universe]
{-# NOINLINE fnTable #-}

-- | One elementary-function node whose arguments are already in normal form.
-- 'Nothing': no rule applies, and the node is in normal form.
--
-- >>> simplifyElementary (fnSymbol Sin) (V.singleton (apply sTimes [Int_ (-1), x]))
-- Just (Right Times[-1, Sin[x]])
simplifyElementary :: Symbol -> V.Vector Expr -> Maybe (Either Undefined Expr)
simplifyElementary f vs = do
  fn <- fnOf f
  let r = elementaryNode fn f vs
  if either (const False) (isNode (Sym f) vs) r then Nothing else Just r

-- | The node @f[vs]@, @f@ the symbol of @fn@, to normal form: the node
-- itself when no rule applies.
elementaryNode :: Fn -> Symbol -> V.Vector Expr -> Either Undefined Expr
elementaryNode fn f vs = case (fn, V.toList vs) of
  (_, [x]) -> elementary fn x
  -- Log[b, b^r] is r; any other Log[b, z] is Log[z]/Log[b], as in WL
  -- (wolfram/HoldPattern/BasicExamples/3, wolfram/Log/Scope/SpecificValues/1)
  (Log, [b, z])
    -- base 0 is left alone; base 1 divides by Log[1] = 0
    | b == Int_ 0 -> unchanged
    | b == Int_ 1 -> Left (if z == Int_ 1 then ZeroOverZero else ZeroDenominator)
    -- Log[0]/Log[b] is -∞/Log[b], whose direction is Log[b]'s sign: -∞ for a
    -- base known above 1, ∞ for one known in (0, 1), and left alone
    -- where that sign is not known (WL 15.0.1: Log[x, 0] is -∞/Log[x])
    | z == Int_ 0 -> fromMaybe unchanged (logOfZeroOver b)
    | Just r <- logBase' b z -> Right (Num (fromRational' r))
    | otherwise -> do
        lz <- call Log z
        lb <- call Log b >>= (`power` Int_ (-1))
        times [lz, lb]
  _ -> unchanged
  where
    unchanged = Right (mkApp (Sym f) vs)

-- | @E^(c·Log[z]) → z^c@ for numeric @c@, on a base and exponent in normal
-- form: the principal @z^c@ is defined as @E^(c·Log[z])@.
simplifyExpPower :: Expr -> Expr -> Maybe (Either Undefined Expr)
simplifyExpPower b w = case b of
  Sym e | e == sE -> case w of
    Call l [z] | l == sLog -> Just (Right z)
    Call t [c@(Num _), Call l [z]] | t == sTimes, l == sLog -> Just (nodeE (Sym sPower) (V.fromList [z, c]))
    _ -> Nothing
  _ -> Nothing

-- | Cohen's 'simplifyPower', then §4.15's radicals and 'simplifyExpPower':
-- what @Power@'s built-in downvalue computes.
simplifyPowerE :: Expr -> Expr -> Either Undefined Expr
simplifyPowerE v w = do
  r <- simplifyPower v w
  case r of
    Call p [Num a, Num b] | p == sPower -> fromMaybe (Right r) (simplifyRadical a b)
    Call p [b, e] | p == sPower -> fromMaybe (Right r) (simplifyExpPower b e)
    _ -> Right r

-- | One node whose head and arguments are in normal form, to normal form.
-- When a rule rewrites the node, the parts of its result that are new are
-- normalized in turn, and the parts it took from the arguments are not
-- revisited: so building a sum of two shared subterms costs what the new
-- nodes cost, not what the subterms do (§8.4).
nodeE :: Expr -> V.Vector Expr -> Either Undefined Expr
nodeE h vs = do
  r <- step h vs
  if isNode h vs r then pure r else settle (subterms 2 vs) r

-- | Whether the expression is the node @h[vs]@, without building it.
isNode :: Expr -> V.Vector Expr -> Expr -> Bool
isNode h vs = \case
  App h' vs' -> h' == h && vs' == vs
  _ -> False

-- | The rule for one node, by its head.
step :: Expr -> V.Vector Expr -> Either Undefined Expr
step h vs = case h of
  Sym f -> case fnOf f of
    Just fn
      | V.any isIndeterminate vs -> Right (Sym sIndeterminate)
      | otherwise -> elementaryNode fn f vs
    Nothing
      | f == sPlus || f == sTimes || f == sPower, V.any isIndeterminate vs -> Right (Sym sIndeterminate)
      | f == sPlus -> simplifySum (orderless f vs)
      | f == sTimes -> simplifyProductE (orderless f vs)
      | f == sPower, [v, w] <- V.toList vs -> simplifyPowerE v w
      -- Cohen's operators, as 'Cassini.Simplify.Automatic.simplify' rewrites them
      | f == sDivide, [x, y] <- V.toList vs -> simplifyQuotient x y
      | f == sSubtract || f == sMinus, not (V.null vs) -> simplifyDifference vs
      | f == sFactorial, [v] <- V.toList vs -> simplifyFactorial v
      | otherwise -> Right (mkApp h vs)
  _ -> Right (mkApp h vs)
  where
    isIndeterminate = \case
      Sym s -> s == sIndeterminate
      _ -> False

-- | A @Flat@ and @Orderless@ node's operands as the evaluator hands them to
-- the built-in (§4.4 steps 8–9): nested operands of the same head spliced
-- in, then sorted in ◁ order. Cohen's merges accept any order, but on
-- unsorted operands they are quadratic (§8.4), and the result agrees with
-- the evaluator's either way.
orderless :: Symbol -> V.Vector Expr -> V.Vector Expr
orderless f vs
  | V.length vs < 2 = vs
  | otherwise = V.fromList (sortBy compareCanonical (concatMap splice (V.toList vs)))
  where
    splice v = case v of
      Call g ws | g == f -> ws
      _ -> [v]

-- | The expressions, and their arguments down to the given depth: the
-- subterms a rule's result is likely to reuse, which are already in normal
-- form. 'nodeE' takes two levels of a node's arguments.
subterms :: Int -> V.Vector Expr -> HashSet Expr
subterms depth = V.foldl' (add depth) HashSet.empty
  where
    add d known v
      | d <= 0 = HashSet.insert v known
      | otherwise = V.foldl' (add (d - 1)) (HashSet.insert v known) (exprArgs v)

-- | Normalize a rule's result, bottom up, skipping the subterms known to be
-- normal already.
settle :: HashSet Expr -> Expr -> Either Undefined Expr
settle known u
  | HashSet.member u known = Right u
  | otherwise = case u of
      App h as -> rebuildE (settle known) h as
      _ -> Right u

-- | A node rebuilt bottom-up through 'nodeE': the head when it is compound,
-- then the arguments, each by the given recursion.
rebuildE :: (Expr -> Either Undefined Expr) -> Expr -> V.Vector Expr -> Either Undefined Expr
rebuildE go h as = snd <$> rebuildArgs go h as
{-# INLINE rebuildE #-}

-- | 'rebuildE', with the rebuilt arguments too.
rebuildArgs :: (Expr -> Either Undefined Expr) -> Expr -> V.Vector Expr -> Either Undefined (V.Vector Expr, Expr)
rebuildArgs go h as = do
  h' <- case h of
    App _ _ -> go h
    _ -> Right h
  as' <- traverse go as
  (as',) <$> nodeE h' as'
{-# INLINE rebuildArgs #-}

-- | Cohen's automatic simplification with the elementary rules and §4.15's
-- radical normalization at every node, bottom-up.
--
-- >>> simplifyE (apply (fnSymbol Sin) [apply sPlus [x, apply sTimes [mkNumber (fromRational' (7 / 3)), mkSymbol sPi]]])
-- Right Cos[Plus[Times[Rational[1, 6], Pi], Times[-1, x]]]
simplifyE :: Expr -> Either Undefined Expr
simplifyE u = case u of
  Num n -> Right (mkNumber (normalize n))
  Str _ -> Right u
  Sym _ -> Right u
  App h as -> rebuildE simplifyE h as

-- | An ASAE on which no elementary or radical rule fires, at any node.
isElementaryNormal :: Expr -> Bool
isElementaryNormal u = isASAE u && everyNode nodeNormal u
  where
    nodeNormal = \case
      App h as -> either (const False) (isNode h as) (step h as)
      _ -> True

-- | Whether the predicate holds at every node, heads included.
everyNode :: (Expr -> Bool) -> Expr -> Bool
everyNode p u =
  p u && case u of
    App h as -> everyNode p h && all (everyNode p) as
    _ -> True

-- The rules.

-- | The normal form of @fn[x]@, @x@ normal.
elementary :: Fn -> Expr -> Either Undefined Expr
elementary fn x
  | fn == Exp = power (Sym sE) x
  | fn == Log = logRule x
  | fn `elem` [Sin, Cos, Tan, Cot, Sec, Csc] = circular fn x
  | fn `elem` [Sinh, Cosh, Tanh, Coth, Sech, Csch] = hyperbolic fn x
  | otherwise = inverse fn x

-- | Circular functions: inverses, periodicity, parity, then special values.
circular :: Fn -> Expr -> Either Undefined Expr
circular fn x
  -- Sin[ArcSin[y]] → y
  | Call g [y] <- x, fnOf g == Just (inverseOf fn) = Right y
  -- periodicity: remove k·π/2, leaving |s| ≤ 1/4
  | Just (rest, r) <- piPart x,
    let k = round (2 * r) :: Integer,
    k /= 0 = do
      let s = r - fromInteger k / 2
          (fn', negative) = shift fn (k `mod` 4)
      sπ <- times [Num (fromRational' s), Sym sPi]
      arg <- plus (rest <> [sπ])
      y <- call fn' arg
      if negative then negateE y else Right y
  | leadingNegative x = parity fn x
  | Just s <- constantPi x, Just v <- HashMap.lookup (fn, s) circularValues = v
  | otherwise = Right (call' fn x)

-- | The special values at 0, π/6 and π/4, built once.
circularValues :: HashMap (Fn, Rational) (Either Undefined Expr)
circularValues =
  HashMap.fromList
    [ ((fn, s), v fn)
    | fn <- [Sin, Cos, Tan, Cot, Sec, Csc],
      (s, v) <- [(0, valueAt0), (1 / 6, valueAtSixth), (1 / 4, valueAtQuarter)]
    ]
{-# NOINLINE circularValues #-}

-- | The cofunction and sign for @fn(θ + k·π/2)@, @k@ mod 4: Cohen's item 4.
shift :: Fn -> Integer -> (Fn, Bool)
shift fn k = case fn of
  Sin -> [(Sin, False), (Cos, False), (Sin, True), (Cos, True)] `at` k
  Cos -> [(Cos, False), (Sin, True), (Cos, True), (Sin, False)] `at` k
  Tan -> if even k then (Tan, False) else (Cot, True)
  Cot -> if even k then (Cot, False) else (Tan, True)
  Sec -> [(Sec, False), (Csc, True), (Sec, True), (Csc, False)] `at` k
  Csc -> [(Csc, False), (Sec, False), (Csc, True), (Sec, True)] `at` k
  _ -> (fn, False)
  where
    at xs i = fromMaybe (fn, False) (listToMaybe (drop (fromInteger i) xs))

valueAt0, valueAtSixth, valueAtQuarter :: Fn -> Either Undefined Expr
valueAt0 = \case
  Sin -> Right (Int_ 0)
  Cos -> Right (Int_ 1)
  Tan -> Right (Int_ 0)
  Sec -> Right (Int_ 1)
  _ -> Left Pole
valueAtSixth = \case
  Sin -> rad (1 / 2) 1 0
  Cos -> rad (1 / 2) 3 (1 / 2)
  Tan -> rad 1 3 (-(1 / 2))
  Cot -> rad 1 3 (1 / 2)
  Sec -> rad 2 3 (-(1 / 2))
  _ -> rad 2 1 0
valueAtQuarter = \case
  Sin -> rad 1 2 (-(1 / 2))
  Cos -> rad 1 2 (-(1 / 2))
  Sec -> rad 1 2 (1 / 2)
  Csc -> rad 1 2 (1 / 2)
  _ -> Right (Int_ 1)

-- | @c·p^e@, normalized.
rad :: Rational -> Integer -> Rational -> Either Undefined Expr
rad c p e = simplifyE (apply sTimes [Num (fromRational' c), apply sPower [Int_ p, Num (fromRational' e)]])

-- | Hyperbolic functions: values at 0, and parity.
hyperbolic :: Fn -> Expr -> Either Undefined Expr
hyperbolic fn x
  | Int_ 0 <- x = case fn of
      Sinh -> Right (Int_ 0)
      Tanh -> Right (Int_ 0)
      Cosh -> Right (Int_ 1)
      Sech -> Right (Int_ 1)
      _ -> Left Pole
  | leadingNegative x = parity fn x
  | otherwise = Right (call' fn x)

-- | Inverse circular functions: the forward tables read backwards onto the
-- principal ranges, the poles of @ArcSec@ and @ArcCsc@ at 0, then parity.
inverse :: Fn -> Expr -> Either Undefined Expr
inverse fn x
  | Just v <- HashMap.lookup (fn, x) inverseTable = v
  -- ArcSec[x] is ArcCos[1/x], and ArcCsc[x] ArcSin[1/x]: poles at 0, as WL's
  | Int_ 0 <- x, fn == ArcSec || fn == ArcCsc = Left Pole
  | leadingNegative x = parity fn x
  | otherwise = Right (call' fn x)

-- | The inverse tables, keyed on the spelling the forward tables emit.
inverseTable :: HashMap (Fn, Expr) (Either Undefined Expr)
inverseTable =
  HashMap.fromList
    [ ((fn, key), times [Num (fromRational' r), Sym sPi])
    | (fn, entries) <- tables,
      (Right key, r) <- entries
    ]
  where
    sinValues = [(rad 0 1 0, 0), (rad (1 / 2) 1 0, 1 / 6), (rad 1 2 (-(1 / 2)), 1 / 4), (rad (1 / 2) 3 (1 / 2), 1 / 3), (rad 1 1 0, 1 / 2)]
    tanValues = [(rad 0 1 0, 0), (rad 1 3 (-(1 / 2)), 1 / 6), (rad 1 1 0, 1 / 4), (rad 1 3 (1 / 2), 1 / 3)]
    cscValues = [(rad 1 1 0, 1 / 2), (rad 2 1 0, 1 / 6), (rad 1 2 (1 / 2), 1 / 4), (rad 2 3 (-(1 / 2)), 1 / 3)]
    -- ArcCos[y] = π/2 - ArcSin[y], over [-1, 1]
    cosValues = [(v, 1 / 2 - r) | (v, r) <- sinValues] <> [(neg v, 1 / 2 + r) | (v, r) <- sinValues, r /= 0]
    secValues = [(v, 1 / 2 - r) | (v, r) <- cscValues] <> [(neg v, 1 / 2 + r) | (v, r) <- cscValues]
    cotValues = [(rad 0 1 0, 1 / 2), (rad 1 3 (1 / 2), 1 / 6), (rad 1 1 0, 1 / 4), (rad 1 3 (-(1 / 2)), 1 / 3)]
    neg v = v >>= negateE
    tables =
      [ (ArcSin, sinValues),
        (ArcCos, cosValues),
        (ArcTan, tanValues),
        (ArcCot, cotValues),
        (ArcSec, secValues),
        (ArcCsc, cscValues)
      ]
{-# NOINLINE inverseTable #-}

-- | @Log[1] → 0@, @Log[0]@ undefined, @Log[E^r] → r@ for rational @r@.
logRule :: Expr -> Either Undefined Expr
logRule x = case x of
  Int_ 1 -> Right (Int_ 0)
  Int_ 0 -> Left LogOfZero
  Sym e | e == sE -> Right (Int_ 1)
  Call p [Sym e, r@(Num _)] | p == sPower, e == sE -> Right r
  _ -> Right (call' Log x)

-- | @Log[b, 0]@, for a base other than 0 and 1.
logOfZeroOver :: Expr -> Maybe (Either Undefined Expr)
logOfZeroOver = \case
  Num n
    | n > NInt 1 -> Just (Left LogOfZero)
    | n > NInt 0 -> Just (Right Infinity)
  x | positiveConstant x -> Just (Left LogOfZero)
  -- a positive radical whose factors are all above 1, or all below
  x
    | Just fs@(_ : _) <- positiveRadical x,
      all ((> 0) . snd) fs ->
        Just (Left LogOfZero)
    | Just fs@(_ : _) <- positiveRadical x,
      all ((< 0) . snd) fs ->
        Just (Right Infinity)
  _ -> Nothing

-- | @Pi@ and @E@, the constants known positive.
positiveConstant :: Expr -> Bool
positiveConstant = \case
  Sym c -> c == sPi || c == sE
  _ -> False

-- | @r@ when @z@ is @b^r@ exactly, @r@ rational. @Log[b^r] = r Log[b]@ needs
-- @r·Arg[b]@ in @(-π, π]@, so there are two cases:
--
-- * @b@ and @z@ positive radicals, rationals times positive integers to
--   rational powers, whose exponents over a coprime basis are proportional:
--   @Log[1/2, 1/8]@ is 3 and @Log[Sqrt[2], 8]@ is 6;
-- * @z@ written as a power of @b@, for a base known positive (@Pi@ or @E@)
--   or for @-1 < r ≤ 1@: @Log[x, x^2]@ is not 2 at @x = -1@, where
--   @Log[1]/Log[-1]@ is 0.
--
-- >>> logBase' (apply sPower [mkNumber (NInt 2), mkNumber (NRat (1 % 2))]) (mkNumber (NInt 8))
-- Just (6 % 1)
-- >>> logBase' (mkNumber (NInt 12)) (mkNumber (NInt 18))
-- Nothing
logBase' :: Expr -> Expr -> Maybe Rational
logBase' b z
  | b == z = Just 1
  | Just fb <- positiveRadical b, Just fz <- positiveRadical z = proportion fb fz
  | Call p [b', Num r] <- z,
    p == sPower,
    b' == b,
    let q = toRational' r,
    positiveConstant b || (q > -1 && q <= 1) =
      Just q
  | otherwise = Nothing

-- | A positive radical as integers above 1 with rational exponents: a
-- positive rational, a positive integer to a rational power, or a product of
-- those, which is every positive real number §4.15 normalizes.
positiveRadical :: Expr -> Maybe [(Integer, Rational)]
positiveRadical = \case
  Call t xs | t == sTimes -> concat <$> traverse factor xs
  x -> factor x
  where
    factor = \case
      Num n
        | let q = toRational' n,
          q > 0 ->
            Just ([(numerator q, 1) | numerator q > 1] <> [(denominator q, -1) | denominator q > 1])
      Call p [Int_ n, Num e] | p == sPower, n > 1 -> Just [(n, toRational' e)]
      _ -> Nothing

-- | @r@ with @z = b^r@, for @b@ and @z@ as 'positiveRadical' gives them:
-- over a basis of pairwise coprime integers each has one exponent vector,
-- and @r@ exists when @z@'s is @r@ times @b@'s, @b@'s not being zero.
proportion :: [(Integer, Rational)] -> [(Integer, Rational)] -> Maybe Rational
proportion fb fz = do
  let basis = coprimeBasis (map fst (fb <> fz))
      vb = vector basis fb
      vz = vector basis fz
  (eb, ez) <- find ((/= 0) . fst) (zip vb vz)
  let r = ez / eb
  guard (vz == map (r *) vb)
  Just r
  where
    vector basis fs = [sum [e * fromInteger (fst (multiplicity m n)) | (n, e) <- fs] | m <- basis]

-- | A basis of pairwise coprime integers above 1 over which each of the
-- given integers factors: two members with a common factor @g@ are replaced
-- by their cofactors and @g@ until none has one.
coprimeBasis :: [Integer] -> [Integer]
coprimeBasis = go . ordNub . filter (> 1)
  where
    go ns = case [(a, c, g) | (a : rest) <- tails ns, c <- rest, let g = gcd a c, g > 1] of
      [] -> ns
      (a, c, g) : _ -> go (ordNub (filter (> 1) ([a `div` g, c `div` g, g] <> filter (\n -> n /= a && n /= c) ns)))

-- | Parity, on an argument whose leading operand has a negative
-- coefficient: odd heads pull the sign out, even heads drop it, and the
-- rest are left alone.
parity :: Fn -> Expr -> Either Undefined Expr
parity fn x
  | fn `elem` [Sin, Tan, Cot, Csc, Sinh, Tanh, Coth, Csch, ArcSin, ArcTan, ArcCot, ArcCsc] =
      negateArg x >>= call fn >>= negateE
  | fn `elem` [Cos, Sec, Cosh, Sech] = negateArg x >>= call fn
  | otherwise = Right (call' fn x)

-- | Whether the argument's first operand in ◁ order has a negative
-- coefficient.
leadingNegative :: Expr -> Bool
leadingNegative x = case x of
  Call p (t : _) | p == sPlus -> negativeTerm t
  _ -> negativeTerm x
  where
    negativeTerm = \case
      Num n -> n < NInt 0
      Call t (Num n : _ : _) -> t == sTimes && n < NInt 0
      _ -> False

-- | The argument negated term by term, so that the ◁ order of its terms is
-- kept and its leading sign flips.
negateArg :: Expr -> Either Undefined Expr
negateArg x = case x of
  Call p ts | p == sPlus -> traverse negateE ts >>= plus
  _ -> negateE x

-- | A π term in the argument: @r·π@ alone, or among the terms of a sum,
-- with the other terms.
piPart :: Expr -> Maybe ([Expr], Rational)
piPart x = case x of
  Call p ts | p == sPlus -> case break (isJust . piCoefficient) ts of
    (before, t : after) -> (before <> after,) <$> piCoefficient t
    _ -> Nothing
  _ -> ([],) <$> piCoefficient x

-- | The argument as a constant multiple of π, 0 included.
constantPi :: Expr -> Maybe Rational
constantPi = \case
  Int_ 0 -> Just 0
  x -> piPart x >>= \(rest, r) -> r <$ guard (null rest)

piCoefficient :: Expr -> Maybe Rational
piCoefficient = \case
  Sym p | p == sPi -> Just 1
  Call t [Num r, Sym p] | t == sTimes, p == sPi -> Just (toRational' r)
  _ -> Nothing

inverseOf :: Fn -> Fn
inverseOf = \case
  Sin -> ArcSin
  Cos -> ArcCos
  Tan -> ArcTan
  Cot -> ArcCot
  Sec -> ArcSec
  _ -> ArcCsc

-- Construction, each node to normal form.

-- | @fn[y]@, normalized.
call :: Fn -> Expr -> Either Undefined Expr
call fn y = nodeE (Sym (fnSymbol fn)) (V.singleton y)

-- | The node as it stands, when no rule applies.
call' :: Fn -> Expr -> Expr
call' fn y = apply (fnSymbol fn) [y]

-- | The product and the sum, normalized.
times, plus :: [Expr] -> Either Undefined Expr
times = nodeE (Sym sTimes) . V.fromList
plus = nodeE (Sym sPlus) . V.fromList

-- | @-y@, normalized.
negateE :: Expr -> Either Undefined Expr
negateE y = times [Int_ (-1), y]

-- | @v^w@, normalized.
power :: Expr -> Expr -> Either Undefined Expr
power v w = nodeE (Sym sPower) (V.fromList [v, w])

sLog :: Symbol
sLog = fnSymbol Log
