{-# LANGUAGE PatternSynonyms #-}

-- | The kernel's one ordering: Cohen's order relation ◁, extended to a total
-- order on every 'Expr' (DESIGN.md §3.5).
--
-- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.1, Definition 3.26
-- (rules O-1 … O-13) and Figure 3.9.
--
-- Cohen defines ◁ on distinct ASAEs. On other terms it can call distinct
-- terms equal (@Times[x]@ and @x@), so 'compareCanonical' is Cohen's relation,
-- computed as a preorder that recurs into itself, refined lexicographically by
-- a structural order (O-T) that fires only where Cohen's says equal. Strings
-- (O-S1, O-S2) sort after numbers and before everything else.
module Cassini.Core.Order (compareCanonical) where

import Cassini.Core.Expr (Expr, exprArgs, exprArity, exprHead, pattern App, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Symbol (compareSymbolName)
import Cassini.Number (compareNumber)
import Cassini.Structure (Kind (..), exprKind)
import Data.Vector qualified as V

-- $setup
-- >>> import Cassini.Core.Expr (apply, mkSymbol)
-- >>> import Cassini.Core.Symbol (globalSymbol, sPower, sTimes)

-- | Cohen's ◁ as an 'Ordering', total on every 'Expr' and 'EQ' exactly on
-- equal terms.
--
-- >>> let x = mkSymbol (globalSymbol "x"); a = mkSymbol (globalSymbol "a")
-- >>> compareCanonical (apply sTimes [a, apply sPower [x, Int_ 2]]) (apply sPower [x, Int_ 3])
-- LT
compareCanonical :: Expr -> Expr -> Ordering
compareCanonical u v
  | u == v = EQ
  | otherwise = cohen u v <> structural u v

-- | Cohen's rules. A preorder: 'EQ' on distinct terms only off the ASAEs.
cohen :: Expr -> Expr -> Ordering
cohen u v
  | u == v = EQ
  | otherwise = case compare ru rv of
      EQ -> sameKind ku u v
      LT -> crossKind ku u v
      -- O-13: the rules are stated for the upper triangle of Figure 3.9.
      GT -> invert (crossKind kv v u)
  where
    ku = exprKind u
    kv = exprKind v
    ru = rank ku
    rv = rank kv

-- | Figure 3.9's row and column order, with strings placed after constants.
rank :: Kind -> Int
rank = \case
  KConstant -> 0
  KString -> 1
  KProduct -> 2
  KPower -> 3
  KSum -> 4
  KFactorial -> 5
  KFunction -> 6
  KSymbol -> 7

-- | O-1 … O-6 and O-S1: both terms of one kind.
sameKind :: Kind -> Expr -> Expr -> Ordering
sameKind k u v = case k of
  -- O-1
  KConstant | Num a <- u, Num b <- v -> compareNumber a b
  -- O-S1
  KString | Str a <- u, Str b <- v -> compare a b
  -- O-2
  KSymbol | Sym a <- u, Sym b <- v -> compareSymbolName a b
  -- O-3, sums and products alike
  KProduct -> rightToLeft (exprArgs u) (exprArgs v)
  KSum -> rightToLeft (exprArgs u) (exprArgs v)
  -- O-4
  KPower -> cohen (powerBase u) (powerBase v) <> cohen (powerExponent u) (powerExponent v)
  -- O-5
  KFactorial -> cohen (operand u) (operand v)
  -- O-6: names (heads, which may be applications), then operands from the left
  KFunction -> cohen (exprHead u) (exprHead v) <> leftToRight (exprArgs u) (exprArgs v)
  -- Unreachable: exprKind agreed on k for both terms.
  _ -> EQ

-- | O-7 … O-12 and O-S2: @u@, of kind @ku@, against a @v@ of higher rank.
crossKind :: Kind -> Expr -> Expr -> Ordering
crossKind ku u v = case ku of
  -- O-7
  KConstant -> LT
  -- O-S2
  KString -> LT
  -- O-8: u against the one-operand product ·v
  KProduct -> rightToLeft (exprArgs u) (V.singleton v)
  -- O-9: u against v^1
  KPower -> cohen (powerBase u) v <> cohen (powerExponent u) (Int_ 1)
  -- O-10: u against the one-operand sum +v
  KSum -> rightToLeft (exprArgs u) (V.singleton v)
  -- O-11: v first if it is u's operand, else u against v!
  KFactorial -> cohen (operand u) v <> GT
  -- O-12: v first if it is u's name, else u's name against v
  KFunction -> cohen (exprHead u) v <> GT
  -- Unreachable: a symbol has the highest rank.
  KSymbol -> EQ

-- | O-3: compare from the last operand leftwards; if one runs out first, it
-- is smaller (O-3-3).
rightToLeft :: V.Vector Expr -> V.Vector Expr -> Ordering
rightToLeft us vs = go (V.length us - 1) (V.length vs - 1)
  where
    go i j
      | i < 0 || j < 0 = compare (V.length us) (V.length vs)
      | otherwise = cohenAt us i vs j <> go (i - 1) (j - 1)

-- | O-6-2: compare from the first operand rightwards; if one runs out first,
-- it is smaller (O-6-2c).
leftToRight :: V.Vector Expr -> V.Vector Expr -> Ordering
leftToRight us vs = mconcat (V.toList (V.zipWith cohen us vs)) <> compare (V.length us) (V.length vs)

cohenAt :: V.Vector Expr -> Int -> V.Vector Expr -> Int -> Ordering
cohenAt us i vs j = case (us V.!? i, vs V.!? j) of
  (Just a, Just b) -> cohen a b
  _ -> EQ

-- | O-T: kind rank, then arity, then head and arguments by 'compareCanonical',
-- then the atoms themselves. Reached only for distinct terms Cohen's rules
-- call equal, and never 'EQ' on distinct terms.
structural :: Expr -> Expr -> Ordering
structural u v =
  comparing (rank . exprKind) u v
    <> comparing exprArity u v
    <> case (u, v) of
      (App hu as, App hv bs) ->
        compareCanonical hu hv <> mconcat (V.toList (V.zipWith compareCanonical as bs))
      (Num a, Num b) -> compareNumber a b
      (Str a, Str b) -> compare a b
      (Sym a, Sym b) -> compareSymbolName a b
      _ -> EQ

invert :: Ordering -> Ordering
invert = compare EQ

-- The parts the rules name. Each is called only on a term of the kind that
-- has it, so the fallbacks are unreachable.

powerBase :: Expr -> Expr
powerBase = argOr 0

powerExponent :: Expr -> Expr
powerExponent = argOr 1

operand :: Expr -> Expr
operand = argOr 0

argOr :: Int -> Expr -> Expr
argOr i e = fromMaybe e (exprArgs e V.!? i)
