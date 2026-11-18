-- | Polynomial builtins (DESIGN.md §2.2, §6.5). So far @Expand@, which is
-- Cohen's @Algebraic_expand@ over the evaluator's normal form (§4.12); the
-- rest arrive with Stage 2.
module Cassini.Builtins.Polynomial (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Arithmetic (fromSimplified)
import Cassini.Builtins.Define (Definition, args, define, down)
import Cassini.Simplify.Elementary (simplifyE)
import Cassini.Simplify.Rational (algebraicExpand)

-- | @Expand@.
definitions :: [Definition]
definitions =
  [ define "Expand" [Protected] [down expand]
  ]
  where
    expand e = case args e of
      [x] -> fromSimplified e (simplifyE x >>= algebraicExpand)
      _ -> pure Nothing
