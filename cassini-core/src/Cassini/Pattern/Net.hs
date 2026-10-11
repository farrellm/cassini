{-# LANGUAGE PatternSynonyms #-}

-- | Candidate retrieval for rule lookup: the 'RuleIndex' (DESIGN.md §4.5.5).
--
-- A rule whose left-hand side has no pattern object in it matches only an
-- expression equal to it, so it is filed under the whole left-hand side, and
-- is a candidate for that expression only: a memoising definition's
-- @f[1]@, @f[2]@, … cost one hash lookup, however many there are. Every
-- other rule is keyed on the head of its left-hand side's first argument,
-- when that argument is literal or a compound with a literal head:
-- @f[g[x_], y_]@ is keyed on @g@. A rule whose first argument is a blank, a
-- sequence, an alternative or a condition is a wildcard, a candidate for
-- every expression, and so is one whose first argument has an @Optional@
-- argument: @f[n_. x_]@ matches @f[y]@ through @Times@'s @OneIdentity@
-- ('requiredHead'). 'candidates' gives the rules filed under the expression,
-- those keyed on its first argument's head and the wildcards, merged back
-- into table order, so specificity and definition order decide exactly as
-- they did without it. It is a superset of the rules that match; the
-- matcher confirms them.
--
-- Rules are ordered by a key the caller gives, so 'insert' and 'delete' are
-- logarithmic and nothing is rebuilt when a table changes.
--
-- §8.3 measured it against trying every rule: on a table of fifty rules for
-- one head it is about thirteen times faster from the first subject on, and
-- building it costs less than one failed match, so there is no break-even
-- in the number of subjects to wait for. It is not Krebber's many-to-one
-- net, which would also share work among the candidates' matches.
--
-- The caller decides when the key is meaningful: not under an @Orderless@
-- or @Flat@ head, where any argument may come first and a rule applies to a
-- run of the arguments, and not for upvalues, whose tag is in some argument,
-- not the head ("Cassini.Rules"). This module must not import
-- "Cassini.Pattern.Match", and it is polymorphic in the rule type so that it
-- need not import "Cassini.Rules" either.
module Cassini.Pattern.Net
  ( RuleIndex,
    emptyIndex,
    insert,
    delete,
    indexRules,
    elems,
    candidates,
  )
where

import Cassini.Core.Expr (Expr, exprHead, pattern App)
import Cassini.Pattern (PatternView (..), isPatternFree, requiredHead, unholdPattern, viewPattern)
import Data.HashMap.Strict qualified as HashMap
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V

-- | An index over rules, ordered by their keys.
data RuleIndex k a = RuleIndex
  { -- | Every rule.
    riAll :: !(Map k a),
    -- | Rules with no pattern object, by their left-hand side.
    riExact :: !(HashMap Expr (Map k a)),
    -- | Rules by the head their first argument requires.
    riKeyed :: !(HashMap Expr (Map k a)),
    -- | Every other rule.
    riWild :: !(Map k a)
  }

-- | Where a rule is filed.
data Slot = Exact !Expr | Keyed !Expr | Wild

-- | No rules.
emptyIndex :: RuleIndex k a
emptyIndex = RuleIndex Map.empty HashMap.empty HashMap.empty Map.empty

-- | Add a rule under its key, given its left-hand side; a rule already
-- under that key is replaced.
insert :: (Ord k) => Expr -> k -> a -> RuleIndex k a -> RuleIndex k a
insert lhs k r ix = case slotOf lhs of
  Exact e -> ix' {riExact = HashMap.insertWith Map.union e one ix.riExact}
  Keyed h -> ix' {riKeyed = HashMap.insertWith Map.union h one ix.riKeyed}
  Wild -> ix' {riWild = Map.insert k r ix.riWild}
  where
    one = Map.singleton k r
    ix' = ix {riAll = Map.insert k r ix.riAll}

-- | Remove the rule under a key, given its left-hand side.
delete :: (Ord k) => Expr -> k -> RuleIndex k a -> RuleIndex k a
delete lhs k ix = case slotOf lhs of
  Exact e -> ix' {riExact = HashMap.update shrink e ix.riExact}
  Keyed h -> ix' {riKeyed = HashMap.update shrink h ix.riKeyed}
  Wild -> ix' {riWild = Map.delete k ix.riWild}
  where
    shrink m = let m' = Map.delete k m in if Map.null m' then Nothing else Just m'
    ix' = ix {riAll = Map.delete k ix.riAll}

-- | Index rules under their keys; the function gives a rule's left-hand
-- side.
indexRules :: (Ord k) => (a -> Expr) -> [(k, a)] -> RuleIndex k a
indexRules lhsOf = foldl' (\ix (k, r) -> insert (lhsOf r) k r ix) emptyIndex

-- | Every indexed rule, in key order.
elems :: RuleIndex k a -> [a]
elems = Map.elems . (.riAll)

-- | The rules that might match the expression, in key order: those filed
-- under it, those keyed on its first argument's head, and the wildcards.
-- An expression with no arguments gets every rule.
candidates :: (Ord k) => RuleIndex k a -> Expr -> [a]
candidates ix e = case firstArgument e of
  Nothing -> elems ix
  Just a ->
    map snd $
      merge
        (bucket (HashMap.lookup e ix.riExact))
        (merge (bucket (HashMap.lookup (exprHead a) ix.riKeyed)) (Map.toAscList ix.riWild))
  where
    bucket = maybe [] Map.toAscList
    merge xs ys = case (xs, ys) of
      (x : xs', y : ys')
        | fst x < fst y -> x : merge xs' ys
        | otherwise -> y : merge xs ys'
      _ -> xs <> ys

-- | Where a left-hand side is filed, seen through @HoldPattern@.
slotOf :: Expr -> Slot
slotOf lhs
  | isPatternFree u = Exact u
  | otherwise = maybe Wild Keyed (ruleKey u)
  where
    u = unholdPattern lhs

-- | The head of the first argument a left-hand side with a pattern object
-- requires, if it requires one. Read through the pattern view, so that the
-- arguments are the rule's head's, not those of a @Condition@ around it.
ruleKey :: Expr -> Maybe Expr
ruleKey lhs = case viewPattern lhs of
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
