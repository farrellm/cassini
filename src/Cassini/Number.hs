-- | Exact rationals over 'Integer': normalization, arithmetic and numeric
-- order (DESIGN.md §3.1).
--
-- A 'Number' is an integer or a fraction in lowest terms with a denominator
-- greater than one, so derived 'Eq' is value equality. 'Ord' is numeric order,
-- not constructor order.
module Cassini.Number
  ( Number (NInt, NRat),
    fromInteger',
    fromRational',
    normalize,
    toRational',
    isInteger,
    compareNumber,
    add,
    mul,
    neg,
    divide,
    pow,
  )
where

-- $setup
-- >>> import Data.Ratio ((%))

-- | An exact number.
data Number
  = -- | An integer.
    NInt !Integer
  | -- | A fraction. Invariant: denominator > 1, reduced, sign on the numerator.
    -- Construct through 'fromRational'' to keep it.
    NRat !Rational
  deriving stock (Eq, Show)

-- | Numeric order, not constructor order.
instance Ord Number where
  compare = compareNumber

instance Hashable Number where
  hashWithSalt s = \case
    NInt i -> s `hashWithSalt` (0 :: Int) `hashWithSalt` i
    NRat r -> s `hashWithSalt` (1 :: Int) `hashWithSalt` numerator r `hashWithSalt` denominator r

instance NFData Number where
  rnf = \case
    NInt i -> rnf i
    NRat r -> rnf r

-- | An integer.
fromInteger' :: Integer -> Number
fromInteger' = NInt

-- | A rational, normalized: integral values become 'NInt'.
--
-- >>> fromRational' (4 % 2)
-- NInt 2
fromRational' :: Rational -> Number
fromRational' r
  | denominator r == 1 = NInt (numerator r)
  | otherwise = NRat r

-- | Restore the 'NRat' invariant on a number built with the raw
-- constructor: an integral fraction becomes 'NInt'.
--
-- >>> normalize (NRat (4 % 2))
-- NInt 2
normalize :: Number -> Number
normalize = \case
  NRat r -> fromRational' r
  n -> n

-- | The value as a 'Rational'.
toRational' :: Number -> Rational
toRational' = \case
  NInt i -> fromIntegral i
  NRat r -> r

-- | Whether the number is an integer.
isInteger :: Number -> Bool
isInteger = \case
  NInt _ -> True
  NRat _ -> False

-- | Numeric comparison across both constructors (Cohen's O-1).
--
-- >>> compareNumber (NInt 2) (NRat (5 % 2))
-- LT
compareNumber :: Number -> Number -> Ordering
compareNumber (NInt a) (NInt b) = compare a b
compareNumber a b = compare (toRational' a) (toRational' b)

-- | Exact sum.
add :: Number -> Number -> Number
add (NInt a) (NInt b) = NInt (a + b)
add a b = fromRational' (toRational' a + toRational' b)

-- | Exact product.
mul :: Number -> Number -> Number
mul (NInt a) (NInt b) = NInt (a * b)
mul a b = fromRational' (toRational' a * toRational' b)

-- | Negation.
neg :: Number -> Number
neg = \case
  NInt a -> NInt (negate a)
  NRat r -> NRat (negate r)

-- | Exact quotient; 'Nothing' on a zero divisor, however it was built.
--
-- >>> divide (NInt 1) (NInt 0)
-- Nothing
divide :: Number -> Number -> Maybe Number
divide a b
  | toRational' b == 0 = Nothing
  | otherwise = Just (fromRational' (toRational' a / toRational' b))

-- | Exact integer power; 'Nothing' for a negative power of zero. @0^0@ is 1,
-- as in Cohen's @Simplify_RNE@; the evaluator decides what @0^0@ means.
--
-- >>> pow (NRat (2 % 3)) (-2)
-- Just (NRat (9 % 4))
pow :: Number -> Integer -> Maybe Number
pow b e
  | e >= 0 = Just (powNat b e)
  | otherwise = (`powNat` negate e) <$> divide (NInt 1) b
  where
    powNat (NInt a) k = NInt (a ^ k)
    powNat (NRat r) k = fromRational' (r ^ k)
