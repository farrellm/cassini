{-# LANGUAGE PatternSynonyms #-}

-- | @Head@, @Part@, @Length@, @Apply@, @Map@, @Level@ and @FreeQ@
-- (DESIGN.md §2.2, §3.7).
--
-- Thin bindings over "Cassini.Structure", except @FreeQ@, whose second
-- argument is a pattern: 'freeOf' is its fast path when the form has no
-- pattern object, and otherwise every subexpression, heads included, goes
-- through the matcher.
--
-- @Map@, @Apply@ and @Level@ share one reading of level specifications:
-- @n@, @{n}@, @{m, n}@, @Infinity@ and @All@, where a negative level @-k@
-- means the subexpressions of depth @k@. @Map[f]@ and @Apply[f]@ are operator
-- forms, built-in subvalues.
module Cassini.Builtins.Structural (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, message, sFalseE, sTrueE, sub, sym)
import Cassini.Core.Expr (Expr, apply, exprArgs, exprArity, exprHead, mkApp, pattern App, pattern Int_, pattern Sym)
import Cassini.Core.Symbol (sList)
import Cassini.Eval.Kernel (Kernel)
import Cassini.Pattern (isPatternFree)
import Cassini.Pattern.Match (matchOne)
import Cassini.Structure (PartError (..), freeOf, part)
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | The structural builtins, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "Head" [Protected] [down (arity "Head" 1 headRule)],
    define "Length" [Protected] [down (arity "Length" 1 lengthRule)],
    define "Part" [NHoldRest, Protected, ReadProtected] [down partRule],
    define "Apply" [Protected] [down (pure . applyRule), sub (pure . operatorForm)],
    define "Map" [Protected] [down (pure . mapRule), sub (pure . operatorForm)],
    define "Level" [Protected] [down (pure . levelRule)],
    define "FreeQ" [Protected] [down freeQRule],
    define "All" [Protected] []
  ]

-- | A builtin of fixed arity: any other number of arguments is
-- @symbol::argx@, and the input stays.
arity :: (Kernel :> es) => Text -> Int -> (Expr -> Maybe Expr) -> Expr -> Eff es (Maybe Expr)
arity name n f e
  | exprArity e == n = pure (f e)
  | otherwise = Nothing <$ message name "argx" [Int_ (toInteger (exprArity e))]

headRule :: Expr -> Maybe Expr
headRule e = exprHead <$> viaNonEmpty head (args e)

lengthRule :: Expr -> Maybe Expr
lengthRule e = Int_ . toInteger . exprArity <$> viaNonEmpty head (args e)

-- | @op[f][expr]@ is @op[f, expr]@.
operatorForm :: Expr -> Maybe Expr
operatorForm = \case
  App (App op fs) xs | [f] <- V.toList fs, [x] <- V.toList xs -> Just (mkApp op (V.fromList [f, x]))
  _ -> Nothing

-- | @Part[expr, i, j, …]@: each index an integer, a list of integers, or
-- @All@. Out of range is @Part::partw@ on an expression and @Part::partd@ on
-- an atom, and the input stays unevaluated (§4.7).
partRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
partRule e = case args e of
  [x] -> pure (Just x)
  x : is@(_ : _) -> case go x is of
    Right r -> pure (Just r)
    Left (Just (PartError target i))
      | exprArity target == 0 -> Nothing <$ message "Part" "partd" [e]
      | otherwise -> Nothing <$ message "Part" "partw" [Int_ (toInteger i), target]
    Left Nothing -> Nothing <$ message "Part" "pkspec" [e]
  _ -> pure Nothing
  where
    -- 'Left Nothing' is an index that is not a part specification.
    go x = \case
      [] -> Right x
      Int_ i : rest -> at x (fromInteger i) >>= (`go` rest)
      Sym a : rest | Sym a == sym "All" -> mkApp (exprHead x) <$> traverse (`go` rest) (exprArgs x)
      App (Sym l) js : rest
        | l == sList,
          Just ks <- traverse intIndex (V.toList js) ->
            mkApp (exprHead x) . V.fromList <$> traverse (at x >=> (`go` rest)) ks
      _ -> Left Nothing
    at x i = first Just (part x i)
    intIndex = \case
      Int_ i -> Just (fromInteger i)
      _ -> Nothing

-- | @Apply[f, expr, spec]@: replace the head of every part at the levels
-- given, by default level 0 only. Atoms have no head to replace.
applyRule :: Expr -> Maybe Expr
applyRule e = case args e of
  [f, x] -> Just (rebuild (inLevel (Level 0, Level 0)) (replaceHead f) x)
  [f, x, spec] -> (\ls -> rebuild (inLevel ls) (replaceHead f) x) <$> levelSpec spec
  _ -> Nothing
  where
    replaceHead f = \case
      App _ as -> mkApp f as
      y -> y

-- | @Map[f, expr, spec]@: wrap every part at the levels given in @f@, by
-- default level 1.
mapRule :: Expr -> Maybe Expr
mapRule e = case args e of
  [f, x] -> Just (rebuild (inLevel (Level 1, Level 1)) (wrap f) x)
  [f, x, spec] -> (\ls -> rebuild (inLevel ls) (wrap f) x) <$> levelSpec spec
  _ -> Nothing
  where
    wrap f y = mkApp f (V.singleton y)

-- | @Level[expr, spec]@: the parts at the levels given, depth first, each
-- before the expression containing it, heads excluded.
levelRule :: Expr -> Maybe Expr
levelRule e = case args e of
  [x, spec] | Just ls <- levelSpec spec -> Just (apply sList (fst (collect (inLevel ls) 0 x)))
  _ -> Nothing
  where
    -- The parts selected, and the depth, in one pass.
    collect keep p x =
      let below = map (collect keep (p + 1)) (V.toList (exprArgs x))
          d = 1 + foldl' (\acc (_, k) -> max acc k) 0 below
       in (concatMap fst below ++ [x | keep p d], d)

-- | One bound of a level specification.
data Bound = Level !Integer | Infinite

-- | @n@ is @{1, n}@, @{n}@ is @{n, n}@, @Infinity@ is @{1, Infinity}@ and
-- @All@ is @{0, Infinity}@.
levelSpec :: Expr -> Maybe (Bound, Bound)
levelSpec spec = case spec of
  App (Sym l) ns | l == sList -> case V.toList ns of
    [n] -> (\b -> (b, b)) <$> bound n
    [m, n] -> (,) <$> bound m <*> bound n
    _ -> Nothing
  Sym a | Sym a == sym "All" -> Just (Level 0, Infinite)
  _ -> (Level 1,) <$> bound spec
  where
    bound = \case
      Int_ n -> Just (Level n)
      App (Sym d) xs | Sym d == sym "DirectedInfinity", [Int_ 1] <- V.toList xs -> Just Infinite
      _ -> Nothing

-- | Whether a part at level @p@ with depth @d@ is in the specification: a
-- non-negative bound compares the level, a negative bound @-k@ the depth.
inLevel :: (Bound, Bound) -> Integer -> Integer -> Bool
inLevel (lo, hi) p d = lower lo && upper hi
  where
    lower = \case
      Level m | m >= 0 -> p >= m
      Level m -> negate d >= m
      Infinite -> False
    upper = \case
      Level n | n >= 0 -> p <= n
      Level n -> negate d <= n
      Infinite -> True

-- | Rebuild bottom up, applying @f@ to every part the predicate selects by
-- its level and its depth (WL's @Depth@: 1 for an atom, one more than the
-- deepest argument, heads excluded), both taken in the original expression.
rebuild :: (Integer -> Integer -> Bool) -> (Expr -> Expr) -> Expr -> Expr
rebuild keep f = fst . go 0
  where
    go p x = case x of
      App h as ->
        let below = V.map (go (p + 1)) as
            d = 1 + V.foldl' (\acc (_, k) -> max acc k) 0 below
            x' = mkApp h (V.map fst below)
         in (if keep p d then f x' else x', d)
      _ -> (if keep p 1 then f x else x, 1)

-- | @FreeQ[expr, form]@: whether no subexpression, heads included, matches
-- the form.
freeQRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
freeQRule e = case args e of
  [x, form]
    | isPatternFree form -> pure (Just (bool sFalseE sTrueE (freeOf x form)))
    | otherwise -> Just . bool sFalseE sTrueE <$> noneMatch form x
  _ -> pure Nothing
  where
    noneMatch form x = do
      here <- isJust <$> matchOne form x
      if here
        then pure False
        else case x of
          App h as -> allM (noneMatch form) (h : V.toList as)
          _ -> pure True
