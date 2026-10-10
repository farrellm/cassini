-- | The evaluator benchmarks (DESIGN.md §8.4): fixed points needing 1, 5
-- and 20 rounds. Every round re-evaluates what is already settled (D14), so
-- this is where re-evaluation first shows.
--
-- The state is built by the partially applied evaluator, once, on the first
-- iteration: a 'KernelState' holds functions and has no 'NFData' for 'env'.
module Bench.Eval (benchmarks) where

import Cassini.Builtins (standardState)
import Cassini.Core.Expr (Expr, apply, mkSymbol)
import Cassini.Core.Symbol (globalSymbol, sPlus, systemSymbol)
import Cassini.Eval (evaluateTop, runEvalPure)
import Cassini.Eval.Kernel (KernelState, defaultConfig)
import Effectful (runPureEff)
import Test.Tasty.Bench (Benchmark, bench, bgroup, nf)

benchmarks :: Benchmark
benchmarks =
  bgroup
    "Eval"
    [ bgroup
        "fixed point"
        [ bench (show k <> " rounds") $ nf (evaluateIn (chainState k)) (link 0 `plus` link 0)
        | k <- [1, 5, 20 :: Int]
        ]
    ]
  where
    plus a b = apply sPlus [a, b]

-- | Evaluate one input from a state, purely.
evaluateIn :: KernelState -> Expr -> Maybe Expr
evaluateIn st e = rightToMaybe (fst (runPureEff (runEvalPure defaultConfig st (evaluateTop e))))

-- | A state in which @x0 := x1@, …, @x(k-1) := xk@: evaluating @x0@ takes
-- one fixed-point round per link, and @x0 + x0@ then collects.
chainState :: Int -> KernelState
chainState k = foldl' define standardState [0 .. k - 1]
  where
    define st i =
      let set = apply (systemSymbol "SetDelayed") [link i, link (i + 1)]
       in snd (runPureEff (runEvalPure defaultConfig st (evaluateTop set)))

link :: Int -> Expr
link i = mkSymbol (globalSymbol ("x" <> show i))
