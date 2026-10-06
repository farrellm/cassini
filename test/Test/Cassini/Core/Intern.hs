-- | "Cassini.Core.Intern" and the 'Eq' of "Cassini.Core.Expr.Internal": under
-- either setting of the @intern@ flag, '==' is structural equality and the hash
-- agrees with it (DESIGN.md §3.4, §7.3).
--
-- The one test module allowed to import the representation (§2.6, rule 4).
module Test.Cassini.Core.Intern (tests) where

import Cassini.Core.Expr (Expr, apply, mkSymbol)
import Cassini.Core.Expr.Internal (Expr (..), Shape (..))
import Cassini.Core.Symbol (globalSymbol)
import Data.Functor.Foldable (cata, embed)
import Data.Hashable (hash)
import Data.Vector qualified as V
import Test.Gen (genExpr, genSubterm, shrinkExpr)
import Test.Tasty (TestTree, localOption, mkTimeout, testGroup)
import Test.Tasty.HUnit (assertBool, testCase)
import Test.Tasty.QuickCheck (Gen, Property, forAllShrink, oneof, sized, testProperty, (===), (==>))

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
      localOption (mkTimeout 5_000_000) $
        testCase "terms sharing a self-shared subterm compare in time linear in nodes" $
          let t = tower 200
           in assertBool "f[t, t] == f[t, t]" (apply f [t, t] == apply f [t, t])
    ]
  where
    f = globalSymbol "f"
    tower :: Int -> Expr
    tower n = foldl' (\u _ -> apply f [u, u]) (mkSymbol (globalSymbol "x")) [1 .. n]

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
forPair f = forAllShrink genPair shrinkPair (uncurry f)
  where
    genPair = do
      x <- gen
      y <- oneof [gen, genSubterm x, pure (rebuild x), rebuild <$> genSubterm x]
      pure (x, y)
    shrinkPair (x, y) = [(x', y) | x' <- shrinkExpr x] ++ [(x, y') | y' <- shrinkExpr y]
