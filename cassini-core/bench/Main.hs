-- | The aggregate benchmark suite (DESIGN.md §8.1). Compiled with @-O2@ and
-- @-with-rtsopts=-T@, so allocation and peak memory are reported beside time.
module Main (main) where

import Bench.Core qualified
import Bench.EndToEnd qualified
import Bench.Eval qualified
import Bench.Pattern qualified
import Bench.Simplify qualified
import Test.Tasty.Bench (defaultMain)

main :: IO ()
main = defaultMain [Bench.Core.benchmarks, Bench.Eval.benchmarks, Bench.Pattern.benchmarks, Bench.Simplify.benchmarks, Bench.EndToEnd.benchmarks]
