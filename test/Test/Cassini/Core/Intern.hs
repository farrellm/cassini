-- | "Cassini.Core.Intern" and the 'Eq' of "Cassini.Core.Expr.Internal": under
-- either setting of the @intern@ flag, '==' is structural equality and the hash
-- agrees with it (DESIGN.md §3.4, §7.3).
--
-- The one test module allowed to import the representation (§2.6, rule 4).
module Test.Cassini.Core.Intern (tests) where

import Cassini.Core.Expr (Expr, apply, mkSymbol)
import Cassini.Core.Expr.Internal (Expr (..), Shape (..))
import Cassini.Core.Symbol (Symbol, globalSymbol)
import Data.Functor.Foldable (cata, embed)
import Data.Hashable (hash)
import Data.Vector qualified as V
import Test.Gen (genExpr, genSubterm, shrinkExpr)
import Test.Tasty (TestTree, localOption, mkTimeout, testGroup)
import Test.Tasty.HUnit (assertBool, testCase)
import Test.Tasty.QuickCheck (Gen, Property, forAllShrink, liftShrink2, oneof, sized, testProperty, (===), (==>))

tests :: TestTree
tests =
  testGroup
    "Core.Intern"
    [ testProperty "== agrees with structural equality" $ forPair $ \x y -> (x == y) === refEq x y,
      testProperty "equal terms have equal hashes" $ forPair $ \x y -> x == y ==> hash x === hash y,
      testProperty "a rebuilt term is equal, with an equal hash" $ forOne $ \x ->
        let x' = rebuild x in (x' == x, hash x') === (True, hash x),
      -- Hash-only, both ids are 'notInterned'; interned, x is live while x' is
      -- built, so the table returns x's node.
      testProperty "a rebuilt term has the same id" $ forOne $ \x -> (rebuild x).exprId === x.exprId,
      -- Hash-only, every id is 'notInterned', so only the pointer test stops a
      -- structural walk of 2^200 nodes. A regression hangs, hence the timeout.
      -- The two sides are built apart, so the roots differ and the pointer test
      -- must answer below them, at t.
      localOption (mkTimeout 5_000_000) $
        testCase "terms sharing a self-shared subterm compare in time linear in nodes" $
          let t = tower 200
           in assertBool "f[t, t] == f[t, t]" (apply fSym [t, t] == pairApart t)
    ]
  where
    tower :: Int -> Expr
    tower n = foldl' (\u _ -> apply fSym [u, u]) (mkSymbol (globalSymbol "x")) [1 .. n]

fSym :: Symbol
fSym = globalSymbol "f"

-- | @f[t, t]@, opaque to the optimizer. Without @NOINLINE@, GHC shares it with
-- the other side of the comparison, and '==' answers from the pointer test at
-- the root.
pairApart :: Expr -> Expr
pairApart t = apply fSym [t, t]
{-# NOINLINE pairApart #-}

-- | Structural equality that looks at nothing the table maintains.
refEq :: Expr -> Expr -> Bool
refEq x y = case (x.exprShape, y.exprShape) of
  (SNumber a, SNumber b) -> a == b
  (SString a, SString b) -> a == b
  (SSymbol a, SSymbol b) -> a == b
  (SApp h as, SApp k bs) -> refEq h k && V.length as == V.length bs && V.and (V.zipWith refEq as bs)
  _ -> False

-- | The same term, built again node by node.
rebuild :: Expr -> Expr
rebuild = cata embed

gen :: Gen Expr
gen = sized (genExpr . min 30)

forOne :: (Expr -> Property) -> Property
forOne = forAllShrink gen shrinkExpr

-- | Pairs that are often equal: a term and its own subterm or rebuild, as well
-- as unrelated terms.
forPair :: (Expr -> Expr -> Property) -> Property
forPair f = forAllShrink genPair (liftShrink2 shrinkExpr shrinkExpr) (uncurry f)
  where
    genPair = do
      x <- gen
      y <- oneof [gen, genSubterm x, pure (rebuild x), rebuild <$> genSubterm x]
      pure (x, y)
