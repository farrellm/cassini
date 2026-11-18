{-# LANGUAGE PatternSynonyms #-}

-- | "Cassini.Simplify.Trig" and "Cassini.Simplify.Rational": Cohen's worked
-- examples from @references/papers/textbooks/cohen2002_*.pdf@ ch. 6–7, the
-- appraisal's limits as the contract, and §7.3's @Simplify.Trig@ rows
-- (DESIGN.md §4.12).
module Test.Cassini.Simplify.Trig (tests) where

import Cassini.Core.Expr (Expr, pattern Call)
import Cassini.Core.Symbol (sPlus, sTimes)
import Cassini.Simplify.Elementary (simplifyE)
import Cassini.Simplify.Trig (contractTrig, expandTrig, isTrigContracted, isTrigExpanded, simplifyTrig)
import Data.Text qualified as T
import Test.Gen (genTrig, genTrigQuotient, shrinkExpr)
import Test.Kernel (evalStd, ff)
import Test.Numeric (evalAt, genPoint)
import Test.QuickCheck (Property, counterexample, (.&&.), forAll, forAllShrink, sized, (===))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "Simplify.Trig"
    [ testGroup
        "Cohen §7.2's examples, the track's criterion (DESIGN.md §10)"
        [ row "Example 7.15: contraction gives 0" "TrigReduce[Plus[Power[Plus[Cos[x], Sin[x]], 4], Power[Plus[Cos[x], Times[-1, Sin[x]]], 4], Cos[Times[4, x]], -3]]" "0",
          row "Example 7.16: contraction gives 0" "TrigReduce[Plus[Sin[x], Sin[y], Times[-2, Sin[Plus[Times[Rational[1, 2], x], Times[Rational[1, 2], y]]], Cos[Plus[Times[Rational[1, 2], x], Times[Rational[-1, 2], y]]]]]]" "0",
          row "Example 7.17: expansion then contraction gives 0" "Simplify[Plus[Power[Sin[x], 3], Power[Cos[Plus[x, Times[Rational[1, 6], Pi]]], 3], Times[-1, Power[Sin[Plus[x, Times[Rational[1, 3], Pi]]], 3]], Times[Rational[3, 4], Sin[Times[3, x]]]]]" "0",
          -- Cohen's (3/4) sin x + (3/4) cos(x + π/6) − (3/4) sin(x + π/3), with
          -- sin(x + π/3) spelled cos(π/6 − x) by §4.11's periodicity rule.
          row "Example 7.17: contraction alone does not" "TrigReduce[Plus[Power[Sin[x], 3], Power[Cos[Plus[x, Times[Rational[1, 6], Pi]]], 3], Times[-1, Power[Sin[Plus[x, Times[Rational[1, 3], Pi]]], 3]], Times[Rational[3, 4], Sin[Times[3, x]]]]]" "Plus[Times[Rational[3, 4], Cos[Plus[Times[Rational[1, 6], Pi], x]]], Times[Rational[-3, 4], Cos[Plus[Times[Rational[1, 6], Pi], Times[-1, x]]]], Times[Rational[3, 4], Sin[x]]]",
          row "Example 7.18: the difference gives 0" "Simplify[Plus[Times[Plus[Sin[x], Sin[Times[3, x]], Sin[Times[5, x]], Sin[Times[7, x]]], Power[Plus[Cos[x], Cos[Times[3, x]], Cos[Times[5, x]], Cos[Times[7, x]]], -1]], Times[-1, Tan[Times[4, x]]]]]" "0",
          row "the appraisal: Example 7.18's left side alone is unchanged" "Simplify[Times[Plus[Sin[x], Sin[Times[3, x]], Sin[Times[5, x]], Sin[Times[7, x]]], Power[Plus[Cos[x], Cos[Times[3, x]], Cos[Times[5, x]], Cos[Times[7, x]]], -1]]]" "Times[Power[Plus[Cos[x], Cos[Times[3, x]], Cos[Times[5, x]], Cos[Times[7, x]]], -1], Plus[Sin[x], Sin[Times[3, x]], Sin[Times[5, x]], Sin[Times[7, x]]]]",
          -- 1 in value, but the two cosines' arguments are equal and spelled apart.
          row "the appraisal: differently spelled equal arguments are not seen" "Simplify[Plus[Power[Sin[Times[Plus[x, 1], Power[Plus[x, 2], -1]]], 2], Power[Cos[Times[Plus[1, Power[x, -1]], Power[Plus[1, Times[2, Power[x, -1]]], -1]]], 2]]]" "Plus[1, Times[Rational[1, 2], Cos[Plus[Times[2, Power[Plus[1, Times[2, Power[x, -1]]], -1]], Times[2, Power[Plus[1, Times[2, Power[x, -1]]], -1], Power[x, -1]]]]], Times[Rational[-1, 2], Cos[Plus[Times[2, Power[Plus[2, x], -1]], Times[2, x, Power[Plus[2, x], -1]]]]]]"
        ],
      testGroup
        "Cohen §7.1–7.2's other examples"
        [ row "(7.18): cos(5x) expanded" "TrigExpand[Cos[Times[5, x]]]" "Plus[Power[Cos[x], 5], Times[-10, Power[Cos[x], 3], Power[Sin[x], 2]], Times[5, Cos[x], Power[Sin[x], 4]]]",
          row "Example 7.6: sin(2(x + y))" "Simplify[Plus[TrigExpand[Sin[Times[2, Plus[x, y]]]], Times[-2, Plus[Times[Sin[x], Cos[y]], Times[Cos[x], Sin[y]]], Plus[Times[Cos[x], Cos[y]], Times[-1, Sin[x], Sin[y]]]]]]" "0",
          row "Example 7.13: sin²x cos²x" "TrigReduce[Times[Power[Sin[x], 2], Power[Cos[x], 2]]]" "Plus[Rational[1, 8], Times[Rational[-1, 8], Cos[Times[4, x]]]]",
          row "Example 7.14: cos⁴x" "TrigReduce[Power[Cos[x], 4]]" "Plus[Rational[3, 8], Times[Rational[1, 2], Cos[Times[2, x]]], Times[Rational[1, 8], Cos[Times[4, x]]]]",
          row "§7.2 Exercise 5: sin x cos²x cos 2x" "TrigReduce[Times[Sin[x], Power[Cos[x], 2], Cos[Times[2, x]]]]" "Plus[Times[Rational[1, 8], Sin[Times[3, x]]], Times[Rational[1, 8], Sin[Times[5, x]]]]",
          row "§7.2 Exercise 11(a): tan(x/2) − sin x/(1 + cos x)" "Simplify[Plus[Tan[Times[Rational[1, 2], x]], Times[-1, Sin[x], Power[Plus[1, Cos[x]], -1]]]]" "0",
          row "§7.2 Exercise 11(b): sin²(15π/16) + cos²(π/16) − 1" "Simplify[Plus[Power[Sin[Times[Rational[15, 16], Pi]], 2], Power[Cos[Times[Rational[1, 16], Pi]], 2], -1]]" "0",
          row "§7.1: 1/(sin 2x − 2 sin x cos x) is a zero denominator" "Simplify[Power[Plus[Sin[Times[2, x]], Times[-2, Sin[x], Cos[x]]], -1]]" "DirectedInfinity[]",
          row "§7.1: a zero over a zero is Indeterminate" "Simplify[Times[Plus[Sin[Times[2, x]], Times[-2, Sin[x], Cos[x]]], Power[Plus[Power[Sin[x], 2], Power[Cos[x], 2], -1], -1]]]" "Indeterminate",
          row "the hyperbolic pair contracts" "Simplify[Plus[Power[Cosh[x], 2], Times[-1, Power[Sinh[x], 2]]]]" "1",
          row "the hyperbolic addition formula" "TrigExpand[Sinh[Plus[x, y]]]" "Plus[Times[Cosh[y], Sinh[x]], Times[Cosh[x], Sinh[y]]]",
          row "nothing contracts a circular with a hyperbolic factor" "TrigReduce[Times[Sin[x], Sinh[y]]]" "Times[Sin[x], Sinh[y]]",
          row "D39: two spellings of one value are one" "Plus[Sin[Plus[x, Times[Rational[2, 3], Pi]]], Times[-1, Cos[Plus[x, Times[Rational[1, 6], Pi]]]]]" "0",
          row "Expand: (x + 1)²" "Expand[Power[Plus[1, x], 2]]" "Plus[1, Times[2, x], Power[x, 2]]",
          row "Expand: radicals merge" "Expand[Power[Plus[1, Power[2, Rational[1, 2]]], 2]]" "Plus[3, Times[2, Power[2, Rational[1, 2]]]]",
          row "Expand leaves function arguments alone" "Expand[Sin[Power[Plus[1, x], 2]]]" "Sin[Power[Plus[1, x], 2]]"
        ],
      testGroup
        "laws (§7.3)"
        [ testProperty "expandTrig's output is trig-expanded, idempotent and of equal value" $
            procedureLaw expandTrig isTrigExpanded,
          testProperty "contractTrig's output is trig-contracted, idempotent and of equal value" $
            procedureLaw contractTrig isTrigContracted,
          testProperty "simplifyTrig preserves value wherever the input is defined" $
            forAllShrink genTrigQuotient shrinkExpr $ \u ->
              forAll genPoint $ \pt -> case simplifyE u >>= simplifyTrig of
                Left _ -> counterexample "undefined" True
                Right v -> sameValue pt u v
        ]
    ]
  where
    row name i o = testCase name (evalStd [i] @?= o)

-- | A procedure's output is in its normal form, is a fixed point, and has
-- the input's value.
procedureLaw :: (Expr -> Either e Expr) -> (Expr -> Bool) -> Property
procedureLaw f normal =
  forAllShrink (sized genTrig) shrinkExpr $ \u ->
    forAll genPoint $ \pt -> case simplifyE u of
      Left _ -> counterexample "undefined" True
      Right u' -> case f u' of
        Left _ -> counterexample "undefined" True
        Right v ->
          counterexample (T.unpack (ff v)) $
            counterexample "not in normal form" (normal v)
              .&&. counterexample "not idempotent" (either (const False) (== v) (f v))
              .&&. counterexample "value changed" (sameValueB pt u' v)

sameValue :: Map Text Double -> Expr -> Expr -> Property
sameValue pt u v = counterexample (show (ff u, ff v)) (sameValueB pt u v === True)

-- | Equal values at a point, to a tolerance relative to the size of the
-- terms: an expansion of @Sinh[3 x]^3@ has terms near 10⁹ that cancel to
-- hundreds, and comparing the result alone would blame the algebra for
-- the floating point.
sameValueB :: Map Text Double -> Expr -> Expr -> Bool
sameValueB pt u v = case (evalAt pt u, evalAt pt v, magnitude u, magnitude v) of
  (Just a, Just b, Just mu, Just mv) ->
    let scale = max 1 (max mu mv)
     in scale > 1e12 || abs (a - b) <= 1e-9 * scale
  _ -> True
  where
    magnitude w = case w of
      Call p ts | p == sPlus -> sum <$> traverse magnitude ts
      Call t fs | t == sTimes -> product <$> traverse magnitude fs
      _ -> abs <$> evalAt pt w
