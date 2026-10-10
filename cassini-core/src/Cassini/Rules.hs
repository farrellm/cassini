{-# LANGUAGE PatternSynonyms #-}

-- | Rules, the four rule tables and the ladder (DESIGN.md §4.2).
--
-- Four tables, one per 'ValueKind', keyed by symbol. Rule application is a
-- four-rung ladder, not two sort keys: user upvalues, built-in upvalues, user
-- downvalues (or subvalues), built-in downvalues (or subvalues). Specificity
-- orders rules within a rung, never across, and 'ladder' is the only list the
-- evaluator may walk.
module Cassini.Rules
  ( -- * Rules
    Rule (..),
    RuleBody (..),
    BuiltinId (..),
    Specificity,
    specificity,
    mkRule,

    -- * Tables
    ValueKind (..),
    Origin (..),
    RuleSet,
    ruleSetToList,
    insertRule,
    removeRule,
    SymbolInfo (..),
    Values,
    emptyInfo,
    hasRules,
    rulesOf,
    modifyRules,

    -- * The ladder
    ladder,
    applicableRules,
  )
where

import Cassini.Attributes (AttributeSet, isFlat, isOrderless)
import Cassini.Core.Expr (Expr, pattern App, pattern Sym)
import Cassini.Core.Symbol (sBlank, sBlankNullSequence, sBlankSequence, sCondition, sHoldPattern, sPattern)
import Cassini.Pattern (isPatternFree, unholdPattern)
import Cassini.Pattern.Net qualified as Net
import Data.Sequence qualified as Seq
import Data.Vector qualified as V
import Text.Show (Show (showsPrec))

-- | A rule: a pattern, what it rewrites to, where it ranks, and which rung of
-- the ladder it is on.
data Rule = Rule
  { -- | The pattern.
    ruleLhs :: !Expr,
    ruleBody :: !RuleBody,
    ruleSpecificity :: !Specificity,
    -- | Which rung of the ladder the rule is on.
    ruleOrigin :: !Origin
  }
  deriving stock (Show)

-- | What a rule rewrites to.
data RuleBody
  = -- | From @=@ (@Set@): the right-hand side, evaluated once, at definition.
    Immediate !Expr
  | -- | From @:=@ (@SetDelayed@): the right-hand side, evaluated per
    -- application.
    Delayed !Expr
  | -- | A Haskell implementation, on the 'Builtin' origin only. An id, not a
    -- function, because a function would mention the kernel effect, whose
    -- module imports this one; the kernel state resolves it (§4.3).
    Native !BuiltinId
  deriving stock (Show)

-- | Names a builtin implementation held in the kernel state.
newtype BuiltinId = BuiltinId Int
  deriving newtype (Eq, Ord, Show)

-- | A coarse structural measure: fewer blanks first, then more literal
-- structure first. Not WL's exact behaviour; where it cannot decide,
-- definition order does (§4.2).
newtype Specificity = Specificity (Int, Int)
  deriving newtype (Eq, Ord, Show)

-- | The specificity of a left-hand side. A sequence blank counts as more
-- general than a single one, and a blank's head constraint and a condition
-- each as one more literal node, so @f[x_Integer]@ precedes @f[x_]@.
-- @HoldPattern@ counts as nothing: it only stops evaluation.
specificity :: Expr -> Specificity
specificity e = let (b, l) = go e in Specificity (b, negate l)
  where
    go :: Expr -> (Int, Int)
    go u
      | isPatternFree u = (0, size u)
    go u = case u of
      App (Sym h) as
        | h == sPattern, [_, p] <- V.toList as -> go p
        | h == sHoldPattern, [p] <- V.toList as -> go p
        | h == sBlank -> (1, constrained as)
        | h == sBlankSequence -> (2, constrained as)
        | h == sBlankNullSequence -> (3, constrained as)
        | h == sCondition, [p, _] <- V.toList as -> second (+ 1) (go p)
      App h as -> foldl' add (second (+ 1) (go h)) (V.map go as)
      _ -> (0, 1)
    add (a, b) (c, d) = (a + c, b + d)
    constrained as = min 1 (V.length as)
    size = \case
      App h as -> 1 + size h + sum (V.map size as)
      _ -> 1 :: Int

-- | A rule with its specificity computed.
mkRule :: Origin -> Expr -> RuleBody -> Rule
mkRule o lhs body = Rule {ruleLhs = lhs, ruleBody = body, ruleSpecificity = specificity lhs, ruleOrigin = o}

-- | The four tables. They have no order of their own: 'ladder' is the only
-- order in which steps 10–13 visit them.
data ValueKind = OwnValue | DownValue | UpValue | SubValue
  deriving stock (Eq, Show)

-- | Whose rule it is.
data Origin = User | Builtin
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | One table's rules, ordered: first applicable wins, with their index
-- (§4.5.5). The index is lazy, so a table is indexed when it is first
-- looked up after a change, never on a change itself.
data RuleSet = RuleSet !(Seq Rule) (Net.RuleIndex Rule)

instance Show RuleSet where
  showsPrec d (RuleSet rs _) = showsPrec d rs

-- | A table of these rules, in this order.
ruleSet :: Seq Rule -> RuleSet
ruleSet rs = RuleSet rs (Net.fromSeq (.ruleLhs) rs)

-- | The rules, in table order.
ruleSetToList :: RuleSet -> [Rule]
ruleSetToList (RuleSet rs _) = toList rs

-- | Insert by specificity, after every rule at least as specific, so
-- definition order breaks ties. A user rule with an equal left-hand side and
-- an equal right-hand-side condition is replaced in place, as redefinition
-- does in WL; @f[x_] := a /; p[x]@ and @f[x_] := b /; q[x]@ are two rules.
-- Left-hand sides are compared through @HoldPattern@, so @f[2] = a@ and
-- @HoldPattern[f[2]] = b@ are one rule.
-- Built-in rules are never replaced: their left-hand sides only record where
-- they live.
insertRule :: Rule -> RuleSet -> RuleSet
insertRule r (RuleSet rs _) = case Seq.findIndexL same rs of
  Just i -> ruleSet (Seq.update i r rs)
  Nothing ->
    let (before, after) = Seq.spanl (\x -> x.ruleSpecificity <= r.ruleSpecificity) rs
     in ruleSet (before <> (r Seq.<| after))
  where
    same x =
      r.ruleOrigin == User
        && x.ruleOrigin == User
        && sameLhs x.ruleLhs r.ruleLhs
        && bodyCondition x.ruleBody == bodyCondition r.ruleBody

-- | The test of a right-hand side @rhs /; test@, if it has one.
bodyCondition :: RuleBody -> Maybe Expr
bodyCondition = \case
  Immediate b -> condition b
  Delayed b -> condition b
  Native _ -> Nothing
  where
    condition = \case
      App (Sym c) as | c == sCondition, [_, t] <- V.toList as -> Just t
      _ -> Nothing

-- | Remove every user rule with this left-hand side, if there is one.
-- Unlike 'insertRule', this ignores right-hand-side conditions: @Unset@
-- names a left-hand side only, so it removes all the conditional rules on it.
removeRule :: Expr -> RuleSet -> (Bool, RuleSet)
removeRule lhs (RuleSet rs _) =
  let rs' = Seq.filter (\x -> not (x.ruleOrigin == User && sameLhs x.ruleLhs lhs)) rs
   in (Seq.length rs' /= Seq.length rs, ruleSet rs')

-- | Whether two left-hand sides are one, seen through @HoldPattern@.
sameLhs :: Expr -> Expr -> Bool
sameLhs a b = unholdPattern a == unholdPattern b

-- | A symbol's four tables. A record, not a map keyed by 'ValueKind', so
-- that there is no key order to walk by mistake: a map's order would put
-- downvalues before upvalues, the inversion steps 11–12 forbid (§4.2).
data Values = Values
  { ownValues :: !RuleSet,
    downValues :: !RuleSet,
    upValues :: !RuleSet,
    subValues :: !RuleSet
  }
  deriving stock (Show)

-- | What the kernel knows about one symbol.
data SymbolInfo = SymbolInfo
  { siAttributes :: !AttributeSet,
    siValues :: !Values
  }
  deriving stock (Show)

-- | A symbol with no attributes and no rules.
emptyInfo :: SymbolInfo
emptyInfo = SymbolInfo mempty (Values none none none none)
  where
    none = ruleSet Seq.empty

-- | One table.
rulesOf :: ValueKind -> SymbolInfo -> RuleSet
rulesOf k si = case k of
  OwnValue -> si.siValues.ownValues
  DownValue -> si.siValues.downValues
  UpValue -> si.siValues.upValues
  SubValue -> si.siValues.subValues

-- | Change one table.
modifyRules :: ValueKind -> (RuleSet -> RuleSet) -> SymbolInfo -> SymbolInfo
modifyRules k f si = si {siValues = set si.siValues}
  where
    set vs = case k of
      OwnValue -> vs {ownValues = f vs.ownValues}
      DownValue -> vs {downValues = f vs.downValues}
      UpValue -> vs {upValues = f vs.upValues}
      SubValue -> vs {subValues = f vs.subValues}

-- | Whether the symbol has any rule, in any table.
hasRules :: SymbolInfo -> Bool
hasRules si = any (\k -> not (null (ruleSetToList (rulesOf k si)))) [OwnValue, DownValue, UpValue, SubValue]

-- | Steps 10–13 (§4.4), in order. The lower rungs read @SubValues@ for
-- @h[…][…]@ and @DownValues@ otherwise, never both, which is why the ladder
-- takes the expression.
ladder :: Expr -> [(ValueKind, Origin)]
ladder e = [(UpValue, User), (UpValue, Builtin), (down, User), (down, Builtin)]
  where
    down = case e of
      App (App _ _) _ -> SubValue
      _ -> DownValue

-- | The candidate rules of one rung, in table order. Specificity has ordered
-- them within the table; the origin selects the rung. A lazy list, so the
-- caller, which stops at the first rule that fires, filters no further.
-- Downvalues come through the index, keyed on the first argument's head,
-- unless the symbol is @Orderless@ or @Flat@, where any argument may match
-- the first pattern (§4.5.5).
applicableRules :: SymbolInfo -> (ValueKind, Origin) -> Expr -> [Rule]
applicableRules si (k, o) e =
  let RuleSet rs ix = rulesOf k si
      indexed = k == DownValue && not (isOrderless si.siAttributes || isFlat si.siAttributes)
   in filter (\r -> r.ruleOrigin == o) (if indexed then Net.candidates ix e else toList rs)
