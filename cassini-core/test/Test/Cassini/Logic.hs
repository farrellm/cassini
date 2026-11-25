{-# LANGUAGE PatternSynonyms #-}

-- | "Cassini.Builtins.Logic": three-valued comparison, with §7.3's @Logic@
-- row (DESIGN.md §4.14).
module Test.Cassini.Logic (tests) where

import Cassini.Core.Expr (apply, pattern Int_, pattern Num)
import Cassini.Core.Symbol (systemSymbol)
import Test.Gen (genExpr, shrinkExpr)
import Test.Kernel (eval, evalStd, ff, parse, std)
import Test.QuickCheck (Property, chooseInt, counterexample, elements, forAll, forAllShrink, sized, vectorOf, (.||.), (===))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "Logic"
    [ testGroup
        "Equal"
        [ testCase "identical is True" $ evalStd ["Equal[f[x], f[x]]"] @?= "True",
          testCase "distinct free symbols stay" $ evalStd ["Equal[x, y]"] @?= "Equal[x, y]",
          testCase "distinct numbers are False" $ evalStd ["Equal[1, Rational[1, 2]]"] @?= "False",
          testCase "lists compare elementwise" $ evalStd ["List[Equal[List[1, x], List[1, x]], Equal[List[1, 2], List[1, 3]], Equal[List[1], List[1, 2]]]"] @?= "List[True, False, False]",
          testCase "a polynomial identity stays until 2a (§10)" $
            evalStd ["Equal[Power[Plus[x, 1], 2], Plus[Power[x, 2], Times[2, x], 1]]"] @?= "Equal[Power[Plus[1, x], 2], Plus[1, Times[2, x], Power[x, 2]]]",
          testCase "a radical the rational layer cannot decide stays (§5.6, D15)" $ evalStd ["Equal[Sqrt[2], 1]"] @?= "Equal[Power[2, Rational[1, 2]], 1]",
          testCase "Indeterminate equals nothing" $ evalStd ["Equal[Indeterminate, Indeterminate]"] @?= "Equal[Indeterminate, Indeterminate]",
          testCase "Infinity == -Infinity is quiet" $ evalStd ["Equal[Infinity, Times[-1, Infinity]]"] @?= "Equal[DirectedInfinity[1], DirectedInfinity[-1]]"
        ],
      testGroup
        "orderings"
        [ testCase "decided on rationals and the real infinities" $
            evalStd ["List[Less[1, 2, 3], Less[1, 3, 2], Greater[Infinity, 5], LessEqual[2, 2]]"] @?= "List[True, False, True, True]",
          testCase "Pi > 3 waits for certified numerics (D9)" $ evalStd ["Greater[Pi, 3]"] @?= "Greater[Pi, 3]"
        ],
      testProperty "Equal is True only on a zero difference, False only on a nonzero number (§7.3)" equalSound,
      testProperty "And and Or never evaluate an argument after the deciding one (§7.3)" shortCircuit
    ]

-- | Whatever @a == b@ gives, it is right: 'True' only when @a - b@
-- evaluates to 0 (or the two are identical), 'False' only when it
-- evaluates to a nonzero number, and otherwise the comparison stays.
equalSound :: Property
equalSound =
  forAllShrink (sized (genExpr . min 12)) shrinkExpr $ \a ->
    forAllShrink (sized (genExpr . min 12)) shrinkExpr $ \b ->
      let (r, _) = eval std (apply (systemSymbol "Equal") [a, b])
          (va, _) = eval std a
          (vb, _) = eval std b
          (d, _) = eval std (apply (systemSymbol "Plus") [a, apply (systemSymbol "Times") [Int_ (-1), b]])
       in counterexample (toString (ff r <> " / " <> ff d)) $ case ff r of
            "True" -> ff d === "0" .||. ff va === ff vb
            "False" -> isNumber d .||. isString va .||. isString vb .||. isList va
            _ -> ff r === ff (apply (systemSymbol "Equal") [va, vb])
  where
    isNumber = \case
      Num _ -> True
      _ -> False
    isString x = take 1 (toString (ff x)) == "\""
    isList x = take 5 (toString (ff x)) == "List["

-- | A run of @True@s for @And@ (@False@s for @Or@), the deciding value, then
-- an argument that would set a flag: the flag stays unset.
shortCircuit :: Property
shortCircuit =
  forAll (elements [("And", "True", "False"), ("Or", "False", "True")]) $ \(op, unit, decider) ->
    forAll (chooseInt (0, 4)) $ \k ->
      forAll (vectorOf k (elements [unit, "x"])) $ \before ->
        let args = before <> [decider, "Set[flag, 1]"]
            (r, st) = eval std (parse (op <> "[" <> mconcat (intersperse ", " args) <> "]"))
         in counterexample (show args) $ (ff r, ff (fst (eval st (parse "flag")))) === (decider, "flag")
