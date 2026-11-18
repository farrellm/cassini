-- | Integer roots and trial division (DESIGN.md §4.15). No 'Cassini.Core.Expr'.
--
-- Source: @references/papers/textbooks/vonzurgathen_gerhard2013_*.pdf@ §9.5
-- (integer roots by Newton iteration) and §19.2 (trial division).
--
-- The elementary-functions track needs these two for radical normalization
-- (§4.15 steps 4–5); @isProbablePrime@ and @factorInteger@ arrive with the
-- control-flow, logic and numbers track (§10).
module Cassini.Number.Integer
  ( integerRoot,
    isPerfectPower,
    primesBelow,
    multiplicity,
    trialBound,
  )
where

-- | The exact @b@-th root of a non-negative @n@, if @n@ is a perfect @b@-th
-- power. Newton's iteration on @x ↦ ((b-1)·x + n div x^(b-1)) div b@,
-- started above the root, decreases to @⌊n^(1/b)⌋@ (vzGG §9.5).
--
-- >>> integerRoot 64 3
-- Just 4
-- >>> integerRoot 65 3
-- Nothing
integerRoot :: Integer -> Integer -> Maybe Integer
integerRoot n b
  | n < 0 || b < 1 = Nothing
  | b == 1 || n < 2 = Just n
  | otherwise = let r = floorRoot n b in if r ^ b == n then Just r else Nothing

-- | @⌊n^(1/b)⌋@ for @n ≥ 2@, @b ≥ 2@.
floorRoot :: Integer -> Integer -> Integer
floorRoot n b = go start
  where
    -- 2^⌈(log2 n + 1)/b⌉ is above the root.
    start = 2 ^ ((integerLog2' n + 1) `div` b + 1)
    go x =
      let y = ((b - 1) * x + n `div` (x ^ (b - 1))) `div` b
       in if y >= x then x else go y

-- | @⌊log2 n⌋@ for @n ≥ 1@.
integerLog2' :: Integer -> Integer
integerLog2' = go 0
  where
    go acc m
      | m < 2 = acc
      | otherwise = go (acc + 1) (m `div` 2)

-- | A perfect-power decomposition @n = m^j@ with @j@ prime, trying each
-- prime @j ≤ log2 n@ in increasing order and taking the first hit (§4.15
-- step 4). Not maximal: @64@ gives @(8, 2)@, and evaluation re-enters.
--
-- >>> isPerfectPower 64
-- Just (8,2)
-- >>> isPerfectPower 12
-- Nothing
isPerfectPower :: Integer -> Maybe (Integer, Integer)
isPerfectPower n
  | n < 4 = Nothing
  | otherwise =
      listToMaybe
        [(m, j) | j <- takeWhile (<= integerLog2' n) primes, Just m <- [integerRoot n j]]

-- | The bound @B@ of §4.15 steps 5–6 (D24): primes below it are extracted
-- from radicands and merged with coefficients.
trialBound :: Integer
trialBound = 1024

-- | The primes below a bound, in increasing order.
--
-- >>> primesBelow 20
-- [2,3,5,7,11,13,17,19]
primesBelow :: Integer -> [Integer]
primesBelow b = takeWhile (< b) primes

-- | The multiplicity of @p@ in @n ≠ 0@, and the cofactor: @n = p^v · m@ with
-- @p@ not dividing @m@ (vzGG §19.2's trial division, one prime).
--
-- >>> multiplicity 2 24
-- (3,3)
multiplicity :: Integer -> Integer -> (Integer, Integer)
multiplicity p = go 0
  where
    go v m
      | m /= 0, (q, 0) <- m `quotRem` p = go (v + 1) q
      | otherwise = (v, m)

-- | The primes, by trial division over the primes already found.
primes :: [Integer]
primes = 2 : filter isPrime [3, 5 ..]
  where
    isPrime n = all (\p -> n `mod` p /= 0) (takeWhile (\p -> p * p <= n) primes)
