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
    bindName,
    isTrue,
    argRange,
    prefersLong,
    builtinDefault,
    MatchOps (..),
  )
where

import Cassini.Attributes (AttributeSet)
import Cassini.Core.Expr (Expr, apply, pattern App, pattern Int_, pattern Sym)
import Cassini.Core.Symbol
  ( Symbol,
    sAlternatives,
    sBlank,
    sBlankNullSequence,
    sBlankSequence,
    sCondition,
    sDirectedInfinity,
    sExcept,
    sHoldPattern,
    sList,
    sOptional,
    sPattern,
    sPatternTest,
    sPlus,
    sPower,
    sRepeated,
    sRepeatedNull,
    sSequence,
    sTimes,
    sTrue,
    sVerbatim,
  )
import Cassini.Structure (substituteAll)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V

-- | A pattern, read. The sequence objects (@__@, @___@, @Repeated@,
-- @Optional@) take a run of arguments, so only "Cassini.Pattern.Sequence"
-- and "Cassini.Pattern.Commutative" match them; alone they match nothing.
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
    | h == sRepeated, [p, n] <- V.toList as, Just r <- repeatSpec 1 n -> PRepeated (viewPattern p) r
    | h == sRepeatedNull, [p] <- V.toList as -> PRepeated (viewPattern p) (0, Nothing)
    | h == sRepeatedNull, [p, n] <- V.toList as, Just r <- repeatSpec 0 n -> PRepeated (viewPattern p) r
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

-- | A repetition count: @n@ is at most @n@ (from the given least), @{n}@
-- exactly @n@, @{m, n}@ from @m@ to @n@, where @n@ may be @Infinity@.
repeatSpec :: Int -> Expr -> Maybe (Int, Maybe Int)
repeatSpec lo = \case
  App (Sym l) ns | l == sList -> case V.toList ns of
    [n] -> count n >>= \k -> pure (k, Just k)
    [m, n] -> (,) <$> count m <*> bound n
    _ -> Nothing
  n -> (lo,) . Just <$> count n
  where
    count = \case
      Int_ k | k >= 0 -> toIntegralSized k
      _ -> Nothing
    bound = \case
      App (Sym d) xs | d == sDirectedInfinity, [Int_ 1] <- V.toList xs -> Just Nothing
      n -> Just <$> count n

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

-- | Bind a name, or check it against its binding: one name means one value
-- across a pattern.
bindName :: (MonadPlus m) => Symbol -> Binding -> Subst -> m Subst
bindName x b sigma = case Map.lookup x sigma of
  Nothing -> pure (Map.insert x b sigma)
  Just b' -> sigma <$ guard (b' == b)

-- | Whether a side condition's value admits a match: only @True@ does
-- (§4.13).
isTrue :: Expr -> Bool
isTrue = \case
  Sym t -> t == sTrue
  _ -> False

-- | How many arguments an element of a pattern's argument list takes: at
-- least, and at most ('Nothing' is unbounded). Under a @Flat@ head (the
-- flag), a blank takes a run of one or more, as the head's arguments
-- grouped (§4.5.3). @Optional@ takes at most one, whatever it wraps.
argRange :: Bool -> PatternView -> (Int, Maybe Int)
argRange flat = go
  where
    go = \case
      PBlank _ | flat -> (1, Nothing)
      PBlankSeq _ -> (1, Nothing)
      PBlankNull _ -> (0, Nothing)
      PNamed _ q -> go q
      PCondition q _ -> go q
      PTest q _ -> go q
      PHold q -> go q
      PExcept _ (Just q) -> go q
      PAlternative (q : qs) -> foldl' widen (go q) (map go qs)
      PRepeated _ r -> r
      POptional _ _ -> (0, Just 1)
      _ -> (1, Just 1)
    widen (a, b) (c, d) = (min a c, max <$> b <*> d)

-- | Whether an element tries its longer runs first. @Optional@ does: it
-- matches an argument when there is one, and only otherwise its default.
-- Everything else tries the shortest run first, as WL's @__@ does.
prefersLong :: PatternView -> Bool
prefersLong = \case
  PNamed _ q -> prefersLong q
  PCondition q _ -> prefersLong q
  PTest q _ -> prefersLong q
  PHold q -> prefersLong q
  POptional _ _ -> True
  _ -> False

-- | The built-in default of an argument of a head, for @Optional[p]@ with
-- no default of its own: the 1-based position and the number of pattern
-- arguments. @Plus@'s is 0, @Times@'s 1, and @Power@'s exponent 1. User
-- defaults (@Default[f] = v@) are not implemented.
builtinDefault :: Symbol -> Int -> Int -> Maybe Expr
builtinDefault f i n
  | f == sPlus = Just (Int_ 0)
  | f == sTimes = Just (Int_ 1)
  | f == sPower, i == 2, n == 2 = Just (Int_ 1)
  | otherwise = Nothing

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
    matchesM :: PatternView -> Expr -> Subst -> m Bool,
    -- | The attributes of a subject's head: a symbol's own, none for a
    -- compound head. @Orderless@, @Flat@ and @OneIdentity@ change matching.
    attributesM :: Expr -> m AttributeSet
  }
