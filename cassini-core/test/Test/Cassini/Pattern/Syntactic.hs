-- | "Cassini.Pattern.Syntactic", through "Cassini.Pattern.Match": unit cases
-- for each pattern object. §7.3's matcher laws are "Test.Cassini.Pattern".
module Test.Cassini.Pattern.Syntactic (tests) where

import Cassini.Core.Expr (Expr)
import Cassini.Pattern (Subst)
import Cassini.Pattern.Match (matchAll)
import Test.Kernel (evalStd, parse, run, std)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
  testGroup
    "Pattern.Syntactic"
    [ testGroup
        "pattern objects"
        [ testCase "a blank matches anything" $ matches "Blank[]" "f[x]" @?= 1,
          testCase "a head constraint" $ (matches "Blank[Integer]" "3", matches "Blank[Integer]" "x") @?= (1, 0),
          testCase "a repeated name means one value" $
            (matches "f[Pattern[x, Blank[]], Pattern[x, Blank[]]]" "f[1, 1]", matches "f[Pattern[x, Blank[]], Pattern[x, Blank[]]]" "f[1, 2]") @?= (1, 0),
          testCase "a literal matches only itself" $ (matches "f[a]" "f[a]", matches "f[a]" "f[b]") @?= (1, 0),
          testCase "arities must agree when no argument takes a run" $ matches "f[Blank[]]" "f[a, b]" @?= 0,
          testCase "alternatives enumerate every branch" $
            matches "Alternatives[Pattern[x, Blank[]], Pattern[y, Blank[]]]" "a" @?= 2,
          testCase "a condition admits only True" $
            ( evalStd ["Set[isOne[1], True]", "SetDelayed[f[Condition[Pattern[x, Blank[]], isOne[x]]], \"one\"]", "List[f[1], f[2]]"],
              matches "Condition[Pattern[x, Blank[]], True]" "a",
              matches "Condition[Pattern[x, Blank[]], x]" "a"
            )
              @?= ("List[\"one\", f[2]]", 1, 0),
          testCase "a pattern test applies its function" $
            evalStd ["SetDelayed[t[Blank[]], True]", "SetDelayed[f[PatternTest[Pattern[x, Blank[]], t]], \"yes\"]", "f[1]"] @?= "\"yes\"",
          testCase "except" $
            (matches "Except[a]" "b", matches "Except[a]" "a", matches "Except[a, Blank[Integer]]" "2", matches "Except[2, Blank[Integer]]" "2") @?= (1, 0, 1, 0),
          testCase "HoldPattern matches as its argument does" $ matches "HoldPattern[f[Blank[], Blank[]]]" "f[a, b]" @?= 1,
          testCase "Verbatim matches blanks literally" $
            (matches "Verbatim[Blank[]]" "Blank[]", matches "Verbatim[Blank[]]" "a") @?= (1, 0),
          testCase "a curried pattern" $ matches "Pattern[h, Blank[]][Pattern[x, Blank[]]]" "f[1][2]" @?= 1
        ]
    ]
  where
    matches p s = length (matchesOf (parse p) (parse s))

matchesOf :: Expr -> Expr -> [Subst]
matchesOf p s = fromRight [] (fst (run std (matchAll p s)))
