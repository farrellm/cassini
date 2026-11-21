{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE PatternSynonyms #-}

-- | Comparison and logic: @Equal@, @Unequal@, @Less@, @Greater@,
-- @LessEqual@, @GreaterEqual@, @SameQ@, @UnsameQ@, @TrueQ@, @And@, @Or@
-- and @Not@ (DESIGN.md §4.14).
--
-- Source: @references/papers/wolfram-language/wolfram_ref_evaluation_of_expressions.html@,
-- "Conditionals": "the condition x==y does not yield True or False unless x
-- and y have specific values", and @And@ evaluates "until one of the exprᵢ is
-- found to be False".
--
-- The comparisons are three-valued. @Equal@ asks 'Cassini.Zero.isZero' about
-- the difference, and leaves the comparison unevaluated on 'Nothing', and on
-- 'Just' 'False' when the difference has a free symbol: "not identically
-- zero" is not "unequal at the current values". Before milestone 2a,
-- 'isZero' has only its rational layer, so @(x + 1)^2 == x^2 + 2 x + 1@
-- stays unevaluated, which is the contract working (§10).
module Cassini.Builtins.Logic (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, isList, sFalseE, sTrueE)
import Cassini.Core.Expr (Expr, apply, pattern App, pattern Call, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Symbol (Symbol, sDirectedInfinity, sFalse, sPlus, sTimes, sTrue, systemSymbol)
import Cassini.Eval.Kernel (Kernel, evaluate, quietly)
import Cassini.Number (toRational')
import Cassini.Zero (isZero)
import Effectful (Eff, (:>))

-- | The comparison and logic builtins, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "Equal" [Protected] [down (chain equal)],
    define "Unequal" [Protected] [down unequal],
    define "Less" [Protected] [down (ordering (<))],
    define "Greater" [Protected] [down (ordering (>))],
    define "LessEqual" [Protected] [down (ordering (<=))],
    define "GreaterEqual" [Protected] [down (ordering (>=))],
    define "SameQ" [Protected] [down (pure . Just . truth . pairwise (==) . args)],
    define "UnsameQ" [Protected] [down (pure . Just . truth . distinct . args)],
    define "TrueQ" [Protected] [down trueQ],
    define "And" [Flat, HoldAll, OneIdentity, Protected] [down (connective sFalse sTrue "And")],
    define "Or" [Flat, HoldAll, OneIdentity, Protected] [down (connective sTrue sFalse "Or")],
    define "Not" [Protected] [down notRule]
  ]

truth :: Bool -> Expr
truth b = if b then sTrueE else sFalseE

-- | Every adjacent pair satisfies the relation.
pairwise :: (a -> a -> Bool) -> [a] -> Bool
pairwise r xs = and (zipWith r xs (drop 1 xs))

-- | No two are equal.
distinct :: [Expr] -> Bool
distinct = \case
  [] -> True
  x : xs -> notElem x xs && distinct xs

-- | A chain of comparisons, @a == b == c@: 'False' if one adjacent pair
-- is, 'True' if every one is, and unevaluated otherwise.
chain :: (Expr -> Expr -> Eff es (Maybe Bool)) -> Expr -> Eff es (Maybe Expr)
chain decide e = do
  let xs = args e
  ds <- zipWithM decide xs (drop 1 xs)
  pure $
    if
      | Just False `elem` ds -> Just sFalseE
      | all (== Just True) ds -> Just sTrueE
      | otherwise -> Nothing

-- | @a == b@ (§4.14): identical is 'True'; two distinct strings, a string
-- and a number, or lists of different lengths are 'False'; lists of one
-- length compare elementwise; anything else by the zero test on the
-- difference. The difference is evaluated quietly: it is the comparison's
-- own working, and @Infinity == -Infinity@ must not report @Infinity::indet@.
equal :: (Kernel :> es) => Expr -> Expr -> Eff es (Maybe Bool)
equal a b
  | a == b = pure (Just True)
  | otherwise = case (a, b) of
      (Str _, Str _) -> pure (Just False)
      (Str _, Num _) -> pure (Just False)
      (Num _, Str _) -> pure (Just False)
      _
        | isList a && isList b ->
            if length (args a) /= length (args b)
              then pure (Just False)
              else do
                ds <- zipWithM equal (args a) (args b)
                pure $
                  if
                    | Just False `elem` ds -> Just False
                    | all (== Just True) ds -> Just True
                    | otherwise -> Nothing
        | isList a || isList b -> pure Nothing
        | otherwise -> do
            d <- quietly Nothing (evaluate (apply sPlus [a, apply sTimes [Int_ (-1), b]]))
            isZero d <&> \case
              Just True -> Just True
              Just False | closed d -> Just False
              _ -> Nothing
  where
    -- No free symbol: no symbol stands as an operand anywhere in it, only
    -- as a head.
    closed = \case
      Sym _ -> False
      App _ xs -> all closed xs
      _ -> True

-- | @a != b@: 'True' when every pair is unequal, 'False' when some pair is
-- equal, unevaluated otherwise.
unequal :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
unequal e = do
  let xs = args e
  ds <- sequence [equal x y | (i, x) <- zip [0 :: Int ..] xs, y <- drop (i + 1) xs]
  pure $
    if
      | Just True `elem` ds -> Just sFalseE
      | all (== Just False) ds -> Just sTrueE
      | otherwise -> Nothing

-- | A real number the orderings decide on: a rational, or @±Infinity@.
data Extended = NegInf | Finite !Rational | PosInf
  deriving stock (Eq, Ord)

extended :: Expr -> Maybe Extended
extended = \case
  Num n -> Just (Finite (toRational' n))
  Call d [Int_ 1] | d == sDirectedInfinity -> Just PosInf
  Call d [Int_ (-1)] | d == sDirectedInfinity -> Just NegInf
  _ -> Nothing

-- | @Less@ and the other orderings, decided exactly on rationals and the
-- real infinities (§4.14); anything else, @Pi@ included, needs certified
-- numerics (D9), and the comparison stays. In a chain, a numeric adjacent
-- pair that fails makes the whole 'False'.
ordering :: (Extended -> Extended -> Bool) -> Expr -> Eff es (Maybe Expr)
ordering r e = pure $ case traverse extended xs of
  Just ns -> Just (truth (pairwise r ns))
  Nothing
    | or (zipWith fails xs (drop 1 xs)) -> Just sFalseE
    | otherwise -> Nothing
  where
    xs = args e
    fails x y = case (extended x, extended y) of
      (Just a, Just b) -> not (r a b)
      _ -> False

-- | @TrueQ[e]@ is 'True' only for 'True'.
trueQ :: Expr -> Eff es (Maybe Expr)
trueQ e = pure $ case args e of
  [x] -> Just (truth (x == sTrueE))
  _ -> Nothing

-- | @And@ and @Or@: evaluate left to right, stopping at the first argument
-- that decides (@False@ for @And@, @True@ for @Or@); arguments that evaluate
-- to the identity are dropped, and what remains is kept, evaluated.
connective :: (Kernel :> es) => Symbol -> Symbol -> Text -> Expr -> Eff es (Maybe Expr)
connective decider unit name e = go [] (args e)
  where
    go kept = \case
      [] -> pure . Just $ case reverse kept of
        [] -> Sym unit
        [x] -> x
        xs -> apply (systemSymbol name) xs
      x : rest ->
        evaluate x >>= \case
          Sym s | s == decider -> pure (Just (Sym decider))
          Sym s | s == unit -> go kept rest
          v -> go (v : kept) rest

-- | @Not[True]@ is 'False' and @Not[False]@ 'True'; anything else stays.
notRule :: Expr -> Eff es (Maybe Expr)
notRule e = pure $ case args e of
  [Sym s]
    | s == sTrue -> Just sFalseE
    | s == sFalse -> Just sTrueE
  _ -> Nothing
