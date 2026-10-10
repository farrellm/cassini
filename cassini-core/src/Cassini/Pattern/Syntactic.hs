{-# LANGUAGE PatternSynonyms #-}

-- | Structural matching, no attributes (DESIGN.md §4.5.3, step 1): blanks,
-- names, conditions, tests, alternatives, @Except@, @HoldPattern@,
-- @Verbatim@ and literals. Every later matcher calls back into it.
--
-- Sequence patterns (@__@, @___@, @Repeated@, @Optional@) match nothing
-- here: they take runs of arguments, which only an argument list has, and
-- "Cassini.Pattern.Sequence" distributes them. A compound pattern here
-- matches only a subject with the same number of arguments, position by
-- position; "Cassini.Pattern.Match" sends it here only when no argument
-- pattern takes a run and the head has neither @Flat@ nor @Orderless@.
module Cassini.Pattern.Syntactic (matchSyntactic) where

import Cassini.Core.Expr (Expr, exprHead, pattern App)
import Cassini.Pattern (Binding (..), MatchOps (..), PatternView (..), Subst, applySubst, bindName, isTrue)
import Data.Vector qualified as V

-- | Match one pattern node against a subject, extending the substitution.
-- Every way of matching is a result, so alternatives and their bindings are
-- all enumerated.
matchSyntactic :: (MonadPlus m) => MatchOps m -> PatternView -> Expr -> Subst -> m Subst
matchSyntactic ops p s sigma = case p of
  PBlank c -> sigma <$ guard (headMatches c)
  PNamed x q -> ops.recur q s sigma >>= bindName x (BOne s)
  -- Only True admits a match (§4.13); the test sees the bindings so far.
  PCondition q test -> do
    sigma' <- ops.recur q s sigma
    decided <- ops.evalM (applySubst sigma' test)
    sigma' <$ guard (isTrue decided)
  PTest q f -> do
    sigma' <- ops.recur q s sigma
    decided <- ops.evalM (App f (V.singleton s))
    sigma' <$ guard (isTrue decided)
  PAlternative qs -> asum [ops.recur q s sigma | q <- qs]
  PLiteral e -> sigma <$ guard (e == s)
  PCompound h qs -> case s of
    App sh sargs
      | V.length sargs == V.length qs -> do
          sigma' <- ops.recur h sh sigma
          V.foldM (\acc (q, a) -> ops.recur q a acc) sigma' (V.zip qs sargs)
    _ -> empty
  PExcept c q -> do
    excluded <- ops.matchesM c s sigma
    guard (not excluded)
    maybe (pure sigma) (\q' -> ops.recur q' s sigma) q
  PHold q -> ops.recur q s sigma
  PVerbatim e -> sigma <$ guard (e == s)
  PBlankSeq _ -> empty
  PBlankNull _ -> empty
  PRepeated _ _ -> empty
  POptional _ _ -> empty
  where
    headMatches = maybe True (== exprHead s)
