{-# LANGUAGE PatternSynonyms #-}

-- | The zero test (DESIGN.md §5.6), as Stage 1 has it: the rational layer
-- only (§4.8).
--
-- Source: @references/papers/foundations/richardson1968_*.pdf@ — for the
-- class of expressions over the rationals, π, ln 2, a variable, @+ - *@,
-- composition, and @sin@/@exp@/@abs@, the predicate @E = 0@ is undecidable.
--
-- 'Nothing' is "I do not know", returned honestly rather than collapsed into
-- @'Just' 'False'@. Milestone 2a adds the polynomial and trigonometric
-- layers behind the same signature, so its callers, §4.14's @Equal@ first,
-- get stronger with no change.
module Cassini.Zero (isZero) where

import Cassini.Core.Expr (Expr, pattern Num)
import Cassini.Eval.Kernel (Kernel, evaluate)
import Cassini.Number (Number (NInt))
import Effectful (Eff, (:>))

-- | Whether an expression is zero: layer 1, an exact number, decided at
-- once; layer 2, structural identity after automatic simplification, which
-- it reaches by evaluating (§4.3). Anything else is 'Nothing' until 2a.
--
-- An evaluated non-number is not 'Just' 'False': @x - y@ is no proof that
-- @x@ and @y@ differ.
isZero :: (Kernel :> es) => Expr -> Eff es (Maybe Bool)
isZero e = case e of
  Num n -> pure (Just (n == NInt 0))
  _ ->
    evaluate e <&> \case
      Num n -> Just (n == NInt 0)
      _ -> Nothing
