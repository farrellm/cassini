{-# LANGUAGE PatternSynonyms #-}

-- | "Cassini.Core.Traversal": folds rebuild through the smart constructors
-- (DESIGN.md §3.6, §7.3).
module Test.Cassini.Core.Traversal (tests) where

import Cassini.Core.Expr (pattern Sym)
import Cassini.Core.Symbol (globalSymbol)
import Cassini.Core.Traversal (rewriteM)
import Data.Functor.Foldable (cata, embed)
import Test.Gen
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (forAllShrink, sized, testProperty, (===))

tests :: TestTree
tests =
  testGroup
    "Core.Traversal"
    [ testProperty "cata embed ≡ id" $
        forAllShrink (sized (genExpr . min 30)) shrinkExpr $
          \x -> cata embed x === x,
      testCase "rewriteM rewrites to a fixed point, children first" $
        -- x -> y, then y -> z: every x ends as z, heads included.
        runIdentity (rewriteM step (fn "x" [sym "x", plus [sym "y", sym "a"]]))
          @?= fn "z" [sym "z", plus [sym "z", sym "a"]]
    ]
  where
    step = \case
      Sym s
        | s == globalSymbol "x" -> pure (Just (sym "y"))
        | s == globalSymbol "y" -> pure (Just (sym "z"))
      _ -> pure Nothing
