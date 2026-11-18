{-# LANGUAGE PatternSynonyms #-}

-- | Algebraic expansion, rationalization, and numerator and denominator over
-- expressions in normal form (DESIGN.md §4.12).
--
-- Source: @references/papers/textbooks/cohen2002_*.pdf@ §6.4 (Fig. 6.10,
-- @Algebraic_expand@ and @Expand_product@; Fig. 6.11, @Expand_power@;
-- Exercise 6, @Expand_main_op@) and §6.5 (Definition 6.48, @Numerator@ and
-- @Denominator@; Fig. 6.12, @Rationalize_expression@ and
-- @Rationalize_sum@).
--
-- Every intermediate is built with "Cassini.Simplify.Elementary"'s 'nodeE',
-- so each is in the evaluator's normal form, as Cohen's procedures assume
-- of automatic simplification. Cohen states @Algebraic_expand@ for integer
-- exponents; with a non-integer one the result can fail to be expanded
-- (his (6.43)), as @(1 + x)^(1/2) (1 + x)^(3/2)@ does here.
module Cassini.Simplify.Rational
  ( algebraicExpand,
    expandMainOp,
    expandProduct,
    expandPower,
    choose,
    numerator',
    denominator',
    rationalizeExpression,
    isAlgebraicExpanded,
  )
where

import Cassini.Core.Expr (Expr, exprArgs, pattern App, pattern Call, pattern Int_, pattern Num, pattern Sym)
import Cassini.Core.Symbol (sPlus, sPower, sTimes)
import Cassini.Number (Number (NInt, NRat), toRational')
import Cassini.Simplify.Automatic (Undefined)
import Cassini.Simplify.Elementary (nodeE)
import Data.Vector qualified as V

-- $setup
-- >>> import Cassini.Core.Expr (apply, mkNumber, mkSymbol)
-- >>> import Cassini.Number (fromRational')
-- >>> import Cassini.Core.Symbol (globalSymbol)
-- >>> let x = mkSymbol (globalSymbol "x")

-- | Cohen's @Algebraic_expand@: distribute products and positive integer
-- powers over sums, recursively through sums, products and powers. Function
-- arguments are left alone, as WL's @Expand@ leaves them.
--
-- >>> algebraicExpand (apply sPower [apply sPlus [Int_ 1, x], Int_ 2])
-- Right Plus[1, Times[2, x], Power[x, 2]]
algebraicExpand :: Expr -> Either Undefined Expr
algebraicExpand u = case u of
  Call p ts | p == sPlus -> traverse algebraicExpand ts >>= plus
  Call t (f : fs) | t == sTimes -> do
    fs' <- traverse algebraicExpand (f : fs)
    foldlM expandProduct (Int_ 1) fs'
  Call p [b, Int_ n] | p == sPower, n >= 2 -> algebraicExpand b >>= (`expandPower` n)
  _ -> Right u

-- | Cohen's @Expand_main_op@: distribute with respect to the main operator
-- only, without expanding the operands first.
--
-- >>> expandMainOp (apply sTimes [x, apply sPlus [Int_ 2, apply sPower [apply sPlus [Int_ 1, x], Int_ 2]]])
-- Right Plus[Times[2, x], Times[x, Power[Plus[1, x], 2]]]
expandMainOp :: Expr -> Either Undefined Expr
expandMainOp u = case u of
  Call t (f : fs) | t == sTimes -> foldlM expandProduct f fs
  Call p [b, Int_ n] | p == sPower, n >= 2 -> expandPower b n
  _ -> Right u

-- | Cohen's @Expand_product@: the expanded product of two expanded
-- expressions.
expandProduct :: Expr -> Expr -> Either Undefined Expr
expandProduct r s = case (r, s) of
  (Call p ts, _) | p == sPlus -> traverse (`expandProduct` s) ts >>= plus
  (_, Call p _) | p == sPlus -> expandProduct s r
  _ -> times [r, s]

-- | Cohen's @Expand_power@: an expanded expression to a non-negative integer
-- power, by the binomial theorem on its first term and the rest.
expandPower :: Expr -> Integer -> Either Undefined Expr
expandPower u n = case u of
  Call p (f : rest@(_ : _))
    | p == sPlus -> do
        r <- plus rest
        terms <- forM [0 .. n] $ \k -> do
          cf <- power f (Int_ (n - k)) >>= \fk -> times [Int_ (choose n k), fk]
          rk <- expandPower r k
          expandProduct cf rk
        plus terms
  _ -> power u (Int_ n)

-- | The binomial coefficient.
choose :: Integer -> Integer -> Integer
choose n k = product [n - k + 1 .. n] `div` product [1 .. k]

-- | Cohen's @Numerator@ (Definition 6.48).
--
-- >>> numerator' (apply sTimes [mkNumber (fromRational' (2 / 3)), x, apply sPower [apply sPlus [Int_ 2, x], Int_ (-1)]])
-- Right Times[2, x]
numerator' :: Expr -> Either Undefined Expr
numerator' u = case u of
  Num (NRat r) -> Right (Int_ (numerator r))
  Num (NInt _) -> Right u
  Call p [_, Num e] | p == sPower, isNegative e -> Right (Int_ 1)
  Call t fs | t == sTimes -> traverse numerator' fs >>= times
  _ -> Right u

-- | Cohen's @Denominator@ (Definition 6.48).
denominator' :: Expr -> Either Undefined Expr
denominator' u = case u of
  Num (NRat r) -> Right (Int_ (denominator r))
  Num (NInt _) -> Right (Int_ 1)
  Call p [_, Num e] | p == sPower, isNegative e -> power u (Int_ (-1))
  Call t fs | t == sTimes -> traverse denominator' fs >>= times
  _ -> Right (Int_ 1)

isNegative :: Number -> Bool
isNegative e = toRational' e < 0

-- | Cohen's @Rationalize_expression@ (Fig. 6.12): combine the terms of every
-- sum over a common denominator, recursively.
--
-- >>> rationalizeExpression (apply sPlus [Int_ 1, apply sPower [x, Int_ (-1)]])
-- Right Times[Power[x, -1], Plus[1, x]]
rationalizeExpression :: Expr -> Either Undefined Expr
rationalizeExpression u = case u of
  Call p [b, e] | p == sPower -> rationalizeExpression b >>= (`power` e)
  Call t fs | t == sTimes -> traverse rationalizeExpression fs >>= times
  Call p ts@(_ : _) | p == sPlus -> traverse rationalizeExpression ts >>= foldrM1 rationalizeSum
  _ -> Right u
  where
    foldrM1 f = \case
      [] -> Right (Int_ 0)
      xs -> case reverse xs of
        y : ys -> foldlM (flip f) y ys
        [] -> Right (Int_ 0)

-- | Cohen's @Rationalize_sum@: @m/r + n/s → (m s + n r)/(r s)@.
rationalizeSum :: Expr -> Expr -> Either Undefined Expr
rationalizeSum u v = do
  m <- numerator' u
  r <- denominator' u
  n <- numerator' v
  s <- denominator' v
  if r == Int_ 1 && s == Int_ 1
    then plus [u, v]
    else do
      ms <- times [m, s]
      nr <- times [n, r]
      top <- rationalizeSum ms nr
      rs <- times [r, s]
      bottom <- power rs (Int_ (-1))
      times [top, bottom]

-- | Whether every complete subexpression is in algebraic-expanded form: no
-- product has a sum operand, and no power with an integer exponent of at
-- least 2 has a sum base. Function arguments count as subexpressions.
isAlgebraicExpanded :: Expr -> Bool
isAlgebraicExpanded u = here && all isAlgebraicExpanded (V.toList (exprArgs u)) && headOk
  where
    here = case u of
      Call t fs | t == sTimes -> not (any isSum fs)
      Call p [b, Int_ n] | p == sPower -> not (n >= 2 && isSum b)
      _ -> True
    headOk = case u of
      App h@(App _ _) _ -> isAlgebraicExpanded h
      _ -> True
    isSum = \case
      Call p _ -> p == sPlus
      _ -> False

-- Construction, each node to normal form.

times, plus :: [Expr] -> Either Undefined Expr
times = nodeE (Sym sTimes) . V.fromList
plus = nodeE (Sym sPlus) . V.fromList

power :: Expr -> Expr -> Either Undefined Expr
power v w = nodeE (Sym sPower) (V.fromList [v, w])
