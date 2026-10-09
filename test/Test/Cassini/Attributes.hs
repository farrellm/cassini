-- The identity law is the law under test, so hlint's rewrite of it is not
-- wanted here.
{- HLINT ignore "Monoid law, left identity" -}
{- HLINT ignore "Monoid law, right identity" -}

-- | "Cassini.Attributes": the monoid laws, and 'holdsArgument' against a
-- naive reference (DESIGN.md §4.1, §7.3).
module Test.Cassini.Attributes (tests) where

import Cassini.Attributes
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (Gen, chooseInt, forAll, sublistOf, testProperty, (===))

tests :: TestTree
tests =
  testGroup
    "Attributes"
    [ testProperty "union is associative" $ forAll3 $ \s t u -> (s <> t) <> u === s <> (t <> u),
      testProperty "union is commutative" $ forAll2 $ \s t -> s <> t === t <> s,
      testProperty "union is idempotent" $ forAll genSet $ \s -> s <> s === s,
      testProperty "the empty set is the identity" $ forAll genSet $ \s -> (mempty <> s, s <> mempty) === (s, s),
      testProperty "membership is the list's" $ forAll (sublistOf universe) $ \as ->
        filter (`member` attributeSet as) universe === sortNub as,
      testProperty "holdsArgument agrees with a naive reference" $
        forAll genSet $ \s -> forAll (chooseInt (0, 5)) $ \n -> forAll (chooseInt (-1, 6)) $ \i ->
          holdsArgument s i n === (i `elem` heldIndices s n),
      testCase "names round-trip" $ map (attributeFromName . attributeName) universe @?= map Just universe,
      testCase "WL's order is by name" $
        attributeList (attributeSet [Protected, Orderless, Flat]) @?= [Flat, Orderless, Protected]
    ]
  where
    forAll2 p = forAll genSet $ \s -> forAll genSet (p s)
    forAll3 p = forAll genSet $ \s -> forAll genSet $ \t -> forAll genSet (p s t)

genSet :: Gen AttributeSet
genSet = attributeSet <$> sublistOf universe

-- | The held positions, written out: all of them, or the first, or the rest.
heldIndices :: AttributeSet -> Int -> [Int]
heldIndices s n
  | member HoldAll s || member HoldAllComplete s = [1 .. n]
  | otherwise = [1 | member HoldFirst s, n >= 1] ++ (if member HoldRest s then [2 .. n] else [])
