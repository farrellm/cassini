-- | The automatic-simplification benchmarks (DESIGN.md §8.4): sums and
-- products of 10, 100 and 1000 terms, with and without like terms, which
-- separates the cost of sorting from the cost of merging.
module Bench.Simplify (benchmarks) where

import Cassini.Core.Expr (Expr, apply, mkNumber, mkSymbol)
import Cassini.Core.Symbol (globalSymbol, sPower, sTimes)
import Cassini.Number (Number (NInt))
import Cassini.Simplify.Automatic (simplifyProduct, simplifySum)
import Data.Vector qualified as V
import Test.Tasty.Bench (Benchmark, bench, bgroup, env, nf)

benchmarks :: Benchmark
benchmarks =
  bgroup
    "Simplify"
    [ bgroup "sum" [sized simplifySum n | n <- sizes],
      bgroup "product" [sized simplifyProduct n | n <- sizes]
    ]
  where
    sizes = [10, 100, 1000]
    sized f n =
      bgroup
        (show n <> " terms")
        [ env (pure (distinct n)) $ \ts -> bench "distinct" $ nf (rightToMaybe . f) ts,
          env (pure (alike n)) $ \ts -> bench "like terms" $ nf (rightToMaybe . f) ts
        ]

-- | @n@ distinct terms @k·s_j@, in a scrambled order: all sorting, no
-- merging.
distinct :: Int -> V.Vector Expr
distinct n = V.fromList [term (toInteger (k `mod` 9 + 2)) (k * 7919 `mod` n) | k <- [1 .. n]]

-- | @n@ terms over five symbols: mostly merging.
alike :: Int -> V.Vector Expr
alike n = V.fromList [term (toInteger (k `mod` 9 + 2)) (k `mod` 5) | k <- [1 .. n]]

-- | @c·s_j^2@: a coefficient for sums to collect, a power for products to
-- merge.
term :: Integer -> Int -> Expr
term c j = apply sTimes [mkNumber (NInt c), apply sPower [mkSymbol (globalSymbol ("s" <> show j)), mkNumber (NInt 2)]]
