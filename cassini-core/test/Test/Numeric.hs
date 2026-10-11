{-# LANGUAGE PatternSynonyms #-}

-- | A test-only evaluator of expressions to 'Double' at a point, for the laws
-- that compare values (DESIGN.md §7.3). A heuristic oracle, not a decision
-- procedure, which is why it lives here and the library's zero test has no
-- such layer (§5.6).
module Test.Numeric
  ( evalAt,
    approxEqual,
    genPoint,
  )
where

import Cassini.Core.Expr (Expr, pattern App, pattern Num, pattern Sym)
import Cassini.Core.Symbol (sFactorial, sPlus, sPower, sTimes, symName)
import Cassini.Number (toRational')
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V
import Test.QuickCheck (Gen, choose)

-- | The value at a point, or 'Nothing' where the expression is undefined
-- there, complex, or too large to compare: a negative base under a
-- non-integer power, a non-positive power of zero, a factorial of anything
-- but a small natural number, @f@ or @g@ of arguments too large for a
-- periodic function to keep the tolerance, or any head this evaluator does
-- not know. The functions @f@ and @g@ are fixed real functions of their
-- arguments, and @Derivative[n1, …][f]@ and @[g]@ their partial derivatives.
evalAt :: Map Text Double -> Expr -> Maybe Double
evalAt point = go
  where
    go = \case
      Num n -> Just (fromRational (toRational' n))
      Sym s -> Map.lookup s.symName point
      App (Sym h) as
        | h == sPlus -> sum <$> traverse go (V.toList as)
        | h == sTimes -> product <$> traverse go (V.toList as)
        | h == sPower,
          [b, e] <- V.toList as -> do
            b' <- go b
            e' <- go e
            power b' e'
        | h == sFactorial, [x] <- V.toList as -> go x >>= factorial
        | h.symName == "f" -> traverse go (V.toList as) >>= periodic (\w -> sin (1.3 * w))
        | h.symName == "g" -> traverse go (V.toList as) >>= periodic (\w -> cos (0.7 * w) + 2)
      -- Derivative[n1, …, nk][f][a1, …, ak]: f and g are functions of
      -- w = a1 + 2 a2 + …, so the partial derivative is the k-th
      -- derivative in w times 1^n1 2^n2 ….
      App (App (App (Sym d) ns) fs) as
        | d.symName == "Derivative",
          [Sym f] <- V.toList fs,
          Just orders <- traverse order (V.toList ns),
          length orders == V.length as -> do
            xs <- traverse go (V.toList as)
            let k = sum orders
                scale = product [fromIntegral i ^ n | (i, n) <- zip [1 :: Int ..] orders]
                shift = fromIntegral k * pi / 2
            periodic
              ( \w -> case f.symName of
                  "f" -> scale * 1.3 ^ k * sin (1.3 * w + shift)
                  "g" | k > 0 -> scale * 0.7 ^ k * cos (0.7 * w + shift)
                  "g" -> cos (0.7 * w) + 2
                  _ -> 0 / 0
              )
              xs
              >>= \v -> if isNaN v then Nothing else Just v
      _ -> Nothing
    order = \case
      Num n | Just k <- integral (toRational' n), k >= 0 -> Just k
      _ -> Nothing
    integral r = if denominator r == 1 then Just (numerator r) else Nothing
    -- Rounding makes the argument's absolute error about 1e-16 of its size,
    -- and a periodic function passes it on whole: beyond 1e6, two spellings
    -- of one value can differ by more than 'approxEqual' allows.
    periodic k xs =
      let w = sum (zipWith (*) [1 ..] xs)
       in if abs w > 1e6 then Nothing else Just (k w)
    power b e
      | b == 0 && e <= 0 = Nothing
      | b < 0 && not (isWhole e) = Nothing
      | isWhole e = Just (b ^^ (round e :: Integer))
      | otherwise = Just (b ** e)
    factorial x
      | isWhole x && x >= 0 && x <= 20 = Just (product [1 .. x])
      | otherwise = Nothing
    isWhole x = x == fromInteger (round x)

-- | Whether two values agree to a relative tolerance; values that are not
-- finite or are too large to compare meaningfully agree with anything.
approxEqual :: Double -> Double -> Bool
approxEqual a b
  | any (\x -> isNaN x || isInfinite x || abs x > 1e9) [a, b] = True
  | otherwise = abs (a - b) <= 1e-6 * max 1 (max (abs a) (abs b))

-- | A point: a positive value for each symbol of the generators' pool.
genPoint :: Gen (Map Text Double)
genPoint = Map.fromList <$> traverse (\v -> (v,) <$> choose (0.5, 2.5)) ["a", "b", "c", "x", "y", "m", "n"]
