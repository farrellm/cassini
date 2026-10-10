{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE PatternSynonyms #-}

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
-- matcher without any matcher importing it. 'match' also dispatches among
-- them: a compound pattern's arguments go to "Cassini.Pattern.Commutative"
-- under an @Orderless@ head, to "Cassini.Pattern.Sequence" under a @Flat@
-- head or when an argument pattern takes a run, and are matched position by
-- position otherwise.
module Cassini.Pattern.Match
  ( MatchT,
    liftMatch,
    observeFirst,
    observeAll,
    match,
    matchOne,
    matchAll,
    matchRule,
    matchRuleOrRun,

    -- * Configuration, for measurement
    MatchConfig (..),
    defaultMatchConfig,
    matchWith,
  )
where

import Cassini.Attributes (Attribute (OneIdentity), AttributeSet, isFlat, isOrderless, member)
import Cassini.Core.Expr (Expr, apply, exprHead, mkApp, pattern App, pattern Sym)
import Cassini.Core.Symbol (sBlankNullSequence, sCondition, sPattern, sTrue, symbol)
import Cassini.Eval.Kernel (Kernel, evaluate, lookupSymbol)
import Cassini.Pattern (MatchOps (..), PatternView (..), Subst, applySubst, argRange, bindDefault, builtinDefault, unholdPattern, viewPattern)
import Cassini.Pattern.Commutative (matchCommutative)
import Cassini.Pattern.Sequence (ArgContext (..), matchArgs)
import Cassini.Pattern.Syntactic (matchSyntactic)
import Cassini.Rules (SymbolInfo (..))
import Control.Monad.Logic (LogicT, observeAllT, observeManyT)
import Data.List (partition)
import Data.Vector qualified as V
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
match = matchWith defaultMatchConfig

-- | The knobs §8.3 turns to measure the matcher. Evaluation always uses
-- 'defaultMatchConfig'.
newtype MatchConfig = MatchConfig
  { -- | Whether the commutative matcher runs its first two steps,
    -- constants and bound variables (§4.5.4).
    pruneCommutative :: Bool
  }

-- | Every step on.
defaultMatchConfig :: MatchConfig
defaultMatchConfig = MatchConfig {pruneCommutative = True}

-- | 'match', configured.
matchWith :: (Kernel :> es) => MatchConfig -> PatternView -> Expr -> Subst -> MatchT es Subst
matchWith cfg = go
  where
    ops =
      MatchOps
        { recur = go,
          evalM = liftMatch . evaluate,
          matchesM = \p s sigma -> liftMatch (isJust <$> observeFirst (go p s sigma)),
          attributesM = liftMatch . headAttributes
        }
    go p s sigma = case p of
      PCompound h qs -> compound h qs s sigma <|> oneIdentity h qs s sigma
      _ -> matchSyntactic ops p s sigma
    compound h qs s sigma = case s of
      App sh sargs -> do
        sigma' <- go h sh sigma
        attrs <- ops.attributesM sh
        let ctx = ArgContext {acHead = sh, acFlat = isFlat attrs, acOneIdentity = member OneIdentity attrs}
        if
          | isOrderless attrs -> matchCommutative cfg.pruneCommutative ops ctx qs sargs sigma'
          | ctx.acFlat || any ((/= (1, Just 1)) . argRange False) qs -> matchArgs ops ctx qs sargs sigma'
          | V.length qs == V.length sargs -> V.foldM (\acc (q, a) -> go q a acc) sigma' (V.zip qs sargs)
          | otherwise -> empty
      _ -> empty
    -- Under a OneIdentity head, f[p, q:.d, …] matches what p matches, the
    -- optional arguments taking their defaults, when the subject is not an
    -- f[…] itself (§4.5.1): x matches n_. x_ with n = 1.
    oneIdentity h qs s sigma = case h of
      PLiteral hd@(Sym f) | exprHead s /= hd -> do
        attrs <- ops.attributesM hd
        guard (member OneIdentity attrs)
        oneIdentityArgs f qs s sigma
      _ -> empty
    oneIdentityArgs f qs s sigma = case partition (isOptional . snd) (zip [1 ..] (V.toList qs)) of
      (optionals@(_ : _), [(_, q)]) -> do
        sigma' <- foldlM (\acc (i, o) -> defaulted f (V.length qs) i o acc) sigma optionals
        go q s sigma'
      _ -> empty
    defaulted f n i o sigma = case o of
      POptional q d -> maybe empty (\v -> bindDefault q v sigma) (d <|> builtinDefault f i n)
      _ -> empty
    isOptional = \case
      POptional _ _ -> True
      _ -> False

-- | The attributes of a subject's head: a symbol's own; a compound head has
-- none.
headAttributes :: (Kernel :> es) => Expr -> Eff es AttributeSet
headAttributes = \case
  Sym f -> (.siAttributes) <$> lookupSymbol f
  _ -> pure mempty

-- | A rule's right-hand side, instantiated by each match of its left-hand
-- side under which it applies: @lhs :> rhs /; test@ applies only where the
-- test, under the match's bindings, evaluates to @True@, and where it does
-- not, the next match is tried. Shared by the evaluator's rule tables and
-- the @Replace@ family.
matchRule :: (Kernel :> es) => Expr -> Expr -> Expr -> MatchT es Expr
matchRule lhs body e = do
  sigma <- match (viewPattern lhs) e mempty
  case body of
    App (Sym c) xs
      | c == sCondition,
        [rhs, test] <- V.toList xs ->
          liftMatch (evaluate (applySubst sigma test)) >>= \case
            Sym t | t == sTrue -> pure (applySubst sigma rhs)
            _ -> empty
    _ -> pure (applySubst sigma body)

-- | The first match, if there is one.
matchOne :: (Kernel :> es) => Expr -> Expr -> Eff es (Maybe Subst)
matchOne p s = observeFirst (match (viewPattern p) s mempty)

-- | Every match, in order.
matchAll :: (Kernel :> es) => Expr -> Expr -> Eff es [Subst]
matchAll p s = observeAll (match (viewPattern p) s mempty)

-- | 'matchRule', and then, under a @Flat@ head, the rule applied to a run of
-- the arguments, the rest kept around the replacement: with @f@ @Flat@,
-- @f[b, c] -> x@ turns @f[a, b, c, d]@ into @f[a, x, d]@, and if @f@ is
-- @Orderless@ too the run may be any sub-multiset (§4.5.3). The rule
-- @f[ps] -> r@ is matched as @f[pre___, ps, post___] -> f[pre, r, post]@,
-- or @f[ps, rest___] -> f[r, rest]@, with variables no user pattern can
-- name. Rule application uses it, in the evaluator and in @Replace@; a
-- match of the whole is always tried first.
matchRuleOrRun :: (Kernel :> es) => Expr -> Expr -> Expr -> MatchT es Expr
matchRuleOrRun lhs body e = case (unholdPattern lhs, e) of
  -- Checked before the alternative is built: most subjects cannot take a
  -- run, and the evaluator asks on every rule it tries.
  (App (Sym g) ps, App hd@(Sym f) as) | g == f, V.length as > 1 -> matchRule lhs body e <|> run hd ps
  _ -> matchRule lhs body e
  where
    run hd ps = do
      attrs <- liftMatch (headAttributes hd)
      guard (isFlat attrs)
      let (before, after)
            | isOrderless attrs = ([], [runVariable "rest"])
            | otherwise = ([runVariable "pre"], [runVariable "post"])
          around x = mkApp hd (V.fromList (map runName before <> [x] <> map runName after))
          lhs' = mkApp hd (V.fromList (before <> V.toList ps <> after))
          body' = case body of
            App (Sym c) xs | c == sCondition, [x, test] <- V.toList xs -> apply sCondition [around x, test]
            _ -> around body
      matchRule lhs' body' e
    runName = \case
      App _ xs | Just x <- V.headM xs -> x
      x -> x

-- | A sequence variable in a private context, which no user pattern names.
runVariable :: Text -> Expr
runVariable n = apply sPattern [Sym (symbol "Cassini`Private`" n), apply sBlankNullSequence []]
