-- | Integer roots, trial division, strong pseudoprimality and integer
-- factorization (DESIGN.md §4.15). No 'Cassini.Core.Expr'.
--
-- Source: @references/papers/textbooks/vonzurgathen_gerhard2013_*.pdf@ §9.5
-- (integer roots by Newton iteration), §18.3 (the strong pseudoprimality
-- test), §19.2 (trial division) and §19.4 (Pollard's rho method).
--
-- Every algorithm here is deterministic: the strong pseudoprimality test
-- uses fixed witnesses, and Pollard's rho a fixed sequence of seeds, so that
-- the evaluator under test stays a pure function (§4.3).
module Cassini.Number.Integer
  ( integerRoot,
    isPerfectPower,
    primesBelow,
    multiplicity,
    trialBound,
    trialFactor,
    isProbablePrime,
    factorInteger,
  )
where

import Data.Map.Strict qualified as Map
import GHC.Num.Integer qualified as Integer

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

-- | @⌊log2 n⌋@ for @n ≥ 1@, read off the representation's size rather than
-- by repeated halving, which is quadratic in the bit length and, called once
-- per candidate exponent, made @Sqrt@ of a 30,000-bit integer take minutes.
integerLog2' :: Integer -> Integer
integerLog2' n = toInteger (Integer.integerLog2 n)

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

-- | Trial division by the primes below a bound: the prime factors found,
-- with their multiplicities, in increasing order, and the cofactor, which
-- has no prime factor below the bound (vzGG §19.2).
--
-- >>> trialFactor 100 (2 ^ 3 * 7 * 1009)
-- ([(2,3),(7,1)],1009)
trialFactor :: Integer -> Integer -> ([(Integer, Int)], Integer)
trialFactor bound n0 = go (primesBelow bound) (abs n0) []
  where
    go _ 1 acc = (reverse acc, 1)
    go [] m acc = (reverse acc, m)
    go (p : ps) m acc
      | p * p > m = (reverse ((m, 1) : acc), 1)
      | otherwise = case multiplicity p m of
          (0, _) -> go ps m acc
          (v, m') -> go ps m' ((p, fromInteger v) : acc)

-- | The strong pseudoprimality test with the first 13 primes as witnesses
-- (vzGG §18.3). A proof of primality below 3.3·10²⁴; above that, "probable
-- prime" (§4.15).
--
-- >>> filter isProbablePrime [0 .. 30]
-- [2,3,5,7,11,13,17,19,23,29]
-- >>> isProbablePrime 3215031751
-- False
isProbablePrime :: Integer -> Bool
isProbablePrime n
  | n < 2 = False
  | n `elem` witnesses = True
  | any (\p -> n `mod` p == 0) witnesses = False
  | otherwise = all strong witnesses
  where
    witnesses = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41]
    (s, d) = multiplicity 2 (n - 1)
    strong a =
      let x = powMod a d n
       in x == 1 || x == n - 1 || elem (n - 1) (take (fromInteger s - 1) (drop 1 (iterate (\y -> y * y `mod` n) x)))

-- | @a^e mod m@ by repeated squaring.
powMod :: Integer -> Integer -> Integer -> Integer
powMod a0 e0 m = go (a0 `mod` m) e0 1
  where
    go _ 0 acc = acc
    go a e acc = go (a * a `mod` m) (e `div` 2) (if odd e then acc * a `mod` m else acc)

-- | The complete factorization of @n ≠ 0@, ignoring its sign: each prime
-- (probable prime above 'isProbablePrime''s bound) with its multiplicity, in
-- increasing order. Trial division below 'trialBound', then Pollard's rho
-- with Brent's cycle detection, seeded by a fixed sequence (vzGG §19.2,
-- §19.4). Complete, so its time is unbounded on hard inputs.
--
-- >>> factorInteger 360
-- [(2,3),(3,2),(5,1)]
-- >>> factorInteger (1000003 * 1000033)
-- [(1000003,1),(1000033,1)]
factorInteger :: Integer -> [(Integer, Int)]
factorInteger n0 =
  let (small, rest) = trialFactor trialBound n0
   in small <> collect (split rest)
  where
    collect ps = Map.toList (Map.fromListWith (+) [(p, 1) | p <- ps])
    split m
      | m == 1 = []
      | isProbablePrime m = [m]
      | Just (r, j) <- isPerfectPower m = concat (replicate (fromInteger j) (split r))
      | otherwise = let d = rho m 1 in split d <> split (m `div` d)

-- | A nontrivial factor of a composite @m@ with no small prime factor, by
-- Pollard's rho on @x ↦ x² + c@, trying @c = 1, 2, …@ in turn.
rho :: Integer -> Integer -> Integer
rho m c = fromMaybe (rho m (c + 1)) (brent 2 2 (1 :: Integer))
  where
    f x = (x * x + c) `mod` m
    -- Brent's variant: y runs ahead in powers of two.
    brent x y r = go x y r 0
    go x y r k
      | k >= r = brent' y y (2 * r)
      | otherwise =
          let y' = f y
              d = gcd (abs (x - y')) m
           in if d == 1 then go x y' r (k + 1) else (if d == m then Nothing else Just d)
    brent' x y r = if r > 2 ^ (64 :: Int) then Nothing else go x y r 0
