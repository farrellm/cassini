{-# LANGUAGE PatternSynonyms #-}

-- | "Cassini.Pattern.Syntactic", through "Cassini.Pattern.Match": unit cases
-- for each pattern object, and §7.3's matcher laws over syntactic patterns.
module Test.Cassini.Pattern.Syntactic (tests) where

import Cassini.Core.Expr (Expr, mkApp, pattern App, pattern Sym)
import Cassini.Core.Symbol (sPattern)
import Cassini.Eval.Kernel (KernelState (..))
import Cassini.Pattern (Binding (..), Subst)
import Cassini.Pattern.Match (matchAll, matchOne)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V
import Test.Gen (genExpr, genPattern, shrinkExpr)
import Test.Kernel (evalStd, ff, parse, run, std)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (counterexample, forAll, forAllShrink, sized, testProperty, (===))

tests :: TestTree
tests =
  testGroup
    "Pattern.Syntactic"
    [ testGroup
        "pattern objects"
        [ testCase "a blank matches anything" $ matches "Blank[]" "f[x]" @?= 1,
          testCase "a head constraint" $ (matches "Blank[Integer]" "3", matches "Blank[Integer]" "x") @?= (1, 0),
          testCase "a repeated name means one value" $
            (matches "f[Pattern[x, Blank[]], Pattern[x, Blank[]]]" "f[1, 1]", matches "f[Pattern[x, Blank[]], Pattern[x, Blank[]]]" "f[1, 2]") @?= (1, 0),
          testCase "a literal matches only itself" $ (matches "f[a]" "f[a]", matches "f[a]" "f[b]") @?= (1, 0),
          testCase "arities must agree: no sequence matching yet (1b)" $ matches "f[Blank[]]" "f[a, b]" @?= 0,
          testCase "alternatives enumerate every branch" $
            matches "Alternatives[Pattern[x, Blank[]], Pattern[y, Blank[]]]" "a" @?= 2,
          testCase "a condition admits only True" $
            ( evalStd ["Set[isOne[1], True]", "SetDelayed[f[Condition[Pattern[x, Blank[]], isOne[x]]], \"one\"]", "List[f[1], f[2]]"],
              matches "Condition[Pattern[x, Blank[]], True]" "a",
              matches "Condition[Pattern[x, Blank[]], x]" "a"
            )
              @?= ("List[\"one\", f[2]]", 1, 0),
          testCase "a pattern test applies its function" $
            evalStd ["SetDelayed[t[Blank[]], True]", "SetDelayed[f[PatternTest[Pattern[x, Blank[]], t]], \"yes\"]", "f[1]"] @?= "\"yes\"",
          testCase "except" $
            (matches "Except[a]" "b", matches "Except[a]" "a", matches "Except[a, Blank[Integer]]" "2", matches "Except[2, Blank[Integer]]" "2") @?= (1, 0, 1, 0),
          testCase "HoldPattern matches as its argument does" $ matches "HoldPattern[Plus[Blank[], Blank[]]]" "Plus[a, b]" @?= 1,
          testCase "Verbatim matches blanks literally" $
            (matches "Verbatim[Blank[]]" "Blank[]", matches "Verbatim[Blank[]]" "a") @?= (1, 0),
          testCase "a curried pattern" $ matches "Pattern[h, Blank[]][Pattern[x, Blank[]]]" "f[1][2]" @?= 1
        ],
      testGroup
        "laws"
        [ testProperty "completeness: a pattern derived from a subject matches it" $
            forAllShrink (sized genExpr) shrinkExpr $ \s ->
              forAll (genPattern s) $ \p ->
                counterexample (toString (ff p)) (not (null (matchesOf p s))),
          testProperty "soundness: every match instantiates the pattern to the subject" $
            forAllShrink (sized genExpr) shrinkExpr $ \s ->
              forAll (genPattern s) $ \p ->
                all (\sigma -> instantiate sigma p == s) (matchesOf p s),
          testProperty "matchOne is the first of matchAll" $
            forAllShrink (sized genExpr) shrinkExpr $ \s ->
              forAll (genPattern s) $ \p ->
                rightToMaybe (fst (run std (matchOne p s))) === (listToMaybe <$> rightToMaybe (fst (run std (matchAll p s)))),
          testProperty "matching leaves the kernel state unchanged" $
            forAllShrink (sized genExpr) shrinkExpr $ \s ->
              forAll (genPattern s) $ \p ->
                let st' = snd (run std (matchAll p s))
                 in show @Text (Map.toList st'.ksSymbols) === show (Map.toList std.ksSymbols)
        ]
    ]
  where
    matches p s = length (matchesOf (parse p) (parse s))

matchesOf :: Expr -> Expr -> [Subst]
matchesOf p s = fromRight [] (fst (run std (matchAll p s)))

-- | Replace each named pattern by its binding: the pattern as the match
-- reads it.
instantiate :: Subst -> Expr -> Expr
instantiate sigma = go
  where
    go e = case e of
      App (Sym h) as
        | h == sPattern,
          Just (Sym x) <- as V.!? 0,
          Just (BOne v) <- Map.lookup x sigma ->
            v
      App h as -> mkApp (go h) (V.map go as)
      _ -> e
