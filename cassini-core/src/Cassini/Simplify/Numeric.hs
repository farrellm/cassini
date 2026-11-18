{-# LANGUAGE PatternSynonyms #-}

-- | Radical normalization of rational bases (DESIGN.md §4.15).
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
-- The infinity pass of §4.15 is not here yet: it arrives with the
-- control-flow, logic and numbers track (§10).
module Cassini.Simplify.Numeric
  ( simplifyRadical,
    mergeCoefficient,
    simplifyProductE,
  )
where

import Cassini.Core.Expr (Expr, apply, mkNumber, pattern Call, pattern Int_, pattern Num)
import Cassini.Core.Symbol (sPower, sTimes)
import Cassini.Number (Number (NRat), fromRational', toRational')
import Cassini.Number.Integer (isPerfectPower, multiplicity, primesBelow, trialBound)
import Cassini.Simplify.Automatic (Undefined, simplifyProduct)
import Data.HashSet qualified as HashSet
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
      let k = truncate q :: Integer
       in Radical (if even k then 1 else -1) [(-1, q - fromInteger k)]
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
      let k = truncate q :: Integer
       in Radical (fromInteger n ^^ k) [(n, q - fromInteger k)]
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

-- | Cohen's 'simplifyProduct', then step 6's coefficient merge: what
-- @Times@'s built-in downvalue computes.
simplifyProductE :: V.Vector Expr -> Either Undefined Expr
simplifyProductE vs = do
  p <- simplifyProduct vs
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
                k = truncate total :: Integer
                r = total - fromInteger k
                c' = c / fromInteger p ^^ v * fromInteger p ^^ k
             in (c', [apply sPower [Int_ p, Num (fromRational' r)] | r /= 0] <> acc)
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
