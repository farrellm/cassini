-- | "Cassini.Builtins.Calculus": each rule of @D@'s table, @Derivative@'s
-- subvalues, milestone 1c's criterion, and §7.3's @Calculus@ row over
-- arithmetic expressions (DESIGN.md §4.9).
module Test.Cassini.Calculus (tests) where

import Cassini.Core.Expr (apply)
import Cassini.Core.Symbol (systemSymbol)
import Data.Map.Strict qualified as Map
import Data.Text qualified as T
import Test.Gen (genBAE, shrinkExpr, sym)
import Test.Kernel (eval, evalStd, ff, std)
import Test.Numeric (evalAt, genPoint)
import Test.QuickCheck (Property, counterexample, discard, forAll, forAllShrink, sized)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "Calculus"
    [ testGroup
        "milestone 1c (DESIGN.md §10)"
        [ testCase "D[f[x] g[x], x] gives both product-rule terms" $
            evalStd ["D[Times[f[x], g[x]], x]"] @?= "Plus[Times[Derivative[1][g][x], f[x]], Times[Derivative[1][f][x], g[x]]]",
          testCase "after Derivative[1][f] = 3 #^2 &, D[f[x^2], x] is 6 x^5" $
            evalStd ["Set[Derivative[1][f], Function[Times[3, Power[Slot[1], 2]]]]", "D[f[Power[x, 2]], x]"] @?= "Times[6, Power[x, 5]]"
        ],
      testGroup
        "D's rules, in table order"
        [ testCase "D[f] is f" $ evalStd ["D[Power[x, 2]]"] @?= "Power[x, 2]",
          testCase "several variables differentiate in turn" $ evalStd ["D[Times[Power[x, 2], Power[y, 3]], x, y]"] @?= "Times[6, x, Power[y, 2]]",
          testCase "{x, n} is the nth derivative" $ evalStd ["D[Power[x, 5], List[x, 3]]"] @?= "Times[60, Power[x, 2]]",
          testCase "{x, 0} is the expression" $ evalStd ["D[Power[x, 5], List[x, 0]]"] @?= "Power[x, 5]",
          testCase "{{x, y}} is the gradient" $ evalStd ["D[Times[x, y], List[List[x, y]]]"] @?= "List[y, x]",
          testCase "D threads over a list" $ evalStd ["D[List[x, Power[x, 2]], x]"] @?= "List[1, Times[2, x]]",
          testCase "a constant's derivative is 0" $ evalStd ["D[Times[a, y], x]"] @?= "0",
          testCase "the variable's is 1" $ evalStd ["D[x, x]"] @?= "1",
          testCase "the sum rule" $ evalStd ["D[Plus[Power[x, 2], x, 1], x]"] @?= "Plus[1, Times[2, x]]",
          testCase "the product rule" $ evalStd ["D[Times[a, x, f[x]], x]"] @?= "Plus[Times[a, f[x]], Times[Derivative[1][f][x], a, x]]",
          testCase "the power rule, symbolic exponent" $ evalStd ["D[Power[x, n], x]"] @?= "Times[n, Power[x, Plus[-1, n]]]",
          testCase "an exponent depending on the variable waits for Log (§4.11)" $
            evalStd ["D[Power[2, x], x]"] @?= "D[Power[2, x], x]",
          testCase "the chain rule, through each argument" $
            evalStd ["D[h[x, Power[x, 2], y], x]"] @?= "Plus[Derivative[1, 0, 0][h][x, Power[x, 2], y], Times[2, Derivative[0, 1, 0][h][x, Power[x, 2], y], x]]",
          testCase "differentiating a derivative raises its order" $ evalStd ["D[Derivative[1][f][x], x]"] @?= "Derivative[2][f][x]",
          testCase "a head alone depending on the variable gives 0" $ evalStd ["D[x[t], x]"] @?= "0",
          testCase "differentiation by a subexpression" $ evalStd ["D[Power[f[x], 2], f[x]]"] @?= "Times[2, f[x]]"
        ],
      testGroup
        "Derivative"
        [ testCase "Derivative[0][f] is f" $ evalStd ["Derivative[0][f]"] @?= "f",
          testCase "orders add" $ evalStd ["Derivative[1][Derivative[2][f]]"] @?= "Derivative[3][f]",
          testCase "an unknown function's derivative stays" $ evalStd ["Derivative[1][f][x]"] @?= "Derivative[1][f][x]",
          -- wolfram/Derivative/Scope/1 does this with x Cos[x]; Cos's
          -- derivative waits for §4.11, so a polynomial stands in.
          testCase "a function defined by a downvalue differentiates to a pure function" $
            evalStd ["SetDelayed[f[Pattern[x, Blank[]]], Times[x, Power[x, 2]]]", "Derivative[1][f]"] @?= "Function[Times[3, Power[Slot[1], 2]]]",
          -- wolfram/Derivative/BasicExamples/1, with a polynomial for Sin.
          testCase "f'[x] and D[f[x], x] agree" $
            evalStd ["SetDelayed[f[Pattern[x, Blank[]]], Plus[Power[x, 3], Power[x, 2]]]", "MatchQ[Derivative[1][f][x], D[f[x], x]]"] @?= "True",
          testCase "a second derivative" $
            evalStd ["SetDelayed[f[Pattern[x, Blank[]]], Plus[Power[x, 3], Power[x, 2]]]", "Derivative[2][f][x]"] @?= "Plus[2, Times[6, x]]",
          testCase "a pure function differentiates" $ evalStd ["Derivative[1][Function[Power[Slot[1], 3]]]"] @?= "Function[Times[3, Power[Slot[1], 2]]]",
          testCase "a partial derivative of a two-argument definition" $
            evalStd ["SetDelayed[f[Pattern[x, Blank[]], Pattern[y, Blank[]]], Times[Power[x, 2], y]]", "Derivative[1, 1][f][a, b]"] @?= "Times[2, a]",
          testCase "a definition that does not match fresh variables is left alone" $
            evalStd ["SetDelayed[f[Pattern[x, Blank[Integer]]], x]", "D[f[x], x]"] @?= "Derivative[1][f][x]",
          testCase "a user derivative as a subvalue" $
            evalStd ["SetDelayed[Derivative[1][f][Pattern[x, Blank[]]], fp[x]]", "D[f[Power[x, 2]], x]"] @?= "Times[2, fp[Power[x, 2]], x]"
        ],
      testProperty "D agrees with finite differences of the test evaluator (§7.3)" finiteDifferences
    ]

-- | For an arithmetic expression @e@ in @x@, @D[e, x]@ at a point agrees with
-- the central difference of @e@ there. Points where either side is
-- undefined, or where @D@ stays unevaluated, are discarded.
finiteDifferences :: Property
finiteDifferences =
  forAllShrink (sized (genBAE . min 24)) shrinkExpr $ \e ->
    forAll genPoint $ \p ->
      let d = fst (eval std (apply (systemSymbol "D") [e, sym "x"]))
          at x0 = evalAt (Map.insert "x" x0 p)
          x = p Map.! "x"
          h = 1.0e-5
       in case (at (x + h) e, at (x - h) e, evalAt p d) of
            (Just up, Just down, Just slope)
              | all (\v -> abs v < 1.0e6) [up, down, slope] ->
                  let fd = (up - down) / (2 * h)
                   in counterexample (T.unpack (ff d) <> " at " <> show p <> ": " <> show slope <> " vs " <> show fd) $
                        abs (slope - fd) <= 1.0e-4 * max 1 (abs slope + abs fd)
            _ -> discard
