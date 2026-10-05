-- | "Cassini.Core.Order": Cohen's worked examples, and the order laws over
-- generated terms and over every pair of kinds (DESIGN.md §3.5, §7.3).
module Test.Cassini.Core.Order (tests) where

import Cassini.Core.Expr (Expr)
import Cassini.Core.Order (compareCanonical)
import Data.Ratio ((%))
import Test.Gen
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))
import Test.Tasty.QuickCheck (Gen, Property, counterexample, forAllShrink, listOf, shrinkList, sized, testProperty, (.&&.), (===))

tests :: TestTree
tests =
  testGroup
    "Core.Order"
    [ cohenExamples,
      testGroup "every pair of kinds" kindPairs,
      testGroup
        "laws"
        [ testProperty "reflexive" $ forAllShrink gen shrinkExpr $ \x -> compareCanonical x x === EQ,
          testProperty "antisymmetric" $ forAll2 $ \x y ->
            compareCanonical x y === invert (compareCanonical y x),
          testProperty "transitive" $ forAll3 gen transitive,
          testProperty "transitive, small terms" $ forAll3 (genExpr 5) transitive,
          testProperty "EQ exactly on equal terms" $ forAll2 $ \x y ->
            (compareCanonical x y == EQ) === (x == y),
          testProperty "sorting is a permutation" $
            forAllShrink (listOf gen) (shrinkList shrinkExpr) $ \xs ->
              let ys = sortBy compareCanonical xs
               in length ys === length xs .&&. all (\e -> count e xs == count e ys) xs
        ]
    ]
  where
    count e = length . filter (== e)

-- | Source: cohen2003 §3.1, Definition 3.26 and Examples 3.27–3.32. Each pair
-- is checked in both directions.
cohenExamples :: TestTree
cohenExamples =
  testGroup
    "Cohen's examples"
    [ before "O-1: 2 ◁ 5/2" (int 2) (rat (5 % 2)),
      before "O-2: a ◁ b" a b,
      before "O-2: v1 ◁ v2" (sym "v1") (sym "v2"),
      before "O-2: x1 ◁ xa" (sym "x1") (sym "xa"),
      before "O-3: a + b ◁ a + c" (plus [a, b]) (plus [a, c]),
      before "O-3: a + c + d ◁ b + c + d" (plus [a, c, d]) (plus [b, c, d]),
      before "O-3-3: c + d ◁ b + c + d" (plus [c, d]) (plus [b, c, d]),
      before "Ex. 3.27: (1+x)² ◁ (1+x)³" (power (plus [int 1, x]) (int 2)) (power (plus [int 1, x]) (int 3)),
      before "Ex. 3.27: (1+x)³ ◁ (1+y)²" (power (plus [int 1, x]) (int 3)) (power (plus [int 1, y]) (int 2)),
      before "O-6: f(x) ◁ g(x)" (fn "f" [x]) (fn "g" [x]),
      before "O-6: f(x) ◁ f(y)" (fn "f" [x]) (fn "f" [y]),
      before "O-6-2c: g(x) ◁ g(x, y)" (fn "g" [x]) (fn "g" [x, y]),
      before "O-7: 3 ◁ x" (int 3) x,
      before "Ex. 3.28: a·x² ◁ x³" (times [a, power x (int 2)]) (power x (int 3)),
      before "Ex. 3.29: (1+x)³ ◁ 1+y" (power (plus [int 1, x]) (int 3)) (plus [int 1, y]),
      before "Ex. 3.30: 1+x ◁ y" (plus [int 1, x]) y,
      before "O-11: m! ◁ n" (factorial (sym "m")) (sym "n"),
      before "O-11-1: n ◁ n!" (sym "n") (factorial (sym "n")),
      before "Ex. 3.31: x ◁ x(t)" x (fn "x" [sym "t"]),
      before "Ex. 3.31: x ◁ y(t)" x (fn "y" [sym "t"]),
      before "Ex. 3.32: x ◁ x²" x (power x (int 2))
    ]
  where
    a = sym "a"
    b = sym "b"
    c = sym "c"
    d = sym "d"
    x = sym "x"
    y = sym "y"
    before name u v =
      testCase name $ (compareCanonical u v, compareCanonical v u) @?= (LT, GT)

-- | Antisymmetry over every pair, and transitivity over every triple, of
-- 'everyKind': a pair no rule covers would diverge or disagree here.
kindPairs :: [TestTree]
kindPairs =
  [ testCase "antisymmetric" $
      sequence_
        [ assertBool (n1 <> " vs " <> n2) (compareCanonical u v == invert (compareCanonical v u))
        | (n1, u) <- everyKind,
          (n2, v) <- everyKind
        ],
    testCase "transitive" $
      sequence_
        [ assertBool (intercalate ", " [n1, n2, n3]) (transitive' u v w)
        | (n1, u) <- everyKind,
          (n2, v) <- everyKind,
          (n3, w) <- everyKind
        ]
  ]

transitive :: Expr -> Expr -> Expr -> Property
transitive u v w =
  counterexample (show (compareCanonical u v, compareCanonical v w, compareCanonical u w)) $
    transitive' u v w

transitive' :: Expr -> Expr -> Expr -> Bool
transitive' u v w =
  not (compareCanonical u v /= GT && compareCanonical v w /= GT) || compareCanonical u w /= GT

invert :: Ordering -> Ordering
invert = compare EQ

gen :: Gen Expr
gen = sized (genExpr . min 30)

forAll2 :: (Expr -> Expr -> Property) -> Property
forAll2 f = forAllShrink ((,) <$> gen <*> gen) (liftShrink2' shrinkExpr) (uncurry f)

forAll3 :: Gen Expr -> (Expr -> Expr -> Expr -> Property) -> Property
forAll3 g f =
  forAllShrink ((,,) <$> g <*> g <*> g) shrink3 (\(u, v, w) -> f u v w)
  where
    shrink3 (u, v, w) =
      [(u', v, w) | u' <- shrinkExpr u] ++ [(u, v', w) | v' <- shrinkExpr v] ++ [(u, v, w') | w' <- shrinkExpr w]

liftShrink2' :: (a -> [a]) -> (a, a) -> [(a, a)]
liftShrink2' s (u, v) = [(u', v) | u' <- s u] ++ [(u, v') | v' <- s v]
