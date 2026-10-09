{-# LANGUAGE PatternSynonyms #-}

-- | The pattern language as a view over 'Expr', and substitutions
-- (DESIGN.md §4.5.1).
--
-- Patterns are expressions, as in WL: @Blank[]@ is a symbol applied to
-- nothing. 'viewPattern' reads one into a 'PatternView' for the matchers.
--
-- The matchers are written by open recursion over 'MatchOps', which
-- "Cassini.Pattern.Match" ties to 'Cassini.Pattern.Match.MatchT'. So no matcher
-- imports the monad, and the monad's module imports every matcher, without a
-- cycle (§4.5.2).
module Cassini.Pattern
  ( PatternView (..),
    viewPattern,
    isPatternFree,
    unholdPattern,
    Binding (..),
    Subst,
    bindingExpr,
    applySubst,
    MatchOps (..),
  )
where

import Cassini.Core.Expr (Expr, apply, pattern App, pattern Sym)
import Cassini.Core.Symbol
  ( Symbol,
    sAlternatives,
    sBlank,
    sBlankNullSequence,
    sBlankSequence,
    sCondition,
    sExcept,
    sHoldPattern,
    sOptional,
    sPattern,
    sPatternTest,
    sRepeated,
    sRepeatedNull,
    sSequence,
    sVerbatim,
  )
import Cassini.Structure (substituteAll)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V

-- | A pattern, read. Constructors the syntactic matcher does not handle
-- (sequences, @Repeated@, @Optional@) arrive with milestone 1b.
data PatternView
  = -- | @_h@
    PBlank !(Maybe Expr)
  | -- | @__h@, one or more
    PBlankSeq !(Maybe Expr)
  | -- | @___h@, zero or more
    PBlankNull !(Maybe Expr)
  | -- | @x:patt@, @x_@
    PNamed !Symbol !PatternView
  | -- | @patt /; test@
    PCondition !PatternView !Expr
  | -- | @patt ? f@
    PTest !PatternView !Expr
  | -- | @p | q@
    PAlternative ![PatternView]
  | -- | @Repeated[p, {min, max}]@; 'Nothing' is unbounded
    PRepeated !PatternView !(Int, Maybe Int)
  | -- | @Optional[p, default]@
    POptional !PatternView !(Maybe Expr)
  | -- | an expression with no pattern object in it
    PLiteral !Expr
  | -- | a head and arguments, at least one of them a pattern
    PCompound !PatternView !(V.Vector PatternView)
  | -- | @Except[c]@, @Except[c, p]@
    PExcept !PatternView !(Maybe PatternView)
  | -- | @HoldPattern[p]@
    PHold !PatternView
  | -- | @Verbatim[e]@: @e@ literally, blanks too
    PVerbatim !Expr
  deriving stock (Show)

-- | Read a pattern. A subexpression with no pattern object is a 'PLiteral',
-- matched by equality.
viewPattern :: Expr -> PatternView
viewPattern e = case e of
  App (Sym h) as
    | h == sBlank, Just c <- constraint as -> PBlank c
    | h == sBlankSequence, Just c <- constraint as -> PBlankSeq c
    | h == sBlankNullSequence, Just c <- constraint as -> PBlankNull c
    | h == sPattern, [Sym x, p] <- V.toList as -> PNamed x (viewPattern p)
    | h == sCondition, [p, t] <- V.toList as -> PCondition (viewPattern p) t
    | h == sPatternTest, [p, f] <- V.toList as -> PTest (viewPattern p) f
    | h == sAlternatives -> PAlternative (map viewPattern (V.toList as))
    | h == sRepeated, [p] <- V.toList as -> PRepeated (viewPattern p) (1, Nothing)
    | h == sRepeatedNull, [p] <- V.toList as -> PRepeated (viewPattern p) (0, Nothing)
    | h == sOptional, [p] <- V.toList as -> POptional (viewPattern p) Nothing
    | h == sOptional, [p, d] <- V.toList as -> POptional (viewPattern p) (Just d)
    | h == sExcept, [c] <- V.toList as -> PExcept (viewPattern c) Nothing
    | h == sExcept, [c, p] <- V.toList as -> PExcept (viewPattern c) (Just (viewPattern p))
    | h == sHoldPattern, [p] <- V.toList as -> PHold (viewPattern p)
    | h == sVerbatim, [x] <- V.toList as -> PVerbatim x
  App h as
    | isPatternFree e -> PLiteral e
    | otherwise -> PCompound (viewPattern h) (V.map viewPattern as)
  _ -> PLiteral e
  where
    constraint as = case V.toList as of
      [] -> Just Nothing
      [c] -> Just (Just c)
      _ -> Nothing

-- | Whether the expression contains no pattern object, heads included. Such a
-- pattern matches only itself, which is the fast path of @FreeQ@ and
-- @ReplaceAll@ (§3.7).
isPatternFree :: Expr -> Bool
isPatternFree = \case
  App (Sym h) as | isPatternHead h (V.length as) -> False
  App h as -> isPatternFree h && all isPatternFree as
  _ -> True
  where
    isPatternHead h n =
      h `elem` [sBlank, sBlankSequence, sBlankNullSequence, sAlternatives, sRepeated, sRepeatedNull, sOptional, sExcept, sHoldPattern, sVerbatim]
        || (h `elem` [sPattern, sCondition, sPatternTest] && n == 2)

-- | A pattern seen through any @HoldPattern@ wrapping it whole. @HoldPattern@
-- only stops evaluation, so @HoldPattern[f[x_]]@ and @f[x_]@ are one
-- left-hand side to the matcher, to rule identity and to specificity.
unholdPattern :: Expr -> Expr
unholdPattern = \case
  App (Sym h) as | h == sHoldPattern, [x] <- V.toList as -> unholdPattern x
  e -> e

-- | What a pattern variable is bound to: one expression, or a run of
-- arguments for a sequence variable.
data Binding
  = BOne !Expr
  | BSeq !(V.Vector Expr)
  deriving stock (Eq, Show)

-- | A substitution: pattern variables to their bindings. All matcher state
-- lives here, never in an effect, so a failed branch is abandoned by dropping
-- a value (§4.5.2).
type Subst = Map Symbol Binding

-- | The binding as one expression: a sequence becomes @Sequence[…]@, which
-- step 5 splices wherever it lands in an argument list.
bindingExpr :: Binding -> Expr
bindingExpr = \case
  BOne x -> x
  BSeq xs -> apply sSequence (V.toList xs)

-- | Replace every bound variable by its binding, all at once. Not yet aware of
-- scoping constructs; that arrives with @Function@ (§4.13).
applySubst :: Subst -> Expr -> Expr
applySubst s u
  | Map.null s = u
  | otherwise = substituteAll u [(Sym x, bindingExpr b) | (x, b) <- Map.toList s]

-- | What a matcher needs from the monad it runs in. "Cassini.Pattern.Match"
-- supplies these for 'Cassini.Pattern.Match.MatchT'; the matchers are
-- polymorphic in @m@, so they never see @logict@ (§2.6, rule 6).
data MatchOps m = MatchOps
  { -- | Match a subpattern: the knot, so each matcher can hand any
    -- subpattern back to the dispatcher.
    recur :: PatternView -> Expr -> Subst -> m Subst,
    -- | Evaluate an expression, for side conditions (§4.5.2).
    evalM :: Expr -> m Expr,
    -- | Whether a pattern matches at all, committing to nothing: for
    -- @Except@, whose bindings do not escape.
    matchesM :: PatternView -> Expr -> Subst -> m Bool
  }
