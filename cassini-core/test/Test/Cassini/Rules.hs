{-# LANGUAGE PatternSynonyms #-}

-- | "Cassini.Rules": table order and the ladder (DESIGN.md §4.2, §7.3).
module Test.Cassini.Rules (tests) where

import Cassini.Builtins (install)
import Cassini.Builtins.Define (Definition (..), down, up)
import Cassini.Core.Expr (Expr, apply, mkString, pattern App, pattern Int_, pattern Sym)
import Cassini.Core.Symbol (globalSymbol, sCondition, sHoldPattern)
import Cassini.Eval.Kernel (KernelState)
import Cassini.Pattern (unholdPattern)
import Cassini.Rules
import Data.List (findIndex)
import Test.Gen (fn, genExpr, genPattern)
import Test.Kernel (eval, evalStd, ff, parse, std)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (Gen, chooseInt, counterexample, elements, forAll, listOf, oneof, testProperty, vectorOf, (===), (==>))

tests :: TestTree
tests =
  testGroup
    "Rules"
    [ testProperty "insertRule keeps the table sorted by specificity, insertion order breaking ties" $
        forAll genLhss $ \lhss ->
          let table = foldl' (\t (i, l) -> insertRule (mkRule User l (Immediate (Int_ i))) t) emptyTable (zip [0 ..] lhss)
              entries = [(r.ruleSpecificity, tag r.ruleBody) | r <- ruleSetToList table]
           in counterexample (show entries) $
                and (zipWith (\(s, i) (s', j) -> s < s' || (s == s' && i < j)) entries (drop 1 entries)),
      testProperty "inserting and removing rules agrees with a list kept in table order" $
        forAll genLhss $ \lhss ->
          not (null lhss) ==> forAll (listOf (genOp lhss)) $ \ops ->
            let table = foldl' (\t op -> either (\l -> snd (removeRule l t)) (`insertRule` t) op) emptyTable ops
                model = foldl' (flip (either modelRemove modelInsert)) [] ops
                entries rs = [(r.ruleLhs, show @Text r.ruleBody) | r <- rs]
             in entries (ruleSetToList table) === entries model,
      testProperty "the lower rungs read SubValues exactly for h[…][…]" $
        forAll (genExpr 6) $ \e ->
          let k = if curried e then SubValue else DownValue
           in ladder e === [(UpValue, User), (UpValue, Builtin), (k, User), (k, Builtin)],
      testGroup "evaluation walks the rungs in ladder order" rungOrder,
      testCase "a more specific user rule is tried first, whatever the definition order" $
        evalStd
          [ "SetDelayed[f[Pattern[x, Blank[]]], \"general\"]",
            "SetDelayed[f[1], \"specific\"]",
            "List[f[1], f[2]]"
          ]
          @?= "List[\"specific\", \"general\"]",
      testCase "redefining a rule replaces it" $
        evalStd ["Set[f[1], 1]", "Set[f[1], 2]", "f[1]"] @?= "2"
    ]
  where
    curried = \case
      App (App _ _) _ -> True
      _ -> False
    emptyTable = rulesOf DownValue emptyInfo
    tag = \case
      Immediate (Int_ i) -> i
      _ -> -1

-- | An insertion or a removal on one of the left-hand sides, sometimes
-- wrapped in @HoldPattern@, which neither sees; a body sometimes carries a
-- condition, which an insertion compares.
genOp :: [Expr] -> Gen (Either Expr Rule)
genOp lhss = do
  l <- elements lhss
  l' <- elements [l, apply sHoldPattern [l]]
  i <- chooseInt (0, 3)
  c <- elements [Nothing, Just (fn "p" []), Just (fn "q" [])]
  let body = maybe (Int_ (toInteger i)) (\t -> apply sCondition [Int_ (toInteger i), t]) c
  oneof [pure (Left l'), pure (Right (mkRule User l' (Delayed body)))]

-- | The table as a list, maintained as it was before the index: a rule
-- replaces a user rule with its left-hand side and condition in place, or
-- goes after every rule at least as specific; a removal drops every user
-- rule with the left-hand side.
modelInsert :: Rule -> [Rule] -> [Rule]
modelInsert r rs = case findIndex same rs of
  Just i -> take i rs <> [r] <> drop (i + 1) rs
  Nothing -> let (before, after) = span (\x -> x.ruleSpecificity <= r.ruleSpecificity) rs in before <> [r] <> after
  where
    same x = unholdPattern x.ruleLhs == unholdPattern r.ruleLhs && condition x.ruleBody == condition r.ruleBody
    condition = \case
      Delayed (App (Sym c) cs) | c == sCondition, [_, t] <- toList cs -> Just t
      _ -> Nothing

modelRemove :: Expr -> [Rule] -> [Rule]
modelRemove l = filter (\x -> unholdPattern x.ruleLhs /= unholdPattern l)

-- | Distinct left-hand sides @f[…]@, most with blanks.
genLhss :: Gen [Expr]
genLhss = do
  k <- chooseInt (0, 8)
  ls <- vectorOf k (genExpr 4 >>= \e -> genPattern (fn "f" [e]))
  pure (nubBy' ls)
  where
    nubBy' = foldr (\l acc -> l : filter (/= l) acc) []

-- | One rule on each rung for @f[g[]]@, each answering its rung's name:
-- upvalues on @g@, downvalues on @f@. Leaving out the winner exposes the
-- next rung.
rungOrder :: [TestTree]
rungOrder =
  [ testCase "user upvalue first" $ answer [UserUp, BuiltinUp, UserDown, BuiltinDown] @?= "\"user up\"",
    testCase "then built-in upvalue" $ answer [BuiltinUp, UserDown, BuiltinDown] @?= "\"builtin up\"",
    testCase "then user downvalue: built-in upvalues beat user downvalues" $ answer [UserDown, BuiltinDown] @?= "\"user down\"",
    testCase "then built-in downvalue" $ answer [BuiltinDown] @?= "\"builtin down\""
  ]
  where
    answer rs = ff (fst (eval (foldl' (flip define) std rs) (fn "f" [apply g []])))
    g = globalSymbol "g"
    define :: Rung -> KernelState -> KernelState
    define = \case
      UserUp -> \st -> snd (eval st (parse "UpSetDelayed[f[g[]], \"user up\"]"))
      UserDown -> \st -> snd (eval st (parse "SetDelayed[f[Pattern[y, Blank[]]], \"user down\"]"))
      BuiltinUp -> install [Definition g [] [up (\_ -> pure (Just (mkString "builtin up")))]]
      BuiltinDown -> install [Definition (globalSymbol "f") [] [down (\_ -> pure (Just (mkString "builtin down")))]]

data Rung = UserUp | BuiltinUp | UserDown | BuiltinDown
