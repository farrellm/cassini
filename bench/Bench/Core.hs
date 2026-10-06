-- | The core benchmarks, which decide interning (DESIGN.md §8.2). Run the
-- same suite with the @intern@ flag on and off for the A/B.
module Bench.Core (benchmarks) where

import Cassini.Core.Expr (Expr, apply, mkNumber, mkSymbol)
import Cassini.Core.Order (compareCanonical)
import Cassini.Core.Symbol (globalSymbol, sPlus, sPower, sTimes)
import Cassini.Number (Number (NInt))
import Cassini.Structure (substitute)
import Test.Tasty.Bench (Benchmark, bench, bgroup, env, nf, whnf)

benchmarks :: Benchmark
benchmarks =
  bgroup
    "Core"
    [ bgroup
        "construct"
        [bench ("tree depth " <> show d) $ nf tree d | d <- [10, 14]],
      bgroup
        "equality"
        [ env (pure (tree 14, treeApart 14)) $ \ ~(u, v) ->
            bench "equal, built apart" $ whnf (uncurry (==)) (u, v),
          env (pure (tree 14, treeWithLeaf (int 1) 14)) $ \ ~(u, v) ->
            bench "differing at the last leaf" $ whnf (uncurry (==)) (u, v)
        ],
      bgroup
        "compareCanonical"
        [ env (pure (chain d (sym "x"), chain d (sym "y"))) $ \ ~(u, v) ->
            bench ("depth " <> show d) $ whnf (uncurry compareCanonical) (u, v)
        | d <- [10, 100, 1000]
        ],
      bgroup
        "sortBy compareCanonical"
        [ env (pure (scrambled n)) $ \xs ->
            bench (show n <> " arguments") $ nf (sortBy compareCanonical) xs
        | n <- [10, 100, 1000]
        ],
      env (pure (tree 14)) $ \u ->
        bench "substitute, deep tree" $ nf (substitute u (sym "x")) (sym "z"),
      bgroup
        "expression swell"
        [bench ("(a+b+c+d)^" <> show n) $ nf swell n | n <- [10, 20, 30]]
    ]

sym :: Text -> Expr
sym = mkSymbol . globalSymbol

int :: Integer -> Expr
int = mkNumber . NInt

-- | A complete binary tree of @f@ and @g@ nodes, with @2^d@ leaves, built
-- node by node. Every leaf is @x@, so the tree repeats subterms as real
-- expressions do.
tree :: Int -> Expr
tree = treeWithLeaf (sym "x")

-- | 'tree', built again. Without @NOINLINE@, GHC shares @tree 14@ between the
-- two halves of a pair, and '==' answers from the pointer test (§3.4).
treeApart :: Int -> Expr
treeApart = tree
{-# NOINLINE treeApart #-}

-- | 'tree' with its rightmost leaf replaced, so it differs from 'tree' only
-- at the last leaf.
treeWithLeaf :: Expr -> Int -> Expr
treeWithLeaf l d
  | d <= 0 = l
  | otherwise = apply (globalSymbol (if even d then "f" else "g")) [tree (d - 1), treeWithLeaf l (d - 1)]

-- | @f[f[…f[leaf]…]]@, @d@ deep: two of these differ only at the bottom.
chain :: Int -> Expr -> Expr
chain d leaf = foldl' (\e _ -> apply (globalSymbol "f") [e]) leaf [1 .. d]

-- | @n@ distinct monomials, in a deterministic non-sorted order.
scrambled :: Int -> [Expr]
scrambled n =
  [ monomial (fromIntegral (k * 7919 `mod` 97)) (k `mod` 5) (k `mod` 7) ((k * 31) `mod` 11) (k `mod` 3)
  | k <- [1 .. n]
  ]

-- | @c a^i b^j c^k d^l@.
monomial :: Integer -> Int -> Int -> Int -> Int -> Expr
monomial c i j k l =
  apply sTimes $
    int c : [apply sPower [sym v, int (fromIntegral e)] | (v, e) <- [("a", i), ("b", j), ("c", k), ("d", l)], e > 0]

-- | The expanded form of @(a+b+c+d)^n@, built directly with the smart
-- constructors since @Expand@ does not exist yet: a sum of multinomial terms.
swell :: Int -> Expr
swell n =
  apply
    sPlus
    [ monomial (multinomial [i, j, k, l]) i j k l
    | i <- [0 .. n],
      j <- [0 .. n - i],
      k <- [0 .. n - i - j],
      let l = n - i - j - k
    ]
  where
    multinomial es = factorial (sum es) `div` product (map factorial es)
    factorial m = product [1 .. toInteger m]
