-- | "Cassini.Number.Integer" and "Cassini.Builtins.Integer", with §7.3's
-- @Number.Integer@ row (DESIGN.md §4.15).
module Test.Cassini.Integer (tests) where

import Cassini.Number.Integer (factorInteger, isProbablePrime)
import Test.Kernel (evalStd)
import Test.QuickCheck (Property, chooseInteger, counterexample, elements, forAll, (===))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "Integer"
    [ testGroup
        "builtins"
        [ testCase "Mod has the sign of the divisor, Quotient is the floor" $
            evalStd ["List[Mod[-7, 3], Mod[7, -3], Quotient[-7, 3], Mod[Rational[5, 2], 1]]"] @?= "List[2, -2, -3, Rational[1, 2]]",
          testCase "Round breaks ties to even" $ evalStd ["List[Round[Rational[5, 2]], Round[Rational[7, 2]], Round[Rational[-5, 2]]]"] @?= "List[2, 4, -2]",
          testCase "GCD and LCM of rationals, and partly numeric" $
            evalStd ["List[GCD[Rational[1, 2], Rational[1, 3]], LCM[Rational[2, 3], Rational[1, 3]], LCM[5, 6, c]]"] @?= "List[Rational[1, 6], Rational[2, 3], LCM[30, c]]",
          testCase "Binomial at negative and symbolic arguments" $
            evalStd ["List[Binomial[-3, 2], Binomial[5, 7], Binomial[n, 2]]"] @?= "List[6, 0, Times[Rational[1, 2], n, Plus[-1, n]]]",
          testCase "Max and Min collapse the numbers, infinities included" $
            evalStd ["List[Max[1, x, 3], Min[List[2, -5], x], Max[], Max[Infinity, 2]]"] @?= "List[Max[3, x], Min[-5, x], DirectedInfinity[-1], DirectedInfinity[1]]",
          testCase "Abs and Sign need no assumptions for these" $
            evalStd ["List[Abs[Times[-2, x]], Sign[Times[-2, x]], Abs[Sqrt[3]], Sign[Times[-1, Pi]], Abs[Abs[z]]]"] @?= "List[Times[2, Abs[x]], Times[-1, Sign[x]], Power[3, Rational[1, 2]], -1, Abs[z]]",
          testCase "FactorInteger with a sign and a denominator" $
            evalStd ["FactorInteger[Rational[-45, 8]]"] @?= "List[List[-1, 1], List[2, -3], List[3, 2], List[5, 1]]",
          testCase "PrimeQ of a Mersenne prime past machine size" $ evalStd ["PrimeQ[Plus[Power[2, 89], -1]]"] @?= "True",
          testCase "Numerator and Denominator read signs as WL does" $
            evalStd ["List[Numerator[Times[x, Power[a, Times[-1, b]], Rational[1, 2]]], Denominator[Times[x, Power[a, Times[-1, b]], Rational[1, 2]]]]"] @?= "List[x, Times[2, Power[a, b]]]"
        ],
      testProperty "m = n Quotient[m, n] + Mod[m, n], Mod with the sign of n (§7.3)" quotientMod,
      testProperty "factorInteger multiplies back, and every factor is prime (§7.3)" factorsBack,
      testProperty "isProbablePrime agrees with trial division below 10^6 (§7.3)" primesAgree
    ]

quotientMod :: Property
quotientMod =
  forAll (chooseInteger (-(10 ^ (12 :: Int)), 10 ^ (12 :: Int))) $ \m ->
    forAll (chooseInteger (1, 1000)) $ \n0 ->
      forAll (elements [n0, negate n0]) $ \n ->
        let r = evalStd ["List[Plus[Times[" <> show n <> ", Quotient[" <> show m <> ", " <> show n <> "]], Mod[" <> show m <> ", " <> show n <> "]], Sign[Mod[" <> show m <> ", " <> show n <> "]]]"]
         in counterexample (toString r) $ r `elem` ["List[" <> show m <> ", 0]", "List[" <> show m <> ", " <> show (signum n) <> "]"]

factorsBack :: Property
factorsBack =
  forAll (chooseInteger (2, 10 ^ (15 :: Int))) $ \n ->
    let fs = factorInteger n
     in counterexample (show fs) $ (product [p ^ k | (p, k) <- fs], all (isProbablePrime . fst) fs) === (n, True)

primesAgree :: Property
primesAgree =
  forAll (chooseInteger (0, 10 ^ (6 :: Int))) $ \n ->
    isProbablePrime n === (n >= 2 && all (\p -> n `mod` p /= 0) (takeWhile (\p -> p * p <= n) [2 ..]))
