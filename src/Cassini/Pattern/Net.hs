-- | Candidate retrieval for rule lookup: the 'RuleIndex' interface
-- (DESIGN.md §4.5.5).
--
-- This first implementation returns every rule. It exists so that a
-- discrimination net, if milestone 1b's measured crossover asks for one, is a
-- new implementation here rather than a refactor of "Cassini.Rules". It only
-- retrieves candidates; the matcher confirms them. It must not import
-- "Cassini.Pattern.Match", and it is polymorphic in the rule type so that it
-- need not import "Cassini.Rules" either.
module Cassini.Pattern.Net
  ( RuleIndex,
    fromSeq,
    toSeq,
    candidates,
  )
where

import Cassini.Core.Expr (Expr)

-- | An index over rules, in their table order.
newtype RuleIndex a = RuleIndex (Seq a)

-- | Index rules, keeping their order.
fromSeq :: Seq a -> RuleIndex a
fromSeq = RuleIndex

-- | Every indexed rule, in order.
toSeq :: RuleIndex a -> Seq a
toSeq (RuleIndex rs) = rs

-- | The rules that might match the expression, in table order. A superset of
-- the rules that do: here, all of them.
candidates :: RuleIndex a -> Expr -> Seq a
candidates (RuleIndex rs) _ = rs
