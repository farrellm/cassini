{-# LANGUAGE PatternSynonyms #-}

-- | The integer and rational functions: @Abs@, @Sign@, @Floor@, @Ceiling@,
-- @Round@, @Quotient@, @Mod@, @GCD@, @LCM@, @Binomial@, @Factorial@,
-- @Numerator@, @Denominator@, @Max@, @Min@, @PrimeQ@ and @FactorInteger@
-- (DESIGN.md §4.15).
--
-- Each evaluates on exact numbers and leaves a symbolic argument alone:
-- deciding @Abs[x]@ or @Floor[x]@ needs assumptions (D18) or certified
-- numerics (D9). The algorithms are "Cassini.Number.Integer"'s, which cite
-- their sources; @Numerator@ and @Denominator@ are Cohen's
-- (@references/papers/textbooks/cohen2003_*.pdf@ Definition 6.48, through
-- "Cassini.Simplify.Rational").
module Cassini.Builtins.Integer (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, isList, message, sFalseE, sTrueE)
import Cassini.Builtins.Held (unary)
import Cassini.Core.Expr (Expr, apply, mkNumber, pattern Call, pattern Int_, pattern Num, pattern Sym)
import Cassini.Core.Symbol (sDirectedInfinity, sIndeterminate, sList, systemSymbol)
import Cassini.Eval.Kernel (Kernel)
import Cassini.Number (fromRational', toRational')
import Cassini.Number.Integer (factorInteger, isProbablePrime)
import Cassini.Simplify.Rational (denominator', numerator')
import Data.Ratio ((%))
import Effectful (Eff, (:>))

-- | The integer functions, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "Abs" numeric [down (rational1 (Just . abs))],
    define "Sign" numeric [down (rational1 (Just . fromInteger . signum . numerator))],
    define "Floor" numeric [down (rounding floor)],
    define "Ceiling" numeric [down (rounding ceiling)],
    define "Round" numeric [down (rounding round)],
    define "Quotient" numeric [down quotientRule],
    define "Mod" numeric [down modRule],
    define "GCD" flatOrderless [down (foldRationals gcdQ 0)],
    define "LCM" flatOrderless [down (foldRationals lcmQ 1)],
    define "Binomial" numeric [down binomialRule],
    define "Factorial" numeric [down factorialRule],
    define "Numerator" [Listable, Protected] [down (unary numerator')],
    define "Denominator" [Listable, Protected] [down (unary denominator')],
    define "Max" extreme [down (extremum True)],
    define "Min" extreme [down (extremum False)],
    define "PrimeQ" [Listable, Protected] [down primeQ],
    define "FactorInteger" [Listable, Protected] [down factorIntegerRule]
  ]
  where
    numeric = [Listable, NumericFunction, Protected]
    flatOrderless = [Flat, Listable, OneIdentity, Orderless, Protected]
    extreme = [Flat, NumericFunction, OneIdentity, Orderless, Protected]

-- | A rational argument, if the expression is one.
rational :: Expr -> Maybe Rational
rational = \case
  Num n -> Just (toRational' n)
  _ -> Nothing

-- | A rational as an expression.
number :: Rational -> Expr
number = mkNumber . fromRational'

-- | A function of one rational argument.
rational1 :: (Rational -> Maybe Rational) -> Expr -> Eff es (Maybe Expr)
rational1 f e = pure $ case args e of
  [x] | Just r <- rational x -> number <$> f r
  _ -> Nothing

-- | @Floor[x]@, and @Floor[x, a]@, the multiple of @a@ it rounds to; the
-- same for @Ceiling@ and @Round@. Haskell's 'round' breaks ties to even, as
-- WL's @Round@ does.
rounding :: (Rational -> Integer) -> Expr -> Eff es (Maybe Expr)
rounding f e = pure $ case map rational (args e) of
  [Just r] -> Just (Int_ (f r))
  [Just r, Just a] | a /= 0 -> Just (number (fromInteger (f (r / a)) * a))
  _ -> Nothing

-- | @Quotient[m, n]@ is @Floor[m/n]@; by zero it is @ComplexInfinity@, with
-- @Quotient::infy@.
quotientRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
quotientRule e = case map rational (args e) of
  [Just _, Just 0] -> Just (apply sDirectedInfinity []) <$ message "Quotient" "infy" [e]
  [Just m, Just n] -> pure (Just (Int_ (floor (m / n))))
  _ -> pure Nothing

-- | @Mod[m, n]@ has the sign of @n@, so @m = n·Quotient[m, n] + Mod[m, n]@;
-- @Mod[m, n, d]@ is offset to lie in @[d, d + n)@. Modulo zero it is
-- @Indeterminate@, with @Mod::indet@.
modRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
modRule e = case map rational (args e) of
  [Just _, Just 0] -> indet
  [Just m, Just n] -> pure (Just (number (m - n * fromInteger (floor (m / n)))))
  [Just _, Just 0, Just _] -> indet
  [Just m, Just n, Just d] -> pure (Just (number (m - n * fromInteger (floor ((m - d) / n)))))
  _ -> pure Nothing
  where
    indet = Just (Sym sIndeterminate) <$ message "Mod" "indet" [e]

-- | @GCD@ and @LCM@ of rationals: the greatest rational dividing each, the
-- least each divides, as WL extends them. With every argument a number they
-- collapse; otherwise the call stays.
foldRationals :: (Rational -> Rational -> Rational) -> Rational -> Expr -> Eff es (Maybe Expr)
foldRationals f z e = pure (number . foldl' f z <$> traverse rational (args e))

gcdQ, lcmQ :: Rational -> Rational -> Rational
gcdQ a b = gcd (numerator a) (numerator b) % lcm (denominator a) (denominator b)
lcmQ a b
  | a == 0 || b == 0 = 0
  | otherwise = lcm (numerator a) (numerator b) % gcd (denominator a) (denominator b)

-- | @Binomial[n, k]@ for integers: 0 for @k < 0@, and for @n ≥ 0@ with
-- @k > n@; a negative @n@ by @Binomial[n, k] = (-1)^k Binomial[k - n - 1, k]@.
binomialRule :: Expr -> Eff es (Maybe Expr)
binomialRule e = pure $ case args e of
  [Int_ n, Int_ k] -> Just (Int_ (binomial n k))
  _ -> Nothing
  where
    binomial n k
      | k < 0 = 0
      | n >= 0 && k > n = 0
      | n >= 0 = choose n (min k (n - k))
      | otherwise = (-1) ^ k * choose (k - n - 1) k
    choose n k = product [n - k + 1 .. n] `div` product [1 .. k]

-- | @n!@ for a non-negative integer (Cohen's @Simplify_factorial@); a
-- negative integer's is @ComplexInfinity@, the pole of Γ.
factorialRule :: Expr -> Eff es (Maybe Expr)
factorialRule e = pure $ case args e of
  [Int_ n]
    | n >= 0 -> Just (Int_ (product [1 .. n]))
    | otherwise -> Just (apply sDirectedInfinity [])
  _ -> Nothing

-- | @Max@ and @Min@: lists are flattened, and the numbers among the
-- arguments, the infinities @Infinity@ and @-Infinity@ included, collapse to
-- the extreme; what is symbolic remains. @Max[]@ is @-Infinity@ and
-- @Min[]@ @Infinity@.
extremum :: Bool -> Expr -> Eff es (Maybe Expr)
extremum isMax e
  | null xs = pure (Just (infinity (if isMax then -1 else 1)))
  | n : ns <- numeric =
      let best = foldl' (if isMax then max else min) n ns
       in pure (Just (if null symbolic then extended best else rebuild (extended best : symbolic)))
  | otherwise = pure (if flattened then Just (rebuild symbolic) else single)
  where
    xs = concatMap flatten (args e)
    flatten x = if isList x then concatMap flatten (args x) else [x]
    flattened = length xs /= length (args e) || any isList (args e)
    (numeric, symbolic) = partitionWith classify xs
    classify x = maybe (Right x) Left (extendedOf x)
    single = case xs of
      [x] -> Just x
      _ -> Nothing
    rebuild = \case
      [x] -> x
      ys -> apply (if isMax then systemSymbol "Max" else systemSymbol "Min") ys

-- | A number on the extended real line: a rational, or @±Infinity@.
data Extended = NegInf | Finite !Rational | PosInf
  deriving stock (Eq, Ord)

extendedOf :: Expr -> Maybe Extended
extendedOf = \case
  Num n -> Just (Finite (toRational' n))
  Call d [Int_ 1] | d == sDirectedInfinity -> Just PosInf
  Call d [Int_ (-1)] | d == sDirectedInfinity -> Just NegInf
  _ -> Nothing

extended :: Extended -> Expr
extended = \case
  NegInf -> infinity (-1)
  Finite r -> number r
  PosInf -> infinity 1

infinity :: Integer -> Expr
infinity d = apply sDirectedInfinity [Int_ d]

-- | @PrimeQ[n]@: 'True' for an integer whose absolute value is prime,
-- 'False' for anything else that is a number; a symbol stays.
primeQ :: Expr -> Eff es (Maybe Expr)
primeQ e = pure $ case args e of
  [Int_ n] -> Just (if isProbablePrime (abs n) then sTrueE else sFalseE)
  [_] -> Just sFalseE
  _ -> Nothing

-- | @FactorInteger[n]@: @{{p, k}, …}@ with the primes in increasing order,
-- @{-1, 1}@ first for a negative @n@; a rational's denominator's primes
-- come with negative exponents, merged in order. @0@ and @±1@ are their own
-- factor, as WL gives them.
factorIntegerRule :: Expr -> Eff es (Maybe Expr)
factorIntegerRule e = pure $ case args e of
  [Num n] -> Just (pairs (factors (toRational' n)))
  _ -> Nothing
  where
    factors r
      | r == 0 = [(0, 1)]
      | abs r == 1 = [(numerator r, 1)]
      | otherwise =
          [(-1, 1) | r < 0]
            <> sortOn fst ([(p, toInteger k) | (p, k) <- factorInteger (numerator r)] <> [(p, negate (toInteger k)) | (p, k) <- factorInteger (denominator r)])
    pairs ps = apply sList [apply sList [Int_ p, Int_ k] | (p, k) <- ps]
