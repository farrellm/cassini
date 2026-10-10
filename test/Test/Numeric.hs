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
-- but a small natural number, or any head this evaluator does not know.
-- The functions @f@ and @g@ are fixed real functions of their arguments.
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
        | h.symName == "f" -> (\xs -> sin (1.3 * weighted xs)) <$> traverse go (V.toList as)
        | h.symName == "g" -> (\xs -> cos (0.7 * weighted xs) + 2) <$> traverse go (V.toList as)
      _ -> Nothing
    weighted xs = sum (zipWith (*) [1 ..] xs)
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
