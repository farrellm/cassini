{-# LANGUAGE PatternSynonyms #-}

-- | "Cassini.Simplify.Automatic": Cohen's worked examples, and the source's
-- two contracts as properties (DESIGN.md §4.6, §7.3).
module Test.Cassini.Simplify.Automatic (tests) where

import Cassini.Core.Expr (Expr, pattern App, pattern Num, pattern Sym)
import Cassini.Core.Symbol (sPlus, sPower, sTimes)
import Cassini.Number (fromRational', toRational')
import Cassini.Simplify.Automatic
import Data.Ratio ((%))
import Data.Vector qualified as V
import Test.Gen
import Test.Numeric (approxEqual, evalAt, genPoint)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (Property, checkCoverage, counterexample, cover, forAll, forAllShrink, sized, testProperty, (===), (==>))

tests :: TestTree
tests =
  testGroup
    "Simplify.Automatic"
    [ asaeExamples,
      simplificationExamples,
      testGroup
        "laws"
        [ testProperty "simplifyRNE agrees with Rational, and is Nothing exactly on division by zero" $
            forAllShrink (sized genRNE) shrinkExpr $ \u ->
              simplifyRNE u === (fromRational' <$> referenceRNE u),
          testProperty "simplify u is an ASAE or Undefined" $
            forAllShrink (sized genBAE) shrinkExpr $ \u -> case simplify u of
              Left _ -> True
              Right v -> isASAE v,
          testProperty "for an ASAE u, simplify u is u" $
            checkCoverage $
              forAllShrink (sized genBAE) shrinkExpr $ \u ->
                cover 5 (isASAE u) "already an ASAE" $
                  isASAE u ==>
                    (simplify u === Right u),
          testProperty "simplify is idempotent on its own output" $
            forAllShrink (sized genBAE) shrinkExpr $ \u -> case simplify u of
              Left _ -> True
              Right v -> simplify v == Right v,
          testProperty "simplify preserves numeric value" valuePreserved
        ]
    ]

valuePreserved :: Property
valuePreserved =
  forAllShrink (sized genBAE) shrinkExpr $ \u ->
    forAll genPoint $ \pt -> case simplify u of
      Left _ -> counterexample "undefined" True
      Right v -> case (evalAt pt u, evalAt pt v) of
        (Just before, Just after) -> counterexample (show (u, v, before, after)) (approxEqual before after)
        _ -> counterexample "undefined at the point" True

-- | The value of an RNE over 'Rational', 'Nothing' on division by zero.
referenceRNE :: Expr -> Maybe Rational
referenceRNE = \case
  Num n -> Just (toRational' n)
  App (Sym h) as
    | h == sPlus -> sum <$> traverse referenceRNE (V.toList as)
    | h == sTimes -> product <$> traverse referenceRNE (V.toList as)
    | h == sPower,
      [base', ex] <- V.toList as -> do
        b' <- referenceRNE base'
        e' <- referenceRNE ex
        let k = numerator e'
        if b' == 0 && k < 0 then Nothing else Just (b' ^^ k)
  _ -> Nothing

-- | Source: cohen2003 §3.1, Examples 3.22–3.25 (ASAEs, and expressions that
-- are not).
asaeExamples :: TestTree
asaeExamples =
  testGroup
    "Definition 3.21 (Examples 3.22–3.25)"
    [ testCase "3.22: 2·x·y·z² is an ASAE" $ isASAE (times [int 2, x, y, power z (int 2)]) @?= True,
      testCase "3.22: 2·(x·y)·z² violates ASAE-4-1" $ isASAE (times [int 2, times [x, y], power z (int 2)]) @?= False,
      testCase "3.22: 1·x·y·z² violates ASAE-4-1" $ isASAE (times [int 1, x, y, power z (int 2)]) @?= False,
      testCase "3.22: 2·x·y·z·z² violates ASAE-4-3" $ isASAE (times [int 2, x, y, z, power z (int 2)]) @?= False,
      testCase "3.23: 2x + 3y + 4z is an ASAE" $ isASAE (plus [times [int 2, x], times [int 3, y], times [int 4, z]]) @?= True,
      testCase "3.23: 1 + (x + y) + z violates ASAE-5-1" $ isASAE (plus [int 1, plus [x, y], z]) @?= False,
      testCase "3.23: 1 + 2 + x violates ASAE-5-2" $ isASAE (plus [int 1, int 2, x]) @?= False,
      testCase "3.23: 1 + x + 2x violates ASAE-5-3" $ isASAE (plus [int 1, x, times [int 2, x]]) @?= False,
      testCase "3.23: z + y + x violates ASAE-5-4" $ isASAE (plus [z, y, x]) @?= False,
      testCase "3.24: x², (1+x)³, 2^m, (x·y)^(1/2), (x^(1/2))^(1/2) are ASAEs" $
        map isASAE [power x (int 2), power (plus [int 1, x]) (int 3), power (int 2) (sym "m"), power (times [x, y]) half, power (power x half) half]
          @?= replicate 5 True,
      testCase "3.24: 2³, (x²)³, (x·y)², (1+x)¹, 1^m are not" $
        map isASAE [power (int 2) (int 3), power (power x (int 2)) (int 3), power (times [x, y]) (int 2), power (plus [int 1, x]) (int 1), power (int 1) (sym "m")]
          @?= replicate 5 False,
      testCase "3.25: n! and (-3)! are ASAEs, 3! is not" $
        map isASAE [factorial (sym "n"), factorial (int (-3)), factorial (int 3)] @?= [True, True, False]
    ]

-- | Source: cohen2003 §3.2: Examples 3.35, 3.36, 3.39–3.41 and 3.43, and the
-- examples under rule SPRD-4.
simplificationExamples :: TestTree
simplificationExamples =
  testGroup
    "§3.2 worked simplifications"
    [ testCase "3.35: ((x^(1/2))^(1/2))^8 → x²" $
        simplify (power (power (power x half) half) (int 8)) @?= Right (power x (int 2)),
      testCase "3.36: ((x·y)^(1/2)·z²)² → x·y·z⁴" $
        simplify (power (times [power (times [x, y]) half, power z (int 2)]) (int 2)) @?= Right (times [x, y, power z (int 4)]),
      testCase "3.39: Simplify_product_rec([a, a^-1]) → []" $
        simplifyProductRec [a, power a (int (-1))] @?= Right [],
      testCase "3.40: (2·a·c·e)·(3·b·d·e) → 6·a·b·c·d·e²" $
        simplify (times [times [int 2, a, c, e], times [int 3, b, d, e]]) @?= Right (times [int 6, a, b, c, d, power e (int 2)]),
      testCase "3.41: Simplify_product_rec([a·b, c, b]) → [a, b², c]" $
        simplifyProductRec [times [a, b], c, b] @?= Right [a, power b (int 2), c],
      testCase "3.43: (a·c·e)·(a·c^-1·d·f) → a²·d·e·f" $
        simplify (times [times [a, c, e], times [a, power c (int (-1)), d, f]]) @?= Right (times [power a (int 2), d, e, f]),
      testCase "SPRD-4-1: a^-1·b·a → b" $
        simplify (times [power a (int (-1)), b, a]) @?= Right b,
      testCase "SPRD-4-2: c·2·b·c·a → 2·a·b·c²" $
        simplify (times [c, int 2, b, c, a]) @?= Right (times [int 2, a, b, power c (int 2)]),
      testCase "milestone 1a: a + (b + a) → 2a + b" $
        simplify (plus [a, plus [b, a]]) @?= Right (plus [times [int 2, a], b]),
      testCase "0^-1 is undefined: division by zero" $ simplify (power (int 0) (int (-1))) @?= Left DivisionByZero,
      testCase "0^0 is undefined" $ simplify (power (int 0) (int 0)) @?= Left ZeroToZero,
      testCase "0^x stays, as in WL (a departure from SPOW-2)" $ simplify (power (int 0) x) @?= Right (power (int 0) x),
      testCase "a merged radical joins the coefficient: 3·2^(1/2)·2^(1/2) → 6" $
        simplify (times [int 3, power (int 2) half, power (int 2) half]) @?= Right (int 6)
    ]

half :: Expr
half = rat (1 % 2)

a, b, c, d, e, f, x, y, z :: Expr
a = sym "a"
b = sym "b"
c = sym "c"
d = sym "d"
e = sym "e"
f = sym "f"
x = sym "x"
y = sym "y"
z = sym "z"
