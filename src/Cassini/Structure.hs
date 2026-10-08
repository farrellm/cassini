{-# LANGUAGE PatternSynonyms #-}

-- | Structure-based operators: Cohen's primitive expression operators, as the
-- Haskell API and the backing for WL's structural builtins (DESIGN.md §3.7).
--
-- Source: @references/papers/textbooks/cohen2002_*.pdf@ §3.3 (@Kind@,
-- @Operand@, @Number_of_operands@, @Construct@, @Free_of@, @Substitute@,
-- @Sequential_substitute@, @Concurrent_substitute@).
--
-- One departure from Cohen: his operators are not sub-expressions, but here an
-- application's head is, as in WL, so @freeOf (f[x]) f@ is 'False' and
-- 'substitute' rewrites heads. That is what @FreeQ@ and @ReplaceAll@ need from
-- their fast path.
module Cassini.Structure
  ( Kind (..),
    exprKind,
    PartError (..),
    part,
    numberOfParts,
    construct,
    freeOf,
    substitute,
    substituteSeq,
    substituteAll,
  )
where

import Cassini.Core.Expr (Expr, exprArity, exprHead, mkApp, pattern App, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Symbol (sFactorial, sPlus, sPower, sTimes)
import Data.Vector qualified as V

-- $setup
-- >>> import Cassini.Core.Expr (apply, mkNumber, mkSymbol)
-- >>> import Cassini.Core.Symbol (globalSymbol)
-- >>> import Cassini.Number (Number (NInt))

-- | Cohen's kinds, extended with strings (O-K, §3.5).
data Kind
  = KConstant
  | KString
  | KSymbol
  | KProduct
  | KSum
  | KPower
  | KFactorial
  | KFunction
  deriving stock (Eq, Show, Enum, Bounded)

-- | The kind. @Plus@, @Times@ and @Factorial@ heads, and @Power@ with exactly
-- two arguments, have their Cohen kinds. @Factorial@ needs exactly one
-- argument, as @Power@ needs two, because O-5 compares its operand. Any other
-- application is a function, including a curried one (@f[x][y]@).
--
-- >>> exprKind (apply sPower [mkSymbol (globalSymbol "x")])
-- KFunction
exprKind :: Expr -> Kind
exprKind = \case
  Num _ -> KConstant
  Str _ -> KString
  Sym _ -> KSymbol
  App (Sym f) as
    | f == sPlus -> KSum
    | f == sTimes -> KProduct
    | f == sPower, V.length as == 2 -> KPower
    | f == sFactorial, V.length as == 1 -> KFactorial
  App _ _ -> KFunction

-- | @Part[expr, i]@ does not exist.
data PartError = PartError
  { -- | The expression indexed.
    partExpr :: !Expr,
    -- | The index asked for.
    partIndex :: !Int
  }
  deriving stock (Eq, Show)

-- | Part @i@: 0 is the head, @1..n@ the arguments, and @-n..-1@ the arguments
-- counted from the end, as in WL. An atom has only part 0.
--
-- >>> part (apply (globalSymbol "f") [mkNumber (NInt 1), mkNumber (NInt 2)]) (-1)
-- Right 2
-- >>> isLeft (part (mkSymbol (globalSymbol "x")) 1)
-- True
part :: Expr -> Int -> Either PartError Expr
part e i
  | i == 0 = Right (exprHead e)
  | otherwise = case e of
      App _ as
        | i > 0, Just x <- as V.!? (i - 1) -> Right x
        | i < 0, Just x <- as V.!? (V.length as + i) -> Right x
      _ -> Left (PartError e i)

-- | The number of arguments; 0 for an atom.
numberOfParts :: Expr -> Int
numberOfParts = exprArity

-- | An application of a head to arguments.
construct :: Expr -> V.Vector Expr -> Expr
construct = mkApp

-- | Whether no complete subexpression of @u@, heads included, is @t@.
--
-- >>> let a = mkSymbol (globalSymbol "a"); b = mkSymbol (globalSymbol "b"); c = mkSymbol (globalSymbol "c")
-- >>> freeOf (apply sPlus [a, b, c]) (apply sPlus [a, b])
-- True
freeOf :: Expr -> Expr -> Bool
freeOf u t
  | u == t = False
  | otherwise = case u of
      App h as -> freeOf h t && all (`freeOf` t) as
      _ -> True

-- | @substitute u t r@ replaces every complete subexpression of @u@ that is
-- @t@ with @r@. The replacement is not searched again. Subtrees with no
-- occurrence are returned as they are, not rebuilt.
substitute :: Expr -> Expr -> Expr -> Expr
substitute u t r = substituteAll u [(t, r)]

-- | Substitute each pair in turn: later pairs see earlier replacements.
substituteSeq :: Expr -> [(Expr, Expr)] -> Expr
substituteSeq = foldl' (\u (t, r) -> substitute u t r)

-- | Substitute all pairs at once: at each subexpression the first pair whose
-- target it is applies, and replacements are not searched again.
substituteAll :: Expr -> [(Expr, Expr)] -> Expr
substituteAll u0 rules = fromMaybe u0 (go u0)
  where
    -- 'Nothing' means unchanged, so unchanged subtrees keep their nodes.
    go u = case find ((== u) . fst) rules of
      Just (_, r) -> Just r
      Nothing -> case u of
        App h as ->
          let h' = go h
              as' = V.map go as
           in if isNothing h' && V.all isNothing as'
                then Nothing
                else Just (mkApp (fromMaybe h h') (V.zipWith fromMaybe as as'))
        _ -> Nothing
