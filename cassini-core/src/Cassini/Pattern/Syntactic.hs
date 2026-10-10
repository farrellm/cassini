{-# LANGUAGE PatternSynonyms #-}

-- | Structural matching, no attributes (DESIGN.md §4.5.3, step 1): blanks,
-- names, conditions, tests, alternatives, @Except@, @HoldPattern@,
-- @Verbatim@ and literals. Every later matcher calls back into it.
--
-- Sequence patterns (@__@, @___@, @Repeated@, @Optional@) match nothing here;
-- distributing arguments among them is "Cassini.Pattern.Sequence"'s job, and
-- arrives with milestone 1b, as does matching under @Orderless@ heads. A
-- compound pattern matches only a subject with the same number of arguments,
-- position by position.
module Cassini.Pattern.Syntactic (matchSyntactic) where

import Cassini.Core.Expr (Expr, exprHead, pattern App, pattern Sym)
import Cassini.Core.Symbol (sTrue)
import Cassini.Pattern (Binding (..), MatchOps (..), PatternView (..), Subst, applySubst)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V

-- | Match one pattern node against a subject, extending the substitution.
-- Every way of matching is a result, so alternatives and their bindings are
-- all enumerated.
matchSyntactic :: (MonadPlus m) => MatchOps m -> PatternView -> Expr -> Subst -> m Subst
matchSyntactic ops p s sigma = case p of
  PBlank c -> sigma <$ guard (headMatches c)
  PNamed x q -> ops.recur q s sigma >>= bind x
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
    -- A name already bound must be bound to this subject: one name means one
    -- value across a pattern.
    bind x sigma' = case Map.lookup x sigma' of
      Nothing -> pure (Map.insert x (BOne s) sigma')
      Just (BOne t) -> sigma' <$ guard (t == s)
      Just (BSeq _) -> empty

isTrue :: Expr -> Bool
isTrue = \case
  Sym t -> t == sTrue
  _ -> False
