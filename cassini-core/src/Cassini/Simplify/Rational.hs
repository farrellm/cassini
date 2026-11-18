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
    algebraicExpandFrom,
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

import Cassini.Core.Expr (Expr, pattern Call, pattern Int_, pattern Num)
import Cassini.Core.Symbol (sPlus, sPower, sTimes)
import Cassini.Number (Number (NInt, NRat))
import Cassini.Simplify.Automatic (Undefined)
import Cassini.Simplify.Elementary (everyNode, plus, power, times)
import Data.HashSet qualified as HashSet

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
algebraicExpand = algebraicExpandFrom HashSet.empty

-- | 'algebraicExpand', taking the subterms in the set as expanded already
-- and returning them as they are. A procedure that expands bottom up passes
-- the expanded operands of the node it has just rebuilt, so that each node
-- costs what the rebuilding made new, not the whole subtree again.
algebraicExpandFrom :: HashSet Expr -> Expr -> Either Undefined Expr
algebraicExpandFrom known = go
  where
    go u
      | HashSet.member u known = Right u
      | otherwise = case u of
          Call p ts | p == sPlus -> traverse go ts >>= plus
          Call t (f : fs) | t == sTimes -> do
            f' <- go f
            fs' <- traverse go fs
            foldlM expandProduct f' fs'
          Call p [b, Int_ n] | p == sPower, n >= 2 -> go b >>= (`expandPower` n)
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
  Call p (f : rest@(_ : _)) | p == sPlus -> do
    (fks, rks) <- binomialParts f rest n
    binomial fks rks n
  _ -> power u (Int_ n)

-- | @u^0@ to @u^n@, expanded. Cohen's procedure expands the rest's @r^k@ for
-- each @k@ separately, and each of those its own rest's powers again, so an
-- inner sum's powers were recomputed once per outer exponent; here each
-- sum's powers are computed once and shared.
expandPowers :: Expr -> Integer -> Either Undefined [Expr]
expandPowers u n = case u of
  Call p (f : rest@(_ : _)) | p == sPlus -> do
    (fks, rks) <- binomialParts f rest n
    traverse (binomial fks rks) [0 .. n]
  _ -> traverse (power u . Int_) [0 .. n]

-- | The first term's powers and the rest's, expanded, from 0 to @n@.
binomialParts :: Expr -> [Expr] -> Integer -> Either Undefined ([Expr], [Expr])
binomialParts f rest n = do
  r <- plus rest
  rks <- expandPowers r n
  fks <- traverse (power f . Int_) [0 .. n]
  pure (fks, rks)

-- | @(f + r)^m@ by Cohen's binomial step, from the powers of @f@ and @r@:
-- each term a monomial times an expanded power.
binomial :: [Expr] -> [Expr] -> Integer -> Either Undefined Expr
binomial fks rks m = do
  let k1 = fromInteger m + 1
  terms <- forM (zip3 [0 .. m] (reverse (take k1 fks)) (take k1 rks)) $ \(k, fk, rk) -> do
    cf <- times [Int_ (choose m k), fk]
    expandProduct cf rk
  plus terms

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
  Call p [_, Num e] | p == sPower, e < NInt 0 -> Right (Int_ 1)
  Call t fs | t == sTimes -> traverse numerator' fs >>= times
  _ -> Right u

-- | Cohen's @Denominator@ (Definition 6.48).
denominator' :: Expr -> Either Undefined Expr
denominator' u = case u of
  Num (NRat r) -> Right (Int_ (denominator r))
  Num (NInt _) -> Right (Int_ 1)
  Call p [_, Num e] | p == sPower, e < NInt 0 -> power u (Int_ (-1))
  Call t fs | t == sTimes -> traverse denominator' fs >>= times
  _ -> Right (Int_ 1)

-- | Cohen's @Rationalize_expression@ (Fig. 6.12): combine the terms of every
-- sum over a common denominator, recursively.
--
-- >>> rationalizeExpression (apply sPlus [Int_ 1, apply sPower [x, Int_ (-1)]])
-- Right Times[Power[x, -1], Plus[1, x]]
rationalizeExpression :: Expr -> Either Undefined Expr
rationalizeExpression u = case u of
  Call p [b, e] | p == sPower -> rationalizeExpression b >>= (`power` e)
  Call t fs | t == sTimes -> traverse rationalizeExpression fs >>= times
  Call p (t : ts) | p == sPlus -> traverse rationalizeExpression (t :| ts) >>= sumFromRight
  _ -> Right u
  where
    -- the terms combined from the right, the last one the seed
    sumFromRight = \case
      y :| [] -> Right y
      y :| (z : zs) -> sumFromRight (z :| zs) >>= rationalizeSum y

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
isAlgebraicExpanded = everyNode $ \case
  Call t fs | t == sTimes -> not (any isSum fs)
  Call p [b, Int_ n] | p == sPower -> not (n >= 2 && isSum b)
  _ -> True
  where
    isSum = \case
      Call p _ -> p == sPlus
      _ -> False
