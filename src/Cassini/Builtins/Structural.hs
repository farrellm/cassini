{-# LANGUAGE PatternSynonyms #-}

-- | @Head@, @Part@, @Length@, @Apply@, @Map@, @Level@ and @FreeQ@
-- (DESIGN.md §2.2, §3.7).
--
-- Thin bindings over "Cassini.Structure", except @FreeQ@, whose second
-- argument is a pattern: 'freeOf' is its fast path when the form has no
-- pattern object, and otherwise every subexpression, heads included, goes
-- through the matcher.
--
-- Only the level-1 forms of @Apply@ and @Map@ are here, and @Level@ takes
-- non-negative level specifications; the rest arrives with the corpus
-- triage that asks for it.
module Cassini.Builtins.Structural (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, message, sFalseE, sTrueE, sym)
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
  [ define "Head" [Protected] [down (pure . headRule)],
    define "Length" [Protected] [down (pure . lengthRule)],
    define "Part" [NHoldRest, Protected, ReadProtected] [down partRule],
    define "Apply" [Protected] [down (pure . applyRule)],
    define "Map" [Protected] [down (pure . mapRule)],
    define "Level" [Protected] [down (pure . levelRule)],
    define "FreeQ" [Protected] [down freeQRule],
    define "All" [Protected] []
  ]

headRule :: Expr -> Maybe Expr
headRule e = case args e of
  [x] -> Just (exprHead x)
  [x, h] -> Just (mkApp h (V.singleton (exprHead x)))
  _ -> Nothing

lengthRule :: Expr -> Maybe Expr
lengthRule e = case args e of
  [x] -> Just (Int_ (toInteger (exprArity x)))
  _ -> Nothing

-- | @Part[expr, i, j, …]@: each index an integer, a list of integers, or
-- @All@. Out of range is @Part::partw@ on an expression and @Part::partd@ on
-- an atom, and the input stays unevaluated (§4.7).
partRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
partRule e = case args e of
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

-- | @Apply[f, expr]@: replace the head; an atom stays.
applyRule :: Expr -> Maybe Expr
applyRule e = case args e of
  [f, App _ as] -> Just (mkApp f as)
  [_, x] -> Just x
  _ -> Nothing

-- | @Map[f, expr]@: apply @f@ to each argument; an atom stays.
mapRule :: Expr -> Maybe Expr
mapRule e = case args e of
  [f, App h as] -> Just (mkApp h (V.map (mkApp f . V.singleton) as))
  [_, x] -> Just x
  _ -> Nothing

-- | @Level[expr, n]@ is levels 1 through @n@, @Level[expr, {n}]@ level @n@
-- alone, and @Level[expr, {m, n}]@ levels @m@ through @n@: depth first,
-- each subexpression before the expression containing it, heads excluded.
levelRule :: Expr -> Maybe Expr
levelRule e = case args e of
  [x, spec] | Just (lo, hi) <- levelSpec spec -> Just (apply sList (collect lo hi 0 x))
  _ -> Nothing
  where
    levelSpec = \case
      Int_ n | n >= 0 -> Just (1, n)
      App (Sym l) ns | l == sList -> case V.toList ns of
        [Int_ n] | n >= 0 -> Just (n, n)
        [Int_ m, Int_ n] | m >= 0, n >= 0 -> Just (m, n)
        _ -> Nothing
      _ -> Nothing
    collect lo hi d x =
      concatMap (collect lo hi (d + 1)) (if d < hi then V.toList (exprArgs x) else [])
        ++ [x | d >= lo, d <= hi, d > 0 || lo == 0]

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
