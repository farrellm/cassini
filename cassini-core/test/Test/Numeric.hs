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
import Cassini.Core.Symbol (sFactorial, sPlus, sPower, sTimes, symContext, symName)
import Cassini.Number (toRational')
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V
import Test.QuickCheck (Gen, choose)

-- | The value at a point, or 'Nothing' where the expression is undefined
-- there, complex, or too large to compare: a negative base under a
-- non-integer power, a non-positive power of zero, a factorial of anything
-- but a small natural number, @f@, @g@ or a circular function of arguments
-- too large for a periodic function to keep the tolerance, or any head this
-- evaluator does not know. The functions @f@ and @g@ are fixed real
-- functions of their arguments, and @Derivative[n1, …][f]@ and @[g]@ their
-- partial derivatives.
evalAt :: Map Text Double -> Expr -> Maybe Double
evalAt point = go
  where
    go = \case
      Num n -> Just (fromRational (toRational' n))
      Sym s
        | s.symName == "Pi" && s.symContext == "System`" -> Just pi
        | s.symName == "E" && s.symContext == "System`" -> Just (exp 1)
        | otherwise -> Map.lookup s.symName point
      App (Sym h) as
        | h == sPlus -> sum <$> traverse go (V.toList as)
        | h == sTimes -> product <$> traverse go (V.toList as)
        | h == sPower,
          [b, e] <- V.toList as -> do
            b' <- go b
            e' <- go e
            power b' e'
        | h == sFactorial, [x] <- V.toList as -> go x >>= factorial
        | h.symContext == "System`",
          [x] <- V.toList as,
          Just f <- elementary h.symName ->
            go x >>= f
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

-- | The elementary functions, real-valued and away from their poles and
-- branch cuts: 'Nothing' within 1e-8 of a pole, for a logarithm of a
-- non-positive number, and for an inverse outside its real domain.
elementary :: Text -> Maybe (Double -> Maybe Double)
elementary = \case
  "Sin" -> circular (Just . sin)
  "Cos" -> circular (Just . cos)
  "Tan" -> circular (\x -> sin x `over` cos x)
  "Cot" -> circular (\x -> cos x `over` sin x)
  "Sec" -> circular (\x -> 1 `over` cos x)
  "Csc" -> circular (\x -> 1 `over` sin x)
  "Sinh" -> total sinh
  "Cosh" -> total cosh
  "Tanh" -> total tanh
  "Coth" -> Just (\x -> cosh x `over` sinh x)
  "Sech" -> total (\x -> 1 / cosh x)
  "Csch" -> Just (\x -> 1 `over` sinh x)
  "ArcSin" -> Just (\x -> if abs x <= 1 then Just (asin x) else Nothing)
  "ArcCos" -> Just (\x -> if abs x <= 1 then Just (acos x) else Nothing)
  "ArcTan" -> total atan
  "ArcCot" -> Just (\x -> if x == 0 then Just (pi / 2) else Just (atan (1 / x)))
  "ArcSec" -> Just (\x -> if abs x >= 1 then Just (acos (1 / x)) else Nothing)
  "ArcCsc" -> Just (\x -> if abs x >= 1 then Just (asin (1 / x)) else Nothing)
  "Exp" -> total exp
  "Log" -> Just (\x -> if x > 0 then Just (logBase (exp 1) x) else Nothing)
  _ -> Nothing
  where
    total f = Just (Just . f)
    -- As for 'periodic' in 'evalAt': beyond 1e6, rounding the argument
    -- alone can move the value by more than 'approxEqual' allows, so
    -- Sin[Exp[9 E]] and Sin[E^(9 E)] would disagree.
    circular f = Just (\x -> if abs x > 1e6 then Nothing else f x)
    over a b = if abs b < 1e-8 then Nothing else Just (a / b)

-- | Whether two values agree to a relative tolerance; values that are not
-- finite or are too large to compare meaningfully agree with anything.
approxEqual :: Double -> Double -> Bool
approxEqual a b
  | any (\x -> isNaN x || isInfinite x || abs x > 1e9) [a, b] = True
  | otherwise = abs (a - b) <= 1e-6 * max 1 (max (abs a) (abs b))

-- | A point: a positive value for each symbol of the generators' pool.
genPoint :: Gen (Map Text Double)
genPoint = Map.fromList <$> traverse (\v -> (v,) <$> choose (0.5, 2.5)) ["a", "b", "c", "x", "y", "m", "n"]
