-- | @TrigExpand@, @TrigReduce@ and @Simplify@ (DESIGN.md §4.12): each a thin
-- wrapper over one procedure of "Cassini.Simplify.Trig".
--
-- @Simplify@ is Cohen's @Simplify_trig@, one fixed strategy, not WL's
-- search under a complexity measure (D17). A denominator that contracts to
-- 0 is mapped as @1/0@ and @0/0@ are (§4.7). The internal
-- @Cassini`TrigZero@ that @isZero@ evaluates arrives with §5.6, at 2a.
module Cassini.Builtins.Simplify (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Arithmetic (fromSimplified)
import Cassini.Builtins.Define (Definition, args, define, down)
import Cassini.Builtins.Held (outsideHeld)
import Cassini.Core.Expr (Expr)
import Cassini.Eval.Kernel (Kernel)
import Cassini.Simplify.Automatic (Undefined)
import Cassini.Simplify.Trig (contractTrig, expandTrig, simplifyTrig, trigSubstitute)
import Effectful (Eff, (:>))

-- | The three builtins.
definitions :: [Definition]
definitions =
  [ define "TrigExpand" [Listable, Protected] [down (unary expandTrig)],
    define "TrigReduce" [Listable, Protected] [down (unary (trigSubstitute >=> contractTrig))],
    define "Simplify" [Protected] [down (unary simplifyTrig)]
  ]

-- | A one-argument builtin over a procedure on normal forms. The argument
-- is already evaluated, so in the evaluator's normal form, which is
-- 'Cassini.Simplify.Elementary.simplifyE''s (§4.11); what it holds stays out
-- of the procedure's reach ('outsideHeld').
unary :: (Kernel :> es) => (Expr -> Either Undefined Expr) -> Expr -> Eff es (Maybe Expr)
unary f e = case args e of
  [x] -> outsideHeld f x >>= fromSimplified e
  _ -> pure Nothing
