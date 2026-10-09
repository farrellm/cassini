{-# LANGUAGE PatternSynonyms #-}

-- | "Cassini.Rules": table order and the ladder (DESIGN.md §4.2, §7.3).
module Test.Cassini.Rules (tests) where

import Cassini.Builtins (install)
import Cassini.Builtins.Define (Definition (..), down, up)
import Cassini.Core.Expr (Expr, apply, mkString, pattern App, pattern Int_)
import Cassini.Core.Symbol (globalSymbol)
import Cassini.Eval.Kernel (KernelState)
import Cassini.Rules
import Test.Gen (fn, genExpr, genPattern)
import Test.Kernel (eval, evalStd, ff, parse, std)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (Gen, chooseInt, counterexample, forAll, testProperty, vectorOf, (===))

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
