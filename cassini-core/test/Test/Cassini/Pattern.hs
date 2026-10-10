{-# LANGUAGE PatternSynonyms #-}

-- | §7.3's @Pattern@ rows, over every matcher (DESIGN.md §4.5): patterns
-- derived from subjects, with sequence blanks, under heads that are
-- @Orderless@, @Flat@, both (@Plus@, @Times@) or neither.
module Test.Cassini.Pattern (tests) where

import Cassini.Attributes (isFlat, isOrderless)
import Cassini.Core.Expr (Expr, apply, mkApp, mkSymbol, pattern App, pattern Sym)
import Cassini.Core.Order (compareCanonical)
import Cassini.Core.Symbol (globalSymbol, sPattern, sSequence)
import Cassini.Eval.Kernel (KernelState (..))
import Cassini.Pattern (Binding (..), Subst)
import Cassini.Pattern.Match (matchAll, matchOne)
import Cassini.Pattern.Net qualified as Net
import Cassini.Rules (SymbolInfo (..))
import Data.Map.Strict qualified as Map
import Data.Sequence qualified as Seq
import Data.Vector qualified as V
import Test.Gen (genExpr, genPattern, shrinkExpr)
import Test.Kernel (ff, run, stateWith)
import Test.QuickCheck (Gen, chooseInt, elements, listOf1, vectorOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.QuickCheck (counterexample, forAll, forAllShrink, sized, testProperty, (===))

tests :: TestTree
tests =
  testGroup
    "Pattern"
    [ testProperty "completeness: a pattern derived from a subject matches it" $
        forAllShrink (sized genSubject) shrinkExpr $ \s ->
          forAll (genPattern s) $ \p ->
            counterexample (toString (ff p)) (not (null (matchesOf p s))),
      testProperty "soundness: every match instantiates the pattern to the subject, modulo attributes" $
        forAllShrink (sized genSubject) shrinkExpr $ \s ->
          forAll (genPattern s) $ \p ->
            counterexample (toString (ff p)) $
              all (\sigma -> normalize (instantiate sigma p) == normalize s) (matchesOf p s),
      testProperty "matchOne is the first of matchAll" $
        forAllShrink (sized genSubject) shrinkExpr $ \s ->
          forAll (genPattern s) $ \p ->
            rightToMaybe (fst (run patternState (matchOne p s))) === (listToMaybe <$> rightToMaybe (fst (run patternState (matchAll p s)))),
      testProperty "the rule index is a superset of the matching rules, in table order" $
        forAllShrink (sized genApplication) shrinkExpr $ \t ->
          forAll (listOf1 (sized genApplication >>= genPattern)) $ \ps ->
            let matching = filter (\p -> not (null (matchesOf p t)))
             in matching (Net.candidates (Net.fromSeq id (Seq.fromList ps)) t) === matching ps,
      testProperty "matching leaves the kernel state unchanged" $
        forAllShrink (sized genSubject) shrinkExpr $ \s ->
          forAll (genPattern s) $ \p ->
            let st' = snd (run patternState (matchAll p s))
             in show @Text (Map.toList st'.ksSymbols) === show (Map.toList patternState.ksSymbols)
    ]

-- | The standard kernel with an @Orderless@ head and a @Flat@ one, beside
-- @Plus@ and @Times@, which are both.
patternState :: KernelState
patternState = stateWith ["SetAttributes[o, Orderless]", "SetAttributes[fl, Flat]"]

-- | A generated expression whose plain function heads @f@ and @g@ become
-- @o@ and @fl@ some of the time, so every combination of the two
-- attributes is matched under.
genSubject :: Int -> Gen Expr
genSubject n = genExpr n >>= go
  where
    go = \case
      App h as -> do
        h' <- case h of
          Sym f | f == globalSymbol "f" -> elements [h, mkSymbol (globalSymbol "o")]
          Sym f | f == globalSymbol "g" -> elements [h, mkSymbol (globalSymbol "fl")]
          _ -> go h
        mkApp h' <$> V.mapM go as
      e -> pure e

-- | @f[a, b]@ for a plain @f@: the rule index's domain, a downvalue of a
-- head with neither @Orderless@ nor @Flat@.
genApplication :: Int -> Gen Expr
genApplication n = do
  k <- chooseInt (0, 3)
  args <- vectorOf k (genSubject (n `div` max 1 k))
  pure (mkApp (mkSymbol (globalSymbol "f")) (V.fromList args))

matchesOf :: Expr -> Expr -> [Subst]
matchesOf p s = fromRight [] (fst (run patternState (matchAll p s)))

-- | Replace each named pattern by its binding, a sequence spliced into its
-- argument list: the pattern as the match reads it.
instantiate :: Subst -> Expr -> Expr
instantiate sigma = go
  where
    go e = case binding e of
      Just (BOne v) -> v
      Just (BSeq xs) -> apply sSequence (V.toList xs)
      Nothing -> case e of
        App h as -> mkApp (go h) (V.fromList (concatMap spliced (V.toList as)))
        _ -> e
    spliced a = case binding a of
      Just (BSeq xs) -> V.toList xs
      _ -> [go a]
    binding = \case
      App (Sym h) as | h == sPattern, Just (Sym x) <- as V.!? 0 -> Map.lookup x sigma
      _ -> Nothing

-- | Flatten @Flat@ heads and sort @Orderless@ ones, bottom up: equal up to
-- the attributes the matcher reads.
normalize :: Expr -> Expr
normalize = \case
  App h as ->
    let h' = normalize h
        as' = map normalize (V.toList as)
        attrs = case h' of
          Sym f -> maybe mempty (.siAttributes) (Map.lookup f patternState.ksSymbols)
          _ -> mempty
        flat = if isFlat attrs then concatMap (\a -> case a of App ah aas | ah == h' -> V.toList aas; _ -> [a]) as' else as'
     in mkApp h' (V.fromList (if isOrderless attrs then sortBy compareCanonical flat else flat))
  e -> e
