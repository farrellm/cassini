-- | "Cassini.Eval": each step of the sequence, the traps it exists to
-- prevent, the limits, and §7.3's laws (DESIGN.md §4.4).
module Test.Cassini.Eval (tests) where

import Cassini.Eval.Kernel (EvalConfig (..), defaultConfig)
import Data.Text qualified as T
import Test.Gen (genExpr, shrinkExpr)
import Test.Kernel (eval, evalStd, evalWith, ff, messageNames, parse, std)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (counterexample, forAllShrink, sized, testProperty, (===))

tests :: TestTree
tests =
  testGroup
    "Eval"
    [ testGroup
        "steps"
        [ testCase "1: a raw object is left unchanged" $ evalStd ["\"s\""] @?= "\"s\"",
          testCase "0: own values chain through the fixed point" $ evalStd ["Set[x, y]", "Set[y, 5]", "x"] @?= "5",
          testCase "2: the head is evaluated" $ evalStd ["Set[h, f]", "h[1]"] @?= "f[1]",
          testCase "3–4: Hold[1+1] stays: the mask gates evaluation" $ evalStd ["Hold[Plus[1, 1]]"] @?= "Hold[Plus[1, 1]]",
          testCase "4: HoldFirst holds the first argument only" $
            evalStd ["SetAttributes[h, HoldFirst]", "h[Plus[1, 1], Plus[1, 1]]"] @?= "h[Plus[1, 1], 2]",
          testCase "4: HoldRest holds the others" $
            evalStd ["SetAttributes[h, HoldRest]", "h[Plus[1, 1], Plus[1, 1]]"] @?= "h[2, Plus[1, 1]]",
          testCase "4: Evaluate overrides a hold" $ evalStd ["Hold[Evaluate[Plus[1, 1]]]"] @?= "Hold[2]",
          testCase "5: Sequence is spliced" $ evalStd ["f[Sequence[a, b], c]"] @?= "f[a, b, c]",
          testCase "5: SequenceHold keeps it" $
            evalStd ["SetAttributes[h, SequenceHold]", "h[Sequence[a, b]]"] @?= "h[Sequence[a, b]]",
          testCase "6: Unevaluated is restored when no rule fires" $
            evalStd ["f[Unevaluated[Plus[1, 1]]]"] @?= "f[Unevaluated[Plus[1, 1]]]",
          testCase "6: a rule sees the stripped argument" $
            evalStd ["SetDelayed[f[Pattern[x, Blank[]]], Hold[x]]", "f[Unevaluated[Plus[1, 1]]]"] @?= "Hold[Plus[1, 1]]",
          testCase "6: a builtin sees the stripped argument" $ evalStd ["Length[Unevaluated[Plus[a, b, c]]]"] @?= "3",
          testCase "5 before 6: a Sequence inside Unevaluated is not spliced" $
            evalStd ["f[Unevaluated[Sequence[a, b]]]"] @?= "f[Unevaluated[Sequence[a, b]]]",
          testCase "7: Flat flattens" $ evalStd ["SetAttributes[h, Flat]", "h[a, h[b, h[c]]]"] @?= "h[a, b, c]",
          testCase "8: Listable threads" $ evalStd ["SetAttributes[h, Listable]", "h[List[1, 2], 3]"] @?= "List[h[1, 3], h[2, 3]]",
          testCase "8: lists of unequal length are Thread::tdlen" $
            let (r, st) = eval std (parse "Plus[List[1, 2], List[1, 2, 3]]")
             in (ff r, messageNames st) @?= ("Plus[List[1, 2], List[1, 2, 3]]", ["Thread::tdlen"]),
          testCase "9: Orderless sorts canonically" $ evalStd ["SetAttributes[h, Orderless]", "h[c, a, b]"] @?= "h[a, b, c]",
          testCase "7 → 8 → 9: Flat before Listable before Orderless" $
            evalStd ["SetAttributes[h, List[Flat, Listable, Orderless]]", "h[b, h[List[a, c]]]"] @?= "List[h[a, b], h[b, c]]",
          testCase "Indeterminate: a numeric function of Indeterminate is Indeterminate" $
            evalStd ["Plus[Indeterminate, Times[-1, Indeterminate]]"] @?= "Indeterminate",
          testCase "12: subvalues for a curried head" $
            evalStd ["SetDelayed[f[Pattern[x, Blank[]]][Pattern[y, Blank[]]], Plus[x, y]]", "f[1][2]"] @?= "3",
          testCase "12: a downvalue does not match a curried head" $
            evalStd ["SetDelayed[f[Pattern[x, Blank[]]], x]", "f[1][2]"] @?= "1[2]",
          testCase "13: built-in downvalues: Plus collects" $ evalStd ["Plus[a, Plus[b, a]]"] @?= "Plus[Times[2, a], b]",
          testCase "Function's third argument gives its attributes" $
            evalStd ["Function[x, y, HoldAll][Plus[1, 1]]"] @?= "Function[x, y, HoldAll][Plus[1, 1]]"
        ],
      testGroup
        "limits"
        [ testCase "$RecursionLimit: a cut is held, with reclim" $
            let (r, st) = evalWith defaultConfig {recursionLimit = 20} std (parse "f[1]")
                (r', st') = evalWith defaultConfig {recursionLimit = 20} (snd (eval std (parse "SetDelayed[f[Pattern[n, Blank[]]], f[Plus[n, 1]]]"))) (parse "f[1]")
             in ((ff r, messageNames st), take 1 (messageNames st'), "Hold[" `isInfix` ff r') @?= (("f[1]", []), ["$RecursionLimit::reclim"], True),
          testCase "$IterationLimit: an endless chain is held, with itlim" $
            let st0 = snd (eval (snd (eval std (parse "SetDelayed[p, q]"))) (parse "SetDelayed[q, p]"))
                (r, st) = evalWith defaultConfig {iterationLimit = 50} st0 (parse "p")
             in (ff r, messageNames st) @?= ("Hold[p]", ["$IterationLimit::itlim"])
        ],
      testGroup
        "messages"
        [ testCase "1/0 is ComplexInfinity with Power::infy" $
            let (r, st) = eval std (parse "Power[0, -1]") in (ff r, messageNames st) @?= ("DirectedInfinity[]", ["Power::infy"]),
          testCase "0^0 is Indeterminate with Power::indet" $
            let (r, st) = eval std (parse "Power[0, 0]") in (ff r, messageNames st) @?= ("Indeterminate", ["Power::indet"]),
          testCase "Part out of range stays, with Part::partw" $
            let (r, st) = eval std (parse "Part[List[1, 2], 5]") in (ff r, messageNames st) @?= ("Part[List[1, 2], 5]", ["Part::partw"])
        ],
      testGroup
        "laws"
        [ testProperty "evaluation is idempotent" $
            forAllShrink (sized genExpr) shrinkExpr $ \e ->
              let once = fst (eval std e)
               in counterexample (toString (ff once)) (ff (fst (eval std once)) === ff once),
          testProperty "evaluation is deterministic" $
            forAllShrink (sized genExpr) shrinkExpr $ \e ->
              let (r1, s1) = eval std e
                  (r2, s2) = eval std e
               in (ff r1, messageNames s1) === (ff r2, messageNames s2)
        ]
    ]
  where
    isInfix = T.isInfixOf
