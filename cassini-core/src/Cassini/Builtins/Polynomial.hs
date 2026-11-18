-- | Polynomial builtins (DESIGN.md §2.2, §6.5). So far @Expand@, which is
-- Cohen's @Algebraic_expand@ over the evaluator's normal form (§4.12); the
-- rest arrive with Stage 2.
module Cassini.Builtins.Polynomial (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, define, down)
import Cassini.Builtins.Held (overList, unary)
import Cassini.Simplify.Rational (algebraicExpand)

-- | @Expand@. It threads over a list, as WL's does without being
-- @Listable@: @Expand[{(1 + x)^2}]@ is @{1 + 2 x + x^2}@ (WL 15.0.1).
definitions :: [Definition]
definitions =
  [ define "Expand" [Protected] [down (overList (unary algebraicExpand))]
  ]
