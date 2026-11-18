{-# LANGUAGE PatternSynonyms #-}

-- | Polynomial builtins (DESIGN.md §2.2, §6.5). So far @Expand@, which is
-- Cohen's @Algebraic_expand@ over the evaluator's normal form (§4.12); the
-- rest arrive with Stage 2.
module Cassini.Builtins.Polynomial (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Arithmetic (fromSimplified)
import Cassini.Builtins.Define (Definition, args, define, down)
import Cassini.Builtins.Held (outsideHeld)
import Cassini.Core.Expr (apply, pattern Call)
import Cassini.Core.Symbol (Symbol, sList, systemSymbol)
import Cassini.Simplify.Elementary (simplifyE)
import Cassini.Simplify.Rational (algebraicExpand)

-- | @Expand@. It threads over a list, as WL's does without being
-- @Listable@: @Expand[{(1 + x)^2}]@ is @{1 + 2 x + x^2}@ (WL 15.0.1).
definitions :: [Definition]
definitions =
  [ define "Expand" [Protected] [down expand]
  ]
  where
    expand e = case args e of
      [Call l xs] | l == sList -> pure (Just (apply sList [apply sExpand [x] | x <- xs]))
      [x] -> outsideHeld (simplifyE >=> algebraicExpand) x >>= fromSimplified e
      _ -> pure Nothing

sExpand :: Symbol
sExpand = systemSymbol "Expand"
