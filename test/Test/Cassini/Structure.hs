-- | "Cassini.Structure": Cohen's structural operators (DESIGN.md §3.7, §7.3).
module Test.Cassini.Structure (tests) where

import Cassini.Core.Expr (apply, exprHead)
import Cassini.Core.Symbol (sFactorial, sPower)
import Cassini.Structure
import Test.Gen
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (forAll, forAllShrink, oneof, sized, testProperty, (===), (==>))

tests :: TestTree
tests =
  testGroup
    "Structure"
    [ testGroup
        "part"
        [ testCase "0 is the head" $ part fx 0 @?= Right (sym "f"),
          testCase "an atom's head" $ part x 0 @?= Right (exprHead x),
          testCase "1 is the first argument" $ part fx 1 @?= Right x,
          testCase "-1 is the last argument" $ part fx (-1) @?= Right y,
          testCase "past the end" $ part fx 3 @?= Left (PartError fx 3),
          testCase "before the start" $ part fx (-3) @?= Left (PartError fx (-3)),
          testCase "an atom has no part 1" $ part x 1 @?= Left (PartError x 1)
        ],
      testGroup
        "kind"
        [ testCase "Power[x, 2] is a power" $ exprKind (power x (int 2)) @?= KPower,
          testCase "Power[x] is a function" $ exprKind (apply sPower [x]) @?= KFunction,
          testCase "Factorial[] is a function" $ exprKind (apply sFactorial []) @?= KFunction,
          testCase "Global`Power[x, 2] is a function" $ exprKind (fn "Power" [x, int 2]) @?= KFunction,
          testCase "f[x][y] is a function" $ exprKind <$> lookupKind "curried-head function" @?= Just KFunction
        ],
      -- Source: cohen2002 §3.3, Example 3.29 (the cases that need no simplification).
      testGroup
        "Cohen's Free_of examples"
        [ testCase "Free_of(a + b, b) is false" $ freeOf (plus [a, b]) b @?= False,
          testCase "Free_of(a + b, c) is true" $ freeOf (plus [a, b]) c @?= True,
          testCase "Free_of((a + b)·c, a + b) is false" $ freeOf (times [plus [a, b], c]) (plus [a, b]) @?= False,
          testCase "Free_of(sin(x) + 2x, sin(x)) is false" $
            freeOf (plus [fn "Sin" [x], times [int 2, x]]) (fn "Sin" [x]) @?= False,
          testCase "Free_of((a + b + c)·d, a + b) is true" $
            freeOf (times [plus [a, b, c], sym "d"]) (plus [a, b]) @?= True,
          testCase "heads are subexpressions, as in WL" $ freeOf fx (sym "f") @?= False
        ],
      -- Source: cohen2002 §3.3, Figure 3.23.
      testGroup
        "Cohen's Substitute examples"
        [ testCase "<2> Substitute(a + b, b = x)" $ substitute (plus [a, b]) b x @?= plus [a, x],
          testCase "<4> Substitute(1/a + a, a = x)" $
            substitute (plus [power a (int (-1)), a]) a x @?= plus [power x (int (-1)), x],
          testCase "<5> Substitute((a + b)² + 1, a + b = x)" $
            substitute (plus [power (plus [a, b]) (int 2), int 1]) (plus [a, b]) x
              @?= plus [power x (int 2), int 1],
          testCase "<6> Substitute(a + b + c, a + b = x) does nothing" $
            substitute (plus [a, b, c]) (plus [a, b]) x @?= plus [a, b, c],
          testCase "sequential substitution sees earlier replacements" $
            substituteSeq (fn "f" [a]) [(a, b), (b, c)] @?= fn "f" [c],
          testCase "concurrent substitution does not" $
            substituteAll (fn "f" [a, b]) [(a, b), (b, a)] @?= fn "f" [b, a]
        ],
      testGroup
        "laws"
        [ testProperty "substitute u t t ≡ u" $ forTerm $ \u -> forAll (genT u) $ \t -> substitute u t t === u,
          testProperty "freeOf u t implies substitute u t r ≡ u" $ forTerm $ \u ->
            forAll (genT u) $ \t -> forAll (genExpr 5) $ \r ->
              freeOf u t ==> substitute u t r === u,
          testProperty "a subterm is not free" $ forTerm $ \u ->
            forAll (genSubterm u) $ \t -> freeOf u t === False
        ]
    ]
  where
    a = sym "a"
    b = sym "b"
    c = sym "c"
    x = sym "x"
    y = sym "y"
    fx = fn "f" [x, y]
    lookupKind n = snd <$> find ((== n) . fst) everyKind
    forTerm = forAllShrink (sized (genExpr . min 30)) shrinkExpr
    genT u = oneof [genSubterm u, genExpr 4]
