{-# LANGUAGE PatternSynonyms #-}

-- | "Cassini.Simplify.Elementary" and "Cassini.Simplify.Numeric"'s radicals:
-- WL 15.0.1's answers, Cohen's Fig. 7.9, §4.15's examples, and §7.3's
-- @Simplify.Elementary@ and @Simplify.Numeric@ rows (DESIGN.md §4.11,
-- §4.15).
module Test.Cassini.Simplify.Elementary (tests) where

import Cassini.Core.Expr (Expr, apply, pattern Call, pattern Int_, pattern Num, pattern Sym)
import Cassini.Core.Symbol (sPi, sPower, sTimes)
import Cassini.Number (Number (NInt, NRat))
import Cassini.Number.Integer (integerRoot)
import Cassini.Simplify.Elementary (Fn (..), fnOf, isElementaryNormal, simplifyE)
import Data.Ratio ((%))
import Data.Text qualified as T
import Test.Cassini.Simplify.ElementaryWL (periodicity, values)
import Test.Gen (genElementary, rat, shrinkExpr, subterms)
import Test.Kernel (eval, evalStd, ff, parse, std)
import Test.Numeric (approxEqual, evalAt, genPoint)
import Test.QuickCheck (Gen, Property, checkCoverage, chooseInteger, counterexample, cover, elements, forAll, forAllShrink, listOf1, sized, (.&&.), (===))
import Test.Tasty (TestName, TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "Simplify.Elementary"
    [ testGroup "WL 15.0.1: x + kπ/12 (D39)" (wl periodicity),
      testGroup "WL 15.0.1: values, parity, inverses" (wl values),
      fig79,
      radicals,
      logTwo,
      indeterminate,
      testGroup
        "laws (§7.3)"
        [ testProperty "simplifyE u is elementary-normal, or undefined" $
            checkCoverage $
              forAllShrink (sized (genElementary . min 30)) shrinkExpr $ \u ->
                covered u $ case simplifyE u of
                  Left _ -> counterexample "undefined" True
                  Right v -> counterexample (T.unpack (ff v)) (isElementaryNormal v),
          testProperty "for elementary-normal u, simplifyE u is u" $
            forAllShrink (sized (genElementary . min 30)) shrinkExpr $ \u -> case simplifyE u of
              Left _ -> counterexample "undefined" True
              Right v -> simplifyE v === Right v,
          testProperty "simplifyE preserves numeric value" valuePreserved,
          testProperty "the evaluator and simplifyE agree" evaluatorAgrees,
          testProperty "radical normalization preserves value and is idempotent" radicalValue,
          testProperty "equal products of rationals and prime radicals normalize identically" radicalCanonical,
          testProperty "integerRoot n b is exact exactly on perfect powers" $
            forAll (chooseInteger (0, 5000)) $ \m -> forAll (chooseInteger (1, 5)) $ \b ->
              integerRoot (m ^ b) b === Just m
                .&&. counterexample "m^b + 1" (b < 2 || m < 1 || isNothing (integerRoot (m ^ b + 1) b))
        ]
    ]

-- | Each pair as one unit test: the input evaluates to WL's answer.
wl :: [(Text, Text)] -> [TestTree]
wl = map (\(i, o) -> testCase (T.unpack i) (evalStd [i] @?= o))

-- | Cohen's Fig. 7.9 (@references/papers/textbooks/cohen2002_*.pdf@ §7.2),
-- with the column each row reproduces (§4.11).
fig79 :: TestTree
fig79 =
  testGroup
    "Cohen Fig. 7.9"
    [ row "sin(π/3), every column" "Sin[Times[Rational[1, 3], Pi]]" "Times[Rational[1, 2], Power[3, Rational[1, 2]]]",
      row "sin(−x), every column" "Sin[Times[-1, x]]" "Times[-1, Sin[x]]",
      row "sin(1 − x), Mathematica's" "Sin[Plus[1, Times[-1, x]]]" "Sin[Plus[1, Times[-1, x]]]",
      row "sin(−1 + x), Mathematica's" "Sin[Plus[-1, x]]" "Times[-1, Sin[Plus[1, Times[-1, x]]]]",
      row "sin(15π/16), MPL's" "Sin[Times[Rational[15, 16], Pi]]" "Sin[Times[Rational[1, 16], Pi]]",
      row "sin(x + 2π/3), MPL's (D39: WL 15.0.1's)" "Sin[Plus[x, Times[Rational[2, 3], Pi]]]" "Cos[Plus[Times[Rational[1, 6], Pi], x]]",
      row "sin(x + π/2 + y), MPL's" "Sin[Plus[x, Times[Rational[1, 2], Pi], y]]" "Cos[Plus[x, y]]",
      row "cos(x + 2π), every column" "Cos[Plus[x, Times[2, Pi]]]" "Cos[x]",
      row "sin(x)/cos(x), MPL's: no function transformations (D16)" "Times[Sin[x], Power[Cos[x], -1]]" "Times[Power[Cos[x], -1], Sin[x]]"
    ]

-- | The two-argument @Log@ (§4.11): a definition, and its exact cases.
logTwo :: TestTree
logTwo =
  testGroup
    "Log[b, z] (§4.11)"
    [ row "is Log[z]/Log[b] (wolfram/Log/PossibleIssues/1)" "Log[b, z]" "Times[Power[Log[b], -1], Log[z]]",
      row "an exact integer power (WL 15.0.1)" "Log[10, 1000]" "3",
      row "a power of a common root (WL 15.0.1)" "Log[4, 8]" "Rational[3, 2]",
      row "a written power of a positive base (wolfram/Log/Scope/SpecificValues/1)" "Log[Pi, Power[Pi, Rational[1, 2]]]" "Rational[1, 2]",
      row "a reciprocal power" "Log[8, Rational[1, 2]]" "Rational[-1, 3]",
      row "a rational base below 1 (WL 15.0.1)" "Log[Rational[1, 2], Rational[1, 8]]" "3",
      row "a radical base (WL 15.0.1)" "Log[Power[2, Rational[1, 2]], Rational[1, 2]]" "-2",
      row "a product of radicals over a coprime basis" "Log[Times[3, Power[2, Rational[1, 2]]], 18]" "2",
      -- WL 15.0.1 gives these as equal quotients, Log[2 Sqrt[2]]/Log[2] and
      -- 2 Log[8]/Log[2]: it reduces a radical case only where the two
      -- logarithms cancel, and §4.11 reduces every one
      row "a radical argument, where WL leaves a quotient" "Log[2, Power[8, Rational[1, 2]]]" "Rational[3, 2]",
      row "a radical base, where WL leaves a quotient" "Log[Power[2, Rational[1, 2]], 8]" "6",
      row "no rational power stays a quotient (WL 15.0.1)" "Log[6, Times[2, Power[3, Rational[1, 2]]]]" "Times[Power[Log[6], -1], Log[Times[2, Power[3, Rational[1, 2]]]]]",
      row "a negative base stays a quotient (WL 15.0.1)" "Log[-2, 4]" "Times[Power[Log[-2], -1], Log[4]]",
      row "base E is the one-argument Log (wolfram/Log/Scope/FunctionProperties/1)" "Log[E, z]" "Log[z]",
      -- Log[x^2] is not 2 Log[x] at x = -1, so x^2 is not read as a power of x
      row "a symbolic base with an exponent outside (-1, 1] stays a quotient" "Log[x, Power[x, 2]]" "Times[Power[Log[x], -1], Log[Power[x, 2]]]",
      row "a symbolic base with an exponent inside (-1, 1] reduces" "Log[x, Power[x, Rational[1, 2]]]" "Rational[1, 2]",
      row "base 1 divides by zero (WL 15.0.1: ComplexInfinity)" "Log[1, 2]" "DirectedInfinity[]",
      row "Log[1, 1] is 0/0 (WL 15.0.1: Indeterminate)" "Log[1, 1]" "Indeterminate",
      row "Log[b, 0] for a base above 1 is -Infinity (WL 15.0.1)" "Log[3, 0]" "DirectedInfinity[-1]",
      row "Log[b, 0] for a base in (0, 1) is Infinity (WL 15.0.1)" "Log[Rational[1, 3], 0]" "DirectedInfinity[1]",
      -- WL 15.0.1 gives -Infinity/Log[x]; until the infinity pass (§4.15),
      -- leaving it is the one answer that is not wrong for some x
      row "Log[b, 0] for a base of unknown sign stays" "Log[x, 0]" "Log[x, 0]"
    ]

-- | §4.15's worked examples of radical normalization.
radicals :: TestTree
radicals =
  testGroup
    "radicals (§4.15)"
    [ row "a perfect square" "Power[4, Rational[1, 2]]" "2",
      row "a perfect power with a remainder" "Power[4, Rational[1, 3]]" "Power[2, Rational[2, 3]]",
      row "the first prime exponent, then again" "Power[64, Rational[1, 3]]" "4",
      row "a perfect-power factor" "Power[8, Rational[1, 2]]" "Times[2, Power[2, Rational[1, 2]]]",
      row "the integer part of the exponent" "Power[2, Rational[3, 2]]" "Times[2, Power[2, Rational[1, 2]]]",
      row "truncated toward zero" "Power[2, Rational[-3, 2]]" "Times[Rational[1, 2], Power[2, Rational[-1, 2]]]",
      row "a negative base" "Power[Rational[-1, 2], Rational[1, 2]]" "Times[Power[-1, Rational[1, 2]], Power[2, Rational[-1, 2]]]",
      row "-1 alone" "Power[-1, Rational[3, 2]]" "Times[-1, Power[-1, Rational[1, 2]]]",
      -- The design's answer, step 2; WL 15.0.1 keeps Sqrt[2/3] whole (D49).
      row "a fraction" "Power[Rational[2, 3], Rational[1, 2]]" "Times[Power[2, Rational[1, 2]], Power[3, Rational[-1, 2]]]",
      row "the coefficient merges: Sqrt[2]/2" "Times[Rational[1, 2], Power[2, Rational[1, 2]]]" "Power[2, Rational[-1, 2]]",
      row "Sqrt[3]/3" "Times[Rational[1, 3], Power[3, Rational[1, 2]]]" "Power[3, Rational[-1, 2]]",
      row "Sqrt[3]/2 is a fixed point" "Times[Rational[1, 2], Power[3, Rational[1, 2]]]" "Times[Rational[1, 2], Power[3, Rational[1, 2]]]",
      row "2 Sqrt[2] is a fixed point" "Times[2, Power[2, Rational[1, 2]]]" "Times[2, Power[2, Rational[1, 2]]]",
      row "two distinct primes are not split" "Times[Rational[1, 2], Power[6, Rational[1, 2]]]" "Times[Rational[1, 2], Power[6, Rational[1, 2]]]",
      row "ArcSin reaches its table through Sqrt[2]/2" "ArcSin[Times[Rational[1, 2], Power[2, Rational[1, 2]]]]" "Times[Rational[1, 4], Pi]",
      row "E^(c Log[z]) is z^c" "Power[E, Times[3, Log[z]]]" "Power[z, 3]"
    ]

-- | One input evaluated, against its FullForm.
-- | Every NumericFunction head this layer rewrites is Indeterminate of an
-- Indeterminate argument, as the evaluator makes it before the rule runs.
indeterminate :: TestTree
indeterminate =
  testGroup
    "a NumericFunction of Indeterminate, as the evaluator's (§4.4)"
    [ testCase (T.unpack i) ((ff <$> simplifyE (parse i)) @?= Right (evalStd [i]))
    | i <- ["Plus[Indeterminate, x]", "Divide[x, Indeterminate]", "Subtract[Indeterminate, x]", "Minus[Indeterminate]"]
    ]

row :: TestName -> Text -> Text -> TestTree
row name i o = testCase name (evalStd [i] @?= o)

valuePreserved :: Property
valuePreserved =
  forAllShrink (sized (genElementary . min 30)) shrinkExpr $ \u ->
    forAll genPoint $ \pt -> case simplifyE u of
      Left _ -> counterexample "undefined" True
      Right v -> case (evalAt pt u, evalAt pt v) of
        (Just before, Just after) -> counterexample (show (ff u, ff v, before, after)) (approxEqual before after)
        _ -> counterexample "undefined at the point" True

-- | The evaluator's built-ins and 'simplifyE' compute one normal form
-- (§4.11), wherever 'simplifyE' is defined.
evaluatorAgrees :: Property
evaluatorAgrees =
  checkCoverage $ forAllShrink (sized (genElementary . min 30)) shrinkExpr $ \u -> covered u $ case simplifyE u of
    Left _ -> counterexample "undefined" True
    Right v -> ff (fst (eval std u)) === ff v

-- | The laws are not vacuous: most inputs are defined, and a good share
-- reach each family of rules.
covered :: Expr -> Property -> Property
covered u =
  cover 60 (isRight r) "defined"
    . cover 10 (any isPiReduction nodes) "a reduction of a π multiple"
    . cover 10 (any isParity nodes) "parity"
    . cover 5 (any isInverse nodes) "an inverse head"
    . cover 5 (any isRadical nodes) "a radical of a number"
  where
    r = simplifyE u
    nodes = u : subterms u
    elementaryArg = \case
      Call f [a] | isJust (fnOf f) -> Just a
      _ -> Nothing
    isPiReduction n = maybe False (any isPi . (\a -> a : subterms a)) (elementaryArg n)
    isPi = \case
      Sym p -> p == sPi
      _ -> False
    isParity n = case elementaryArg n of
      Just (Call t (Num c : _)) -> t == sTimes && c < NInt 0
      Just (Num c) -> c < NInt 0
      _ -> False
    isInverse = \case
      Call f [_] -> fnOf f `elem` map Just [ArcSin, ArcCos, ArcTan, ArcCot, ArcSec, ArcCsc]
      _ -> False
    isRadical = \case
      Call p [Num _, Num (NRat _)] -> p == sPower
      _ -> False

-- | A product of a rational and radicals of small numbers.
genRadicalProduct :: Gen Expr
genRadicalProduct = do
  c <- rat <$> ((%) <$> chooseInteger (-12, 12) <*> chooseInteger (1, 12))
  rs <- listOf1 ((,) <$> elements [2, 3, 4, 5, 8, 9, 12, 27, 1 % 2, 2 % 3, -2, -3] <*> elements [1 % 2, -(1 % 2), 3 % 2, 1 % 3, 2 % 3, -(5 % 2)])
  pure (apply sTimes (c : [apply sPower [rat b, rat e] | (b, e) <- take 3 rs]))

radicalValue :: Property
radicalValue =
  forAll genRadicalProduct $ \u -> case simplifyE u of
    Left _ -> counterexample "undefined" True
    Right v ->
      counterexample (show (ff u, ff v)) $
        simplifyE v == Right v && case (evalAt mempty u, evalAt mempty v) of
          (Just a, Just b) -> approxEqual a b
          _ -> True

-- | One number spelled two ways, @c·p^e@ and @(c·p^k)·p^(e-k)@ for primes
-- below the bound, normalizes to one expression.
radicalCanonical :: Property
radicalCanonical =
  forAll (listOf1 ((,,) <$> elements [2, 3, 5, 7] <*> elements [1 % 2, -(1 % 2), 1 % 3, 2 % 3, 3 % 4, -(5 % 3)] <*> chooseInteger (-3, 3))) $ \fs ->
    forAll ((%) <$> chooseInteger (1, 30) <*> chooseInteger (1, 30)) $ \c ->
      let one = apply sTimes (rat c : [apply sPower [Int_ p, rat e] | (p, e, _) <- take 3 fs])
          shifted = apply sTimes (rat (c * product [fromInteger p ^^ k | (p, _, k) <- take 3 fs]) : [apply sPower [Int_ p, rat (e - fromInteger k)] | (p, e, k) <- take 3 fs])
       in counterexample (show (ff one, ff shifted)) (simplifyE one === simplifyE shifted)
