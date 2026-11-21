{-# LANGUAGE PatternSynonyms #-}

-- | Radical normalization of rational bases, and the infinity pass for
-- @Plus@, @Times@ and @Power@ (DESIGN.md §4.15).
--
-- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.2 (SPOW-5, which
-- leaves @v^w@ alone and so leaves this to a later pass), and
-- @references/papers/textbooks/vonzurgathen_gerhard2013_*.pdf@ §9.5 and
-- §19.2 for the integer roots and trial division of steps 4 and 5.
--
-- Steps 1–5 of §4.15 are 'simplifyRadical', which @Power@'s built-in
-- downvalue tries after Cohen's 'simplifyPower'; step 6, the coefficient
-- merge, is 'mergeCoefficient', which @Times@'s tries after
-- 'simplifyProduct'. Each is an identity for the principal branch over ℂ.
-- The result is canonical for radicands that are a prime below
-- 'trialBound', or a power of one (D24).
--
-- The infinity pass runs before Cohen's operators, which take every term
-- for finite: it implements the extended-real and Riemann-sphere tables of
-- §4.15, absorbing numbers (never symbols, D25), and guards the terms and
-- factors it leaves against the cancellations that would turn an
-- indeterminate form finite. Its sources are
-- @references/papers/wolfram-language/wolfram_ref_numbers.html@
-- ("Indeterminate and Infinite Results") and
-- @wolfram_ref_directedinfinity.html@; the rows were checked against WL
-- 15.0.1 (§4.15).
module Cassini.Simplify.Numeric
  ( simplifyRadical,
    mergeCoefficient,
    simplifySumE,
    simplifyProductE,
    infinityPower,
    infinityBearing,
    isUnmergedInfinite,
  )
where

import Cassini.Core.Expr (Expr, apply, mkNumber, pattern Call, pattern Int_, pattern Num)
import Cassini.Core.Order (compareCanonical)
import Cassini.Core.Symbol (sDirectedInfinity, sPlus, sPower, sTimes)
import Cassini.Number (Number (NRat), fromRational', toRational')
import Cassini.Number.Integer (isPerfectPower, multiplicity, primesBelow, trialBound)
import Cassini.Simplify.Automatic (Undefined (..), powerBase, powerExponent, simplifyProduct, simplifySum)
import Data.HashSet qualified as HashSet
import Data.List (partition)
import Data.Vector qualified as V

-- $setup
-- >>> import Cassini.Number (Number (..))
-- >>> import Data.Ratio ((%))

-- | A product of a rational coefficient and radicals @n^q@, each @n > 1@
-- (or @n = -1@) and @q@ a non-integer rational.
data Radical = Radical !Rational ![(Integer, Rational)]

-- | Steps 1–5 of §4.15 for @v^q@, @v@ rational and @q@ a non-integer
-- rational: 'Nothing' when @v^q@ is already normal.
--
-- >>> simplifyRadical (NInt 8) (NRat (1 % 2))
-- Just (Right Times[2, Power[2, Rational[1, 2]]])
-- >>> simplifyRadical (NInt 2) (NRat (1 % 2))
-- Nothing
simplifyRadical :: Number -> Number -> Maybe (Either Undefined Expr)
simplifyRadical v (NRat q)
  | b == 0 || b == 1 = Nothing
  -- an integer radicand that is already normal, without building it
  | Radical 1 [(n, q')] <- rad, denominator b == 1, n == numerator b, q' == q = Nothing
  | otherwise =
      let r = build rad
       in if r == Right (apply sPower [mkNumber v, mkNumber (NRat q)]) then Nothing else Just r
  where
    b = toRational' v
    rad = radical b q
simplifyRadical _ _ = Nothing

-- | The normal form of @v^q@ as a 'Radical'.
radical :: Rational -> Rational -> Radical
radical v q
  -- step 3 alone: (-1)^q
  | v == -1 =
      let (k, r) = properFraction q :: (Integer, Rational)
       in Radical (if even k then 1 else -1) [(-1, r)]
  -- step 1: a negative base
  | v < 0 = radical (-1) q `times` radical (negate v) q
  -- step 2: a fraction
  | denominator v /= 1 = radical (fromInteger (numerator v)) q `times` radical (fromInteger (denominator v)) (negate q)
  | otherwise = integral (numerator v) q

-- | Steps 3–5 for an integer radicand @n ≥ 1@.
integral :: Integer -> Rational -> Radical
integral n q
  | n == 1 = Radical 1 []
  | denominator q == 1 = Radical (fromInteger n ^^ numerator q) []
  -- step 4: a perfect power, whose exponent may now be an integer
  | Just (m, j) <- isPerfectPower n = integral m (fromInteger j * q)
  -- step 5: b-th powers of primes below the bound
  | (c, n') <- extract, n' /= n = Radical c [] `times` integral n' q
  -- step 3: the integer part of the exponent, truncated toward zero
  | abs q > 1 =
      let (k, r) = properFraction q :: (Integer, Rational)
       in Radical (fromInteger n ^^ k) [(n, r)]
  | otherwise = Radical 1 [(n, q)]
  where
    b = denominator q
    a = numerator q
    -- The residue r is n with every prime so far divided out. Stops once
    -- p² exceeds it: no later prime's square, so no b-th power for b ≥ 2,
    -- divides it, rather than walking every prime below the bound.
    extract = pull (1, n, n) (primesBelow trialBound)
    pull (c, m, r) = \case
      p : ps
        | p * p <= r ->
            let (e, r') = multiplicity p r
                t = e `div` b
             in pull (if t == 0 then (c, m, r') else (c * fromInteger p ^^ (a * t), m `div` (p ^ (b * t)), r')) ps
      _ -> (c, m)

times :: Radical -> Radical -> Radical
times (Radical c xs) (Radical d ys) = Radical (c * d) (xs <> ys)

-- | The product, through Cohen's operator and the coefficient merge.
build :: Radical -> Either Undefined Expr
build (Radical c xs) = simplifyProductE (V.fromList (Num (fromRational' c) : [apply sPower [Int_ n, Num (fromRational' e)] | (n, e) <- xs]))

-- | The infinity pass, then Cohen's 'simplifySum': what @Plus@'s built-in
-- downvalue computes.
simplifySumE :: V.Vector Expr -> Either Undefined Expr
simplifySumE vs = fromMaybe (simplifySum vs) (infinitySum vs)

-- | The infinity pass, then Cohen's 'simplifyProduct' and step 6's
-- coefficient merge: what @Times@'s built-in downvalue computes.
simplifyProductE :: V.Vector Expr -> Either Undefined Expr
simplifyProductE vs = fromMaybe (cohen vs) (infinityProduct vs)
  where
    cohen ws = do
      p <- simplifyProduct ws
      pure (fromMaybe p (mergeCoefficient p))

-- | Step 6 of §4.15, on a product already simplified: the coefficient's
-- multiplicity of each prime @p@ below 'trialBound' with a factor @p^e@ moves
-- into the exponent, and the total is split again as in step 3. 'Nothing'
-- when nothing moves.
--
-- >>> import Cassini.Core.Expr (apply)
-- >>> mergeCoefficient (apply sTimes [Num (NRat (1 % 2)), apply sPower [Int_ 2, Num (NRat (1 % 2))]])
-- Just Power[2, Rational[-1, 2]]
mergeCoefficient :: Expr -> Maybe Expr
mergeCoefficient = \case
  Call t (Num c : fs)
    | t == sTimes,
      any isPrimeRadical fs ->
        let (c', fs') = foldr merge (toRational' c, []) fs
         in if c' == toRational' c
              then Nothing
              else either (const Nothing) Just (simplifyProduct (V.fromList (Num (fromRational' c') : fs')))
  _ -> Nothing
  where
    merge f (c, acc) = case f of
      Call pw [Int_ p, Num (NRat e)]
        | pw == sPower,
          isSmallPrime p ->
            let v = valuation p c
                total = fromInteger v + e
                (k, r) = properFraction total :: (Integer, Rational)
                c' = c / fromInteger p ^^ v * fromInteger p ^^ k
                -- an unchanged exponent keeps its node
                f' = if r == e then f else apply sPower [Int_ p, Num (fromRational' r)]
             in (c', [f' | r /= 0] <> acc)
      _ -> (c, f : acc)
    isPrimeRadical = \case
      Call pw [Int_ p, Num (NRat _)] -> pw == sPower && isSmallPrime p
      _ -> False

-- | The multiplicity of @p@ in a rational: positive in the numerator,
-- negative in the denominator.
valuation :: Integer -> Rational -> Integer
valuation p c = fst (multiplicity p (numerator c)) - fst (multiplicity p (denominator c))

isSmallPrime :: Integer -> Bool
isSmallPrime p = HashSet.member p smallPrimes

smallPrimes :: HashSet Integer
smallPrimes = HashSet.fromList (primesBelow trialBound)
{-# NOINLINE smallPrimes #-}

-- The infinity pass.

-- | An infinity the tables decide on: @DirectedInfinity[±1]@, or
-- @ComplexInfinity@, @DirectedInfinity[]@. Directions other than @±1@ wait
-- for complex numbers (D20).
data Infinite = Real !Integer | Complex
  deriving stock (Eq)

infiniteOf :: Expr -> Maybe Infinite
infiniteOf = \case
  Call d [] | d == sDirectedInfinity -> Just Complex
  Call d [Int_ k] | d == sDirectedInfinity, k == 1 || k == -1 -> Just (Real k)
  _ -> Nothing

infinite :: Infinite -> Expr
infinite = \case
  Real d -> apply sDirectedInfinity [Int_ d]
  Complex -> apply sDirectedInfinity []

-- | Whether an expression is infinity-bearing (§4.15): @DirectedInfinity[…]@
-- itself, a sum with an infinity-bearing term, a product with an
-- infinity-bearing factor, or a power of an infinity-bearing base to a
-- positive rational. An infinity in a function's argument or an exponent
-- does not count.
infinityBearing :: Expr -> Bool
infinityBearing = \case
  Call d _ | d == sDirectedInfinity -> True
  Call p ts | p == sPlus || p == sTimes -> any infinityBearing ts
  Call pw [b, Num e] | pw == sPower, toRational' e > 0 -> infinityBearing b
  _ -> False

indeterminate :: Maybe (Either Undefined Expr)
indeterminate = Just (Left InfinityIndeterminate)

-- | The pass on a sum's terms; 'Nothing' when it has nothing to say and
-- Cohen's operator is to run as it would. The terms of a numeric multiple of
-- a sum count as terms here, so that @u - u@ for a sum @u@ is seen: what
-- would cancel is an infinity against one of the other direction, or two
-- like infinity-bearing terms of opposite sign. Otherwise the numbers are
-- absorbed into the infinities, and every other term stays.
infinitySum :: V.Vector Expr -> Maybe (Either Undefined Expr)
infinitySum vs
  | not (V.any infinityBearing vs) = Nothing
  | conflicting (mapMaybe infiniteOf spread) || cancelling spread = indeterminate
  | otherwise = case mapMaybe infiniteOf ts of
      [] -> Nothing
      d : _ ->
        let others = [t | t <- ts, isNothing (infiniteOf t), not (isNumber t)]
         in Just (if null others then Right (infinite d) else simplifySum (V.fromList (others <> [infinite d])))
  where
    ts = V.toList vs
    spread = concatMap (expandTerm 1) ts
    conflicting ds = (Complex `elem` ds && length ds > 1) || (Real 1 `elem` ds && Real (-1) `elem` ds)

-- | A term, with a numeric multiple of a sum spread over the sum's terms;
-- only for finding cancellations, never as a result.
expandTerm :: Rational -> Expr -> [Expr]
expandTerm c = \case
  Call p ss | p == sPlus -> concatMap (expandTerm c) ss
  Call t [Num k, Call p ss] | t == sTimes, p == sPlus -> concatMap (expandTerm (c * toRational' k)) ss
  u
    | c == 1 -> [u]
    | Just (Real d) <- infiniteOf u -> [infinite (Real (signum (numerator c) * d))]
    | Just Complex <- infiniteOf u -> [u]
    | Call t (Num k : fs) <- u, t == sTimes -> [apply sTimes (Num (fromRational' (c * toRational' k)) : fs)]
    | otherwise -> [apply sTimes [Num (fromRational' c), u]]

-- | Two infinity-bearing terms with the same term part (Cohen's @Term@)
-- whose coefficients have opposite signs, a @DirectedInfinity[-1]@ factor
-- counting as a sign, as in @u - u@ and @2u - u@; or with the same term
-- part holding @ComplexInfinity@, which has no sign to compare.
cancelling :: [Expr] -> Bool
cancelling ts = or [opposite a b | (i, a) <- zip [0 :: Int ..] signed, (j, b) <- zip [0 ..] signed, i < j]
  where
    signed = [(sg, part) | t <- ts, infinityBearing t, let (sg, part) = signedTerm t]
    opposite (s1, p1) (s2, p2) = p1 == p2 && (s1 * s2 < 0 || any ((== Just Complex) . infiniteOf) p1)

-- | A term's sign and its term part, as a list of factors, with every
-- @DirectedInfinity[-1]@ turned to @DirectedInfinity[1]@ and its sign moved
-- into the coefficient.
signedTerm :: Expr -> (Integer, [Expr])
signedTerm u = foldr factor (1, []) (factorsOf u)
  where
    factorsOf = \case
      Call t fs | t == sTimes -> fs
      x -> [x]
    factor f (sg, acc) = case f of
      Num k -> (sg * signum (numerator (toRational' k)), acc)
      _ | Just (Real d) <- infiniteOf f -> (sg * d, infinite (Real 1) : acc)
      _ -> (sg, f : acc)

isNumber :: Expr -> Bool
isNumber = \case
  Num _ -> True
  _ -> False

-- | The pass on a product's factors; 'Nothing' when Cohen's operator is to
-- run as it would. Two factors with one infinity-bearing base and rational
-- exponents of opposite signs are @Indeterminate@ (@u·u^(-1)@); under
-- exponents that are not both rationals they are left unmerged, since the
-- merge is sound or not according to signs the kernel does not know. The
-- numbers and infinities combine by the table: a zero among them is
-- @Indeterminate@, and otherwise the direction is the product of theirs and
-- the coefficient's sign.
infinityProduct :: V.Vector Expr -> Maybe (Either Undefined Expr)
infinityProduct vs
  | not (V.any infinityBearing vs) = Nothing
  | or [opposed a b | (i, a) <- based, (j, b) <- based, i < j, fst a == fst b] = indeterminate
  | not (null infs) =
      if 0 `elem` nums
        then indeterminate
        else
          let d = if Complex `elem` infs then Complex else Real (signum (numerator (product nums)) * product [k | Real k <- infs])
              others = [f | f <- fs, not (isNumber f), isNothing (infiniteOf f)]
           in Just (if null others then Right (infinite d) else withUnmerged (others <> [infinite d]))
  | not (null unmergeable) = Just (withUnmerged fs)
  | otherwise = Nothing
  where
    fs = V.toList vs
    nums = [toRational' n | Num n <- fs]
    infs = mapMaybe infiniteOf fs
    based = zip [0 :: Int ..] [(b, e) | f <- fs, Just b <- [powerBase f], infinityBearing b, Just e <- [powerExponent f]]
    opposed (_, e1) (_, e2) = case (e1, e2) of
      (Num a, Num b) -> signum (toRational' a) * signum (toRational' b) < 0
      _ -> False
    unmergeable = hashNub [b | (_, (b, e)) <- based, (_, (b', e')) <- based, b == b', not (isNumber e && isNumber e'), (b, e) /= (b', e')]
    -- The factors under an unmergeable base are kept apart from Cohen's
    -- merge, and appended in ◁ order: the one non-ASAE product
    -- 'isUnmergedInfinite' admits.
    withUnmerged xs =
      let (kept, rest) = partition (maybe False (`elem` unmergeable) . powerBase) xs
       in if null kept
            then simplifyProduct (V.fromList rest)
            else do
              p <- simplifyProduct (V.fromList rest)
              let ps = case p of
                    Call t ys | t == sTimes -> ys
                    Int_ 1 -> []
                    y -> [y]
              pure (apply sTimes (sortBy compareCanonical (ps <> kept)))

-- | Whether a product is one the infinity pass left unmerged: two or more
-- factors over one infinity-bearing base, not all under rational exponents
-- (§4.15). 'Cassini.Simplify.Elementary.isElementaryNormal' admits it.
isUnmergedInfinite :: Expr -> Bool
isUnmergedInfinite = \case
  Call t fs
    | t == sTimes ->
        let based = [(b, e) | f <- fs, Just b <- [powerBase f], infinityBearing b, Just e <- [powerExponent f]]
         in or [b == b' && not (isNumber e && isNumber e') | (i, (b, e)) <- zip [0 :: Int ..] based, (j, (b', e')) <- zip [0 ..] based, i < j]
  _ -> False

-- | The pass on a power: the table's power and exponent rows, and an
-- infinity-bearing base to the exponent 0. 'Nothing' when Cohen's operator
-- is to run as it would.
infinityPower :: Expr -> Expr -> Maybe (Either Undefined Expr)
infinityPower v w = case (infiniteOf v, w) of
  (Just d, Num e)
    | r == 0 -> indeterminate
    | r < 0 -> Just (Right (Int_ 0))
    | denominator r == 1 -> Just (Right (infinite (raise d (numerator r))))
    | Real (-1) <- d -> Nothing
    | otherwise -> Just (Right (infinite d))
    where
      r = toRational' e
  (Just (Real 1), _)
    | Just (Real 1) <- infiniteOf w -> Just (Right (infinite Complex))
    | Just (Real (-1)) <- infiniteOf w -> Just (Right (Int_ 0))
  (Nothing, _)
    | Num c <- v,
      Just i <- infiniteOf w -> case i of
        Complex -> indeterminate
        Real 1 -> toward (toRational' c)
        Real _
          | toRational' c == 0 -> Just (Right (infinite Complex))
          | otherwise -> toward (recip (toRational' c))
  (Nothing, Num e) | toRational' e == 0, infinityBearing v -> indeterminate
  _ -> Nothing
  where
    raise d n = case d of
      Real k -> Real (k ^ n)
      Complex -> Complex
    toward c
      | c > 1 = Just (Right (infinite (Real 1)))
      | c < -1 = Just (Right (infinite Complex))
      | abs c < 1 = Just (Right (Int_ 0))
      | otherwise = indeterminate
