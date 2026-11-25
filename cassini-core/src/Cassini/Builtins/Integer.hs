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
import Cassini.Core.Expr (Expr, apply, mkNumber, pattern Call, pattern Int_, pattern Num, pattern Sym)
import Cassini.Core.Symbol (sDirectedInfinity, sE, sIndeterminate, sList, sPi, sPlus, sPower, sTimes, systemSymbol)
import Cassini.Eval.Kernel (Kernel)
import Cassini.Number (fromRational', toRational')
import Cassini.Number.Integer (factorInteger, isProbablePrime)
import Data.List (partition)
import Data.Ratio ((%))
import Effectful (Eff, (:>))

-- | The integer functions, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "Abs" numeric [down absRule],
    define "Sign" numeric [down signRule],
    define "Floor" numeric [down (rounding floor)],
    define "Ceiling" numeric [down (rounding ceiling)],
    define "Round" numeric [down (rounding round)],
    define "Quotient" numeric [down quotientRule],
    define "Mod" numeric [down modRule],
    define "GCD" flatOrderless [down (foldRationals gcdQ 0)],
    define "LCM" flatOrderless [down (foldRationals lcmQ 1)],
    define "Binomial" numeric [down binomialRule],
    define "Factorial" numeric [down factorialRule],
    define "Numerator" [Listable, Protected] [down (fraction fst)],
    define "Denominator" [Listable, Protected] [down (fraction snd)],
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

-- | The sign of an expression known to be a nonzero real number of fixed
-- sign without assumptions: a rational, @Pi@, @E@, a positive base to a
-- real rational power, and products of these. 'Nothing' for anything else.
realSign :: Expr -> Maybe Integer
realSign = \case
  Num n -> Just (signum (numerator (toRational' n)))
  Sym s | s == sPi || s == sE -> Just 1
  Call p [b, Num _] | p == sPower, realSign b == Just 1 -> Just 1
  Call t fs | t == sTimes -> product <$> traverse realSign fs
  _ -> Nothing

-- | A product's numeric coefficient and the rest, @1@ and the expression
-- itself for anything else.
coefficient :: Expr -> (Rational, [Expr])
coefficient = \case
  Call t (Num c : fs) | t == sTimes -> (toRational' c, fs)
  x -> (1, [x])

-- | @Abs@: exact on rationals and on expressions of known sign; @Abs@ of an
-- infinity is @Infinity@; and two identities over ℂ that need no
-- assumptions: @Abs[Abs[z]] = Abs[z]@ and @Abs[c·z] = |c|·Abs[z]@ for a
-- rational @c@.
absRule :: Expr -> Eff es (Maybe Expr)
absRule e = pure $ case args e of
  [x]
    | Just _ <- extendedOf x, Nothing <- rational x -> Just (infinity 1)
    | Just sg <- realSign x -> Just (apply sTimes [Int_ sg, x])
    | Call a [_] <- x, a == systemSymbol "Abs" -> Just x
    | (c, rest@(_ : _)) <- coefficient x, c /= 1 -> Just (apply sTimes [number (abs c), apply (systemSymbol "Abs") [times rest]])
  _ -> Nothing

-- | @Sign@: exact on rationals and on expressions of known sign, @±1@ for
-- @±Infinity@; @Sign[Sign[z]] = Sign[z]@ and @Sign[c·z] = Sign[c]·Sign[z]@.
signRule :: Expr -> Eff es (Maybe Expr)
signRule e = pure $ case args e of
  [x]
    | Just (Finite _) <- extendedOf x, Just sg <- realSign x -> Just (Int_ sg)
    | Just PosInf <- extendedOf x -> Just (Int_ 1)
    | Just NegInf <- extendedOf x -> Just (Int_ (-1))
    | Just sg <- realSign x -> Just (Int_ sg)
    | Call a [_] <- x, a == systemSymbol "Sign" -> Just x
    | (c, rest@(_ : _)) <- coefficient x, c /= 1 -> Just (apply sTimes [Int_ (signum (numerator c)), apply (systemSymbol "Sign") [times rest]])
  _ -> Nothing

times :: [Expr] -> Expr
times = \case
  [x] -> x
  xs -> apply sTimes xs

-- | @Floor[x]@, and @Floor[x, a]@, the multiple of @a@ it rounds to; the
-- same for @Ceiling@ and @Round@. Haskell's 'round' breaks ties to even, as
-- WL's @Round@ does.
rounding :: (Rational -> Integer) -> Expr -> Eff es (Maybe Expr)
rounding f e = pure $ case map rational (args e) of
  [Just r] -> Just (Int_ (f r))
  [Nothing] | [x] <- args e, Just inf <- extendedOf x -> Just (extended inf)
  [Just r, Just a] | a /= 0 -> Just (number (fromInteger (f (r / a)) * a))
  _ -> Nothing

-- | @Quotient[m, n]@ is @Floor[m/n]@; by zero it is @ComplexInfinity@, with
-- @Quotient::infy@.
quotientRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
quotientRule e = case map rational (args e) of
  [Just 0, Just 0] -> Just (Sym sIndeterminate) <$ message "Quotient" "indet" [e]
  [Just _, Just 0] -> Just (apply sDirectedInfinity []) <$ message "Quotient" "infy" [e]
  [Just m, Just n] -> pure (Just (Int_ (floor (m / n))))
  -- WL 15.0.1: Quotient[1, 0, 1] is Indeterminate, with Quotient::indet
  [Just _, Just 0, Just _] -> Just (Sym sIndeterminate) <$ message "Quotient" "indet" [e]
  [Just m, Just n, Just d] -> pure (Just (Int_ (floor ((m - d) / n))))
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
-- least each divides, as WL extends them. The numbers among the arguments
-- collapse to one; what is symbolic stays. @GCD[]@ is 0 and @LCM[]@ 1.
foldRationals :: (Rational -> Rational -> Rational) -> Rational -> Expr -> Eff es (Maybe Expr)
foldRationals f z e = pure $ case (nums, others) of
  ([], []) -> Just (number z)
  (n : ns, []) -> Just (number (foldl' f n ns))
  (n : ns@(_ : _), _) -> Just (apply h (number (foldl' f n ns) : others))
  _ -> Nothing
  where
    (nums, others) = partitionWith (\x -> maybe (Right x) Left (rational x)) (args e)
    h = case e of
      Call s _ -> s
      _ -> sTimes

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
  -- a symbolic n and a non-negative integer k: n(n-1)…(n-k+1)/k!, as WL
  -- expands it (wolfram/PascalBinomial/BasicExamples/2)
  [n, Int_ k] | Nothing <- rational n, k >= 0 -> Just (apply sTimes (number (1 / fromInteger (product [1 .. k])) : [apply sPlus [n, Int_ (negate i)] | i <- [0 .. k - 1]]))
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
    xs = hashNub (concatMap flatten (args e))
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

-- | @Numerator@ and @Denominator@, as WL reads a product: a factor is in
-- the denominator when it is a power whose exponent is a negative number or
-- a product with a negative coefficient, and a rational's denominator is;
-- everything else is in the numerator. The parts are returned to be
-- evaluated.
fraction :: ((Expr, Expr) -> Expr) -> Expr -> Eff es (Maybe Expr)
fraction pick e = pure $ case args e of
  [x] -> Just (pick (both (factors x)))
  _ -> Nothing
  where
    factors = \case
      Call t fs | t == sTimes -> fs
      x -> [x]
    both fs = let sides = map side fs in (times' (mapMaybe fst sides), times' (mapMaybe snd sides))
    times' = \case
      [] -> Int_ 1
      [y] -> y
      ys -> apply sTimes ys
    -- the factor's part above the line, and its part below
    side f = case f of
      Num n -> let r = toRational' n in (Just (Int_ (numerator r)), Just (Int_ (denominator r)))
      Call p [b, w] | p == sPower, negative w -> (Nothing, Just (apply sPower [b, apply sTimes [Int_ (-1), w]]))
      -- a sum in the exponent splits by its terms' signs:
      -- Numerator[E^(x - 1/y)] is E^x (wolfram/Exp/PropertiesAndRelations/5)
      Call p [b, Call s ts]
        | p == sPower,
          s == sPlus,
          any negative ts ->
            let (neg, pos) = partition negative ts
             in (if null pos then Nothing else Just (apply sPower [b, apply sPlus pos]), Just (apply sPower [b, apply sTimes [Int_ (-1), apply sPlus neg]]))
      _ -> (Just f, Nothing)
    negative = \case
      Num n -> toRational' n < 0
      Call t (Num c : _) | t == sTimes -> toRational' c < 0
      _ -> False

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
