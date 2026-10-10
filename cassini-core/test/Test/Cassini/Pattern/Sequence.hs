-- | "Cassini.Pattern.Sequence", through "Cassini.Pattern.Match" and the
-- pattern builtins: run lengths and their order, @Repeated@, @Optional@,
-- and blanks under @Flat@ and @OneIdentity@ heads.
module Test.Cassini.Pattern.Sequence (tests) where

import Test.Kernel (evalStd)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
  testGroup
    "Pattern.Sequence"
    [ testGroup
        "runs"
        [ -- wolfram/ReplaceList/BasicExamples/1
          testCase "sequences try the shortest run first" $
            evalStd ["ReplaceList[List[a, b, c, d], Rule[List[Pattern[x, BlankSequence[]], Pattern[y, BlankSequence[]]], List[List[x], List[y]]]]"]
              @?= "List[List[List[a], List[b, c, d]], List[List[a, b], List[c, d]], List[List[a, b, c], List[d]]]",
          testCase "a null sequence may be empty, a sequence may not" $
            evalStd ["List[MatchQ[f[], f[BlankNullSequence[]]], MatchQ[f[], f[BlankSequence[]]]]"] @?= "List[True, False]",
          testCase "a sequence's head constraint applies to every argument" $
            evalStd ["List[MatchQ[f[1, 2], f[BlankSequence[Integer]]], MatchQ[f[1, a], f[BlankSequence[Integer]]]]"] @?= "List[True, False]",
          testCase "a sequence binding splices into the right-hand side" $
            evalStd ["Replace[f[a, b, c], RuleDelayed[f[Pattern[x, Blank[]], Pattern[y, BlankSequence[]]], g[y, x]]]"] @?= "g[b, c, a]",
          testCase "a repeated sequence name means the same run" $
            evalStd ["List[MatchQ[f[a, b, a, b], f[Pattern[x, BlankSequence[]], Pattern[x, BlankSequence[]]]], MatchQ[f[a, b, b], f[Pattern[x, BlankSequence[]], Pattern[x, BlankSequence[]]]]]"]
              @?= "List[True, False]",
          -- wolfram/ReplaceList/Applications/2
          testCase "neighbouring equal elements, every way" $
            evalStd ["ReplaceList[List[a, b, b, b, c, c, a], Rule[List[BlankNullSequence[], Pattern[x, Blank[]], Pattern[x, Blank[]], BlankNullSequence[]], x]]"]
              @?= "List[b, b, c]",
          testCase "a test on a sequence applies to each argument" $
            evalStd ["SetDelayed[small[Pattern[n, Blank[]]], MatchQ[n, Alternatives[1, 2]]]", "List[MatchQ[f[1, 2], f[PatternTest[BlankSequence[], small]]], MatchQ[f[1, 3], f[PatternTest[BlankSequence[], small]]]]"]
              @?= "List[True, False]",
          testCase "a condition sees the whole run" $
            evalStd ["Set[isAB[List[a, b]], True]", "Replace[f[a, b, c], RuleDelayed[f[Condition[Pattern[x, BlankSequence[]], isAB[List[x]]], Pattern[y, BlankSequence[]]], List[y]]]"]
              @?= "List[c]"
        ],
      testGroup
        "Repeated and Optional"
        [ testCase "Repeated matches each argument of its run" $
            evalStd ["List[MatchQ[f[a, a, a], f[Repeated[a]]], MatchQ[f[a, b], f[Repeated[a]]], MatchQ[f[], f[Repeated[a]]], MatchQ[f[], f[RepeatedNull[a]]]]"]
              @?= "List[True, False, False, True]",
          testCase "Repeated with a count: at most n, exactly {n}, {min, max}" $
            evalStd ["List[MatchQ[f[a, a], f[Repeated[a, 2]]], MatchQ[f[a, a, a], f[Repeated[a, 2]]], MatchQ[f[a], f[Repeated[a, List[2]]]], MatchQ[f[a, a, a], f[Repeated[a, List[2, 3]]]]]"]
              @?= "List[True, False, False, True]",
          testCase "Optional with a default, present and absent" $
            evalStd ["List[Replace[f[a], RuleDelayed[f[Pattern[x, Blank[]], Optional[Pattern[y, Blank[]], 0]], List[x, y]]], Replace[f[a, b], RuleDelayed[f[Pattern[x, Blank[]], Optional[Pattern[y, Blank[]], 0]], List[x, y]]]]"]
              @?= "List[List[a, 0], List[a, b]]",
          -- wolfram/OneIdentity/PropertiesAndRelations/1
          testCase "Times' built-in default and OneIdentity: x matches n_. x" $
            evalStd ["ReplaceAll[List[x, Times[2, x], Times[-1, x]], RuleDelayed[Times[Optional[Pattern[n, Blank[]]], x], Power[y, n]]]"]
              @?= "List[y, Power[y, 2], Power[y, -1]]"
        ],
      testGroup
        "Flat"
        [ -- wolfram/Flat/BasicExamples/3
          testCase "a blank under Flat takes the rest of the arguments, grouped" $
            evalStd ["ReplaceAll[Plus[a, b, c], Rule[Plus[Pattern[x, Blank[]], Pattern[y, Blank[]]], List[x, y]]]"] @?= "List[a, Plus[b, c]]",
          -- wolfram/Flat/PossibleIssues/3
          testCase "a blank under Flat takes several arguments; Repeated does not" $
            evalStd ["SetAttributes[f, Flat]", "List[MatchQ[f[1, 2], f[Blank[]]], MatchQ[f[1, 2], f[Repeated[Blank[], List[1]]]]]"] @?= "List[True, False]",
          -- wolfram/OneIdentity/PropertiesAndRelations/2
          testCase "one argument under Flat alone binds f[a] first; with OneIdentity, a" $
            ( evalStd ["SetAttributes[f, Flat]", "ReplaceAll[List[f[a], f[b, c]], RuleDelayed[f[Pattern[x, Blank[]]], x]]"],
              evalStd ["SetAttributes[f, List[Flat, OneIdentity]]", "ReplaceAll[List[f[a], f[b, c]], RuleDelayed[f[Pattern[x, Blank[]]], x]]"]
            )
              @?= ("List[f[a], f[b, c]]", "List[a, f[b, c]]"),
          -- wolfram/Flat/PropertiesAndRelations/5
          testCase "under Flat alone, a failed condition on f[a] falls back to a" $
            evalStd ["SetAttributes[f, Flat]", "SetDelayed[isInt[Blank[Integer]], True]", "ReplaceAll[f[3], RuleDelayed[Condition[f[Pattern[z, Blank[]]], isInt[z]], z]]"]
              @?= "3",
          -- wolfram/Flat/Scope/2
          testCase "a Flat rule applies to a run of the arguments" $
            evalStd ["SetAttributes[f, Flat]", "List[ReplaceAll[f[a, b, c, d, e], Rule[f[b, c, d], x]], ReplaceAll[f[a, b, c, d, e], Rule[f[b], x]]]"]
              @?= "List[f[a, x, e], f[a, x, c, d, e]]",
          -- wolfram/Flat/Scope/3
          testCase "a Flat and Orderless rule applies to a sub-multiset" $
            evalStd ["SetAttributes[f, List[Flat, Orderless]]", "ReplaceAll[f[a, b, c, d, e], Rule[f[d, b], x]]"] @?= "f[a, c, e, x]"
        ]
    ]
