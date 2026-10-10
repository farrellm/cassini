{-# LANGUAGE PatternSynonyms #-}

-- | Candidate retrieval for rule lookup: the 'RuleIndex' (DESIGN.md §4.5.5).
--
-- The index keys each rule on the head of its left-hand side's first
-- argument, when that argument is literal or a compound with a literal head:
-- @f[g[x_], y_]@ is keyed on @g@. A rule whose first argument is a blank, a
-- sequence, an alternative or a condition is a wildcard, a candidate for
-- every expression, and so is one whose first argument has an @Optional@
-- argument: @f[n_. x_]@ matches @f[y]@ through @Times@'s @OneIdentity@
-- ('requiredHead'). 'candidates' gives the rules keyed on the expression's
-- first argument's head and the wildcards, merged back into table order, so
-- specificity and definition order decide exactly as they did without it.
-- It is a superset of the rules that match; the matcher confirms them.
--
-- §8.3 measured it against trying every rule: on a table of fifty rules for
-- one head it is about thirteen times faster from the first subject on, and
-- building it costs less than one failed match, so there is no break-even
-- in the number of subjects to wait for. It is not Krebber's many-to-one
-- net, which would also share work among the candidates' matches.
--
-- The caller decides when the key is meaningful: not under an @Orderless@
-- or @Flat@ head, where any argument may come first, and not for upvalues,
-- whose tag is in some argument, not the head ("Cassini.Rules"). This
-- module must not import "Cassini.Pattern.Match", and it is polymorphic in
-- the rule type so that it need not import "Cassini.Rules" either.
module Cassini.Pattern.Net
  ( RuleIndex,
    fromSeq,
    toSeq,
    candidates,
  )
where

import Cassini.Core.Expr (Expr, exprHead, pattern App)
import Cassini.Pattern (PatternView (..), requiredHead, unholdPattern, viewPattern)
import Data.HashMap.Strict qualified as HashMap
import Data.Sequence qualified as Seq
import Data.Vector qualified as V

-- | An index over rules, in their table order.
data RuleIndex a = RuleIndex
  { riAll :: !(Seq a),
    riKeyed :: !(HashMap Expr (Seq (Int, a))),
    riWild :: !(Seq (Int, a))
  }

-- | Index rules, keeping their order; the function gives a rule's left-hand
-- side.
fromSeq :: (a -> Expr) -> Seq a -> RuleIndex a
fromSeq lhsOf rs = RuleIndex rs keyed wild
  where
    numbered = Seq.mapWithIndex (,) rs
    keyed = HashMap.fromListWith (flip (<>)) [(k, Seq.singleton ir) | ir@(_, r) <- toList numbered, Just k <- [ruleKey (lhsOf r)]]
    wild = Seq.filter (isNothing . ruleKey . lhsOf . snd) numbered

-- | Every indexed rule, in order.
toSeq :: RuleIndex a -> Seq a
toSeq = (.riAll)

-- | The rules that might match the expression, in table order: those keyed
-- on its first argument's head, and the wildcards.
candidates :: RuleIndex a -> Expr -> [a]
candidates ix e = case firstArgument e of
  Nothing -> toList ix.riAll
  Just a -> map snd (merge (toList (HashMap.findWithDefault Seq.empty (exprHead a) ix.riKeyed)) (toList ix.riWild))
  where
    merge xs ys = case (xs, ys) of
      (x : xs', y : ys')
        | fst x < fst y -> x : merge xs' ys
        | otherwise -> y : merge xs ys'
      _ -> xs <> ys

-- | The head of the first argument a rule's left-hand side requires, if it
-- requires one. Read through the pattern view, so that the arguments are the
-- rule's head's, not those of a @Condition@ around it.
ruleKey :: Expr -> Maybe Expr
ruleKey lhs = case viewPattern (unholdPattern lhs) of
  PLiteral e -> exprHead <$> firstArgument e
  PCompound _ ps -> ps V.!? 0 >>= key
  -- A condition on the whole left-hand side keeps its first argument.
  PCondition (PCompound _ ps) _ -> ps V.!? 0 >>= key
  _ -> Nothing
  where
    key = \case
      PLiteral x -> Just (exprHead x)
      PVerbatim x -> Just (exprHead x)
      q@(PCompound _ _) -> requiredHead q
      PHold q -> key q
      _ -> Nothing

firstArgument :: Expr -> Maybe Expr
firstArgument = \case
  App _ as -> as V.!? 0
  _ -> Nothing
