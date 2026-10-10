-- | The matcher's public face: the 'MatchT' monad, its three observation
-- functions, and 'match', 'matchOne' and 'matchAll' (DESIGN.md §4.5.2).
--
-- No @effectful@ handler can enumerate matches: @Eff@ cannot resume a
-- continuation twice, so @Effectful.NonDet@ is @Maybe@-shaped. Nondeterminism
-- is therefore @logict@'s 'LogicT' over 'Eff', and it is confined to this
-- module: 'MatchT' is a newtype, and §2.6's rule 6 lets no other module import
-- "Control.Monad.Logic".
--
-- The matchers themselves are polymorphic in the monad (they take a
-- 'MatchOps'), and 'match' ties the knot here, so this module can import every
-- matcher without any matcher importing it.
module Cassini.Pattern.Match
  ( MatchT,
    liftMatch,
    observeFirst,
    observeAll,
    match,
    matchOne,
    matchAll,
  )
where

import Cassini.Core.Expr (Expr)
import Cassini.Eval.Kernel (Kernel, evaluate)
import Cassini.Pattern (MatchOps (..), PatternView, Subst, viewPattern)
import Cassini.Pattern.Syntactic (matchSyntactic)
import Control.Monad.Logic (LogicT, observeAllT, observeManyT)
import Effectful (Eff, (:>))

-- | Matching: every way a pattern matches, lazily, with kernel calls for side
-- conditions.
newtype MatchT es a = MatchT (LogicT (Eff es) a)
  deriving newtype (Functor, Applicative, Monad, Alternative, MonadPlus)

-- | Run a kernel computation inside a match.
liftMatch :: Eff es a -> MatchT es a
liftMatch = MatchT . lift

-- | The first result, computing no more than it needs.
observeFirst :: MatchT es a -> Eff es (Maybe a)
observeFirst (MatchT m) = listToMaybe <$> observeManyT 1 m

-- | Every result, in order.
observeAll :: MatchT es a -> Eff es [a]
observeAll (MatchT m) = observeAllT m

-- | Match a pattern against a subject, extending a substitution, every way it
-- matches.
match :: (Kernel :> es) => PatternView -> Expr -> Subst -> MatchT es Subst
match = matchSyntactic ops
  where
    ops =
      MatchOps
        { recur = match,
          evalM = liftMatch . evaluate,
          matchesM = \p s sigma -> liftMatch (isJust <$> observeFirst (match p s sigma))
        }

-- | The first match, if there is one.
matchOne :: (Kernel :> es) => Expr -> Expr -> Eff es (Maybe Subst)
matchOne p s = observeFirst (match (viewPattern p) s mempty)

-- | Every match, in order.
matchAll :: (Kernel :> es) => Expr -> Expr -> Eff es [Subst]
matchAll p s = observeAll (match (viewPattern p) s mempty)
