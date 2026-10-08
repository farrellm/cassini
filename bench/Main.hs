-- | The aggregate benchmark suite (DESIGN.md §8.1). Compiled with @-O2@ and
-- @-with-rtsopts=-T@, so allocation and peak memory are reported beside time.
module Main (main) where

import Bench.Core qualified
import Test.Tasty.Bench (defaultMain)

main :: IO ()
main = defaultMain [Bench.Core.benchmarks]
