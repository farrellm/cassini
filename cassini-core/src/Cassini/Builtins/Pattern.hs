{-# LANGUAGE PatternSynonyms #-}

-- | @MatchQ@, @Cases@, @Replace@, @ReplaceAll@, @ReplaceRepeated@ and
-- @ReplaceList@ (DESIGN.md §2.2, §4.5): the language's own access to the
-- matcher.
--
-- A replacement is a @Rule@ or @RuleDelayed@, a list of them, or a list of
-- such lists, which gives a list of results, one per list. A rule applies
-- through 'matchRule', as a user definition does, so @lhs :> rhs /; test@
-- tries the next match where the test fails. Results are not evaluated here:
-- the evaluator takes a builtin's result round again (§4.4), which is also
-- what leaves a replacement inside @Hold@ unevaluated.
--
-- In @ReplaceAll@ and @ReplaceRepeated@, a rule for a @Flat@ head also
-- applies to a run of its arguments ('matchRuleOrRun', §4.5.3); in
-- @Replace@, it must match the whole.
module Cassini.Builtins.Pattern (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Bound (..), Definition, args, define, down, firstJustM, inLevel, levelSpec, message, sFalseE, sTrueE, sub)
import Cassini.Core.Expr (Expr, apply, exprArgs, mkApp, pattern App, pattern Int_, pattern Sym)
import Cassini.Core.Symbol (sList, sRule, sRuleDelayed)
import Cassini.Eval.Kernel (Kernel)
import Cassini.Pattern (viewPattern)
import Cassini.Pattern.Match (match, matchRule, matchRuleOrRun, observeAll, observeFirst)
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | The pattern builtins, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "MatchQ" [Protected] [down matchQRule, sub (pure . operatorForm)],
    define "Cases" [Protected] [down casesRule, sub (pure . operatorForm)],
    define "Replace" [Protected] [down replaceRule, sub (pure . operatorForm)],
    define "ReplaceAll" [Protected] [down replaceAllRule, sub (pure . operatorForm)],
    define "ReplaceRepeated" [Protected] [down replaceRepeatedRule, sub (pure . operatorForm)],
    define "ReplaceList" [Protected] [down replaceListRule, sub (pure . operatorForm)]
  ]

-- | @op[form][expr]@ is @op[expr, form]@: the operator forms take the
-- expression last.
operatorForm :: Expr -> Maybe Expr
operatorForm = \case
  App (App op fs) xs | [f] <- V.toList fs, [x] <- V.toList xs -> Just (mkApp op (V.fromList [x, f]))
  _ -> Nothing

-- | One replacement rule: its left-hand side and its body, which may carry a
-- @/;@ condition.
data Replacement = Replacement !Expr !Expr

-- | The rules a replacement argument holds: one list, or several, each
-- giving its own result.
data Replacements = One ![Replacement] | Several ![[Replacement]]

readRule :: Expr -> Maybe Replacement
readRule = \case
  App (Sym r) xs
    | r == sRule || r == sRuleDelayed,
      [lhs, rhs] <- V.toList xs ->
        Just (Replacement lhs rhs)
  _ -> Nothing

readReplacements :: Expr -> Maybe Replacements
readReplacements e = case e of
  App (Sym l) xs
    | l == sList,
      not (V.null xs),
      all isList xs ->
        Several <$> traverse (traverse readRule . V.toList . exprArgs) (V.toList xs)
    | l == sList -> One <$> traverse readRule (V.toList xs)
  _ -> One . pure <$> readRule e
  where
    isList = \case
      App (Sym l) _ -> l == sList
      _ -> False

-- | Run a replacement over its rules, or emit @symbol::reps@ and stay.
withReplacements :: (Kernel :> es) => Text -> Expr -> ([Replacement] -> Eff es Expr) -> Eff es (Maybe Expr)
withReplacements name rules f = case readReplacements rules of
  Just (One rs) -> Just <$> f rs
  Just (Several rss) -> Just . apply sList <$> traverse f rss
  Nothing -> Nothing <$ message name "reps" [listed]
  where
    listed = case rules of
      App (Sym l) _ | l == sList -> rules
      _ -> apply sList [rules]

-- | The first rule that applies to the whole expression, by its first match.
applyFirst :: (Kernel :> es) => [Replacement] -> Expr -> Eff es (Maybe Expr)
applyFirst rs e = firstJustM (\(Replacement lhs rhs) -> observeFirst (matchRule lhs rhs e)) rs

-- | The first rule that applies, by its first match: to the whole
-- expression or, under a @Flat@ head, to a run of its arguments.
applyWithRuns :: (Kernel :> es) => [Replacement] -> Expr -> Eff es (Maybe Expr)
applyWithRuns rs e = firstJustM (\(Replacement lhs rhs) -> observeFirst (matchRuleOrRun lhs rhs e)) rs

-- | @MatchQ[expr, form]@.
matchQRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
matchQRule e = case args e of
  [x, form] -> Just . bool sFalseE sTrueE . isJust <$> observeFirst (match (viewPattern form) x mempty)
  _ -> pure Nothing

-- | @ReplaceAll[expr, rules]@: top down, the first rule that applies to a
-- subexpression replaces it, and the replacement is not searched again.
-- Heads are searched too.
replaceAllRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
replaceAllRule e = case args e of
  [x, rules] -> withReplacements "ReplaceAll" rules (`go` x)
  _ -> pure Nothing
  where
    go rs x =
      applyWithRuns rs x >>= \case
        Just r -> pure r
        Nothing -> case x of
          App h as -> mkApp <$> go rs h <*> V.mapM (go rs) as
          _ -> pure x

-- | @Replace[expr, rules, levelspec]@: by default the whole expression only;
-- with a level specification, bottom up over the parts at those levels,
-- heads excluded. Unlike @ReplaceAll@, a rule must match a part whole, never
-- a run of a @Flat@ head's arguments: @Replace[a + b + c, a + x_Symbol :> x]@
-- stays (@wolfram/Flat/PossibleIssues/4@).
replaceRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
replaceRule e = case args e of
  [x, rules] -> withReplacements "Replace" rules (\rs -> fromMaybe x <$> applyFirst rs x)
  [x, rules, spec] | Just ls <- levelSpec spec -> withReplacements "Replace" rules (\rs -> rebuildM (inLevel ls) (\y -> fromMaybe y <$> applyFirst rs y) x)
  _ -> pure Nothing

-- | @ReplaceRepeated[expr, rules]@: @ReplaceAll@ until nothing changes. The
-- expression is not evaluated between rounds. After 65536 rounds,
-- @ReplaceRepeated::rrlim@ and the expression as it stands.
replaceRepeatedRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
replaceRepeatedRule e = case args e of
  [x, rules] -> withReplacements "ReplaceRepeated" rules (\rs -> go rs (0 :: Int) x)
  _ -> pure Nothing
  where
    limit = 65536
    go rs k x
      | k >= limit = x <$ message "ReplaceRepeated" "rrlim" [x, Int_ (toInteger limit)]
      | otherwise = do
          x' <- replaceOnce rs x
          if x' == x then pure x else go rs (k + 1) x'
    replaceOnce rs x =
      applyWithRuns rs x >>= \case
        Just r -> pure r
        Nothing -> case x of
          App h as -> mkApp <$> replaceOnce rs h <*> V.mapM (replaceOnce rs) as
          _ -> pure x

-- | @ReplaceList[expr, rules, n]@: every way the rules apply to the whole
-- expression, rule by rule, each rule's in match order; at most @n@.
replaceListRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
replaceListRule e = case args e of
  [x, rules] -> withReplacements "ReplaceList" rules (fmap (apply sList) . every x)
  [x, rules, Int_ n] -> withReplacements "ReplaceList" rules (fmap (apply sList . genericTake n) . every x)
  _ -> pure Nothing
  where
    every x rs = concat <$> traverse (\(Replacement lhs rhs) -> observeAll (matchRule lhs rhs x)) rs

-- | @Cases[expr, form, levelspec, n]@: the parts at the levels given (by
-- default level 1) that match the form, depth first, each before the part
-- containing it, heads excluded. A rule as the form gives its right-hand
-- side for each part its left-hand side matches.
casesRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
casesRule e = case args e of
  [x, form] -> Just <$> cases (Level 1, Level 1) form Nothing x
  [x, form, spec] | Just ls <- levelSpec spec -> Just <$> cases ls form Nothing x
  [x, form, spec, Int_ n] | Just ls <- levelSpec spec -> Just <$> cases ls form (Just n) x
  _ -> pure Nothing
  where
    cases ls form n x = do
      let picked = parts (inLevel ls) x
          pick = case readRule form of
            Just (Replacement lhs rhs) -> matchRule lhs rhs
            Nothing -> \y -> y <$ match (viewPattern form) y mempty
      found <- catMaybes <$> traverse (observeFirst . pick) picked
      pure (apply sList (maybe id genericTake (n :: Maybe Integer) found))

-- | The parts selected by level and depth, depth first, each before the part
-- containing it, heads excluded.
parts :: (Integer -> Integer -> Bool) -> Expr -> [Expr]
parts keep = fst . go 0
  where
    go p x =
      let below = map (go (p + 1)) (V.toList (exprArgs x))
          d = 1 + foldl' (\acc (_, k) -> max acc k) 0 below
       in (concatMap fst below <> [x | keep p d], d)

-- | Rebuild bottom up, applying @f@ to every part the predicate selects by
-- its level and its depth in the original expression.
rebuildM :: (Monad m) => (Integer -> Integer -> Bool) -> (Expr -> m Expr) -> Expr -> m Expr
rebuildM keep f = fmap fst . go 0
  where
    go p x = case x of
      App h as -> do
        below <- V.mapM (go (p + 1)) as
        let d = 1 + V.foldl' (\acc (_, k) -> max acc k) 0 below
            x' = mkApp h (V.map fst below)
        (,d) <$> (if keep p d then f x' else pure x')
      _ -> (,1) <$> (if keep p 1 then f x else pure x)
