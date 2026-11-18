-- | @TrigExpand@, @TrigReduce@ and @Simplify@ (DESIGN.md §4.12): each a thin
-- wrapper over one procedure of "Cassini.Simplify.Trig".
--
-- @Simplify@ is Cohen's @Simplify_trig@, one fixed strategy, not WL's
-- search under a complexity measure (D17). A denominator that contracts to
-- 0 is mapped as @1/0@ and @0/0@ are (§4.7). The internal
-- @Cassini`TrigZero@ that @isZero@ evaluates arrives with §5.6, at 2a.
module Cassini.Builtins.Simplify (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, define, down)
import Cassini.Builtins.Held (overList, unary)
import Cassini.Simplify.Trig (contractTrig, expandTrig, simplifyTrig, trigSubstitute)

-- | The three builtins. @Simplify@ threads over a list, as WL's does without
-- being @Listable@: @Simplify[{1/(1 - Sin[x]) + 1/(1 + Sin[x])}]@ simplifies
-- the element as it would alone, where Cohen's rationalization would stop at
-- the list (WL 15.0.1).
definitions :: [Definition]
definitions =
  [ define "TrigExpand" [Listable, Protected] [down (unary expandTrig)],
    define "TrigReduce" [Listable, Protected] [down (unary (trigSubstitute >=> contractTrig))],
    define "Simplify" [Protected] [down (overList (unary simplifyTrig))]
  ]
