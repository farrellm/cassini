-- | "Cassini.Number": arithmetic agrees with 'Rational', and order is
-- numeric across both constructors (DESIGN.md §3.1, §7.3).
module Test.Cassini.Number (tests) where

import Cassini.Number
import Data.Ratio ((%))
import Test.Gen (genNumber)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (Gen, chooseInteger, forAll, testProperty, (===))

tests :: TestTree
tests =
  testGroup
    "Number"
    [ testGroup
        "normalization"
        [ testCase "an integral fraction is an integer" $ fromRational' (6 % 3) @?= NInt 2,
          testCase "a fraction is reduced, sign on the numerator" $
            fromRational' (2 % (-4)) @?= NRat ((-1) % 2),
          testCase "a sum of fractions can be an integer" $
            add (NRat (1 % 2)) (NRat (1 % 2)) @?= NInt 1
        ],
      testGroup
        "order"
        [ -- Source: cohen2003 §3.1, Definition 3.26, O-1.
          testCase "O-1: 2 ◁ 5/2" $ compareNumber (NInt 2) (NRat (5 % 2)) @?= LT,
          testCase "derived constructor order would say 1 < 1/2" $
            compare (NInt 1) (NRat (1 % 2)) @?= GT
        ],
      testGroup
        "agrees with Rational"
        [ testProperty "add" $ binary $ \a b -> toRational' (add a b) === toRational' a + toRational' b,
          testProperty "mul" $ binary $ \a b -> toRational' (mul a b) === toRational' a * toRational' b,
          testProperty "neg" $ forAll genNumber $ \a -> toRational' (neg a) === negate (toRational' a),
          testProperty "divide" $ binary $ \a b ->
            (toRational' <$> divide a b)
              === if toRational' b == 0 then Nothing else Just (toRational' a / toRational' b),
          testProperty "pow" $ forAll genNumber $ \a -> forAll genExponent $ \e ->
            (toRational' <$> pow a e)
              === if toRational' a == 0 && e < 0 then Nothing else Just (toRational' a ^^ e),
          testProperty "compareNumber" $ binary $ \a b ->
            compareNumber a b === compare (toRational' a) (toRational' b),
          testProperty "results are normalized" $ binary $ \a b ->
            all normalized [add a b, mul a b, neg a]
        ]
    ]
  where
    binary f = forAll genNumber $ \a -> forAll genNumber $ \b -> f a b
    normalized = \case
      NInt _ -> True
      NRat r -> denominator r > 1

genExponent :: Gen Integer
genExponent = chooseInteger (-4, 6)
