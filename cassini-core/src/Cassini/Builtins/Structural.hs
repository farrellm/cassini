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
import Cassini.Builtins.Define (Bound (..), Definition, PartSpec (..), args, define, down, inLevel, levelSpec, message, partSpec, sFalseE, sTrueE, sub)
import Cassini.Core.Expr (Expr, apply, exprArgs, exprArity, exprHead, mkApp, pattern App, pattern Int_)
import Cassini.Core.Symbol (sList)
import Cassini.Eval.Kernel (Kernel)
import Cassini.Pattern (isPatternFree, viewPattern)
import Cassini.Pattern.Match (match, observeFirst)
import Cassini.Structure (freeOf, part)
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
-- @All@. Every index is checked before any part is taken, so one that is not
-- a part specification is @Part::pkspec1@ even on an atom. Out of range is
-- @Part::partw@ on an expression, @{}@ included, and @Part::partd@ on an
-- atom. Either way the input stays unevaluated (§4.7).
partRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
partRule e = case args e of
  [x] -> pure (Just x)
  x : is@(_ : _) -> case traverse partSpec is of
    Left j -> Nothing <$ message "Part" "pkspec1" [j]
    Right specs -> case go x specs of
      Right r -> pure (Just r)
      Left (target, i) -> case target of
        App _ _ -> Nothing <$ message "Part" "partw" [Int_ i, target]
        _ -> Nothing <$ message "Part" "partd" [e]
  _ -> pure Nothing
  where
    go x = \case
      [] -> Right x
      Index i : rest -> at x i >>= (`go` rest)
      AllParts : rest -> parts x (V.toList (exprArgs x)) (`go` rest)
      Indices ks : rest -> parts x ks (at x >=> (`go` rest))
    -- Several parts of x, under its head. An atom has none, even for All or
    -- {}: Part::partd, as for an integer index (the index is not reported).
    parts x is f = case x of
      App h _ -> mkApp h . V.fromList <$> traverse f is
      _ -> Left (x, 0)
    -- An index beyond a machine integer is out of range, not wrapped.
    at x i = maybe (Left (x, i)) (first (const (x, i)) . part x) (toIntegralSized i)

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
    -- The form is read once, not once per subexpression.
    noneMatch form = go
      where
        p = viewPattern form
        go x = do
          here <- isJust <$> observeFirst (match p x mempty)
          if here
            then pure False
            else case x of
              App h as -> allM go (h : V.toList as)
              _ -> pure True
