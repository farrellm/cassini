-- | The end-to-end workload, the number CI gates on (DESIGN.md §8.6).
--
-- At milestone 1a it is a FullForm script of automatic simplification and
-- user rules through 'runScript'. Each later milestone extends it, and each
-- extension regenerates the baselines deliberately: 1c adds parsing,
-- printing and differentiation, 2a polynomial arithmetic.
module Bench.EndToEnd (benchmarks, workload) where

import Cassini.Script (runScript)
import Data.Text qualified as T
import Test.Tasty.Bench (Benchmark, bench, bgroup, nfIO)

benchmarks :: Benchmark
benchmarks = bgroup "EndToEnd" [bench "1a workload" (nfIO (runScript workload))]

-- | The script: definitions, then sums and products that collect, rules that
-- fire through own values, down values and subvalues, and messages.
workload :: Text
workload =
  T.unlines $
    [ "SetDelayed[sq[Pattern[x, Blank[]]], Times[x, x]]",
      "SetDelayed[poly[Pattern[x, Blank[]]], Plus[Power[x, 3], Times[-2, Power[x, 2]], x, 5]]",
      "SetDelayed[pair[Pattern[a, Blank[]]][Pattern[b, Blank[]]], List[a, b, Plus[a, b]]]",
      "Set[c, Plus[p, q]]",
      "UpSetDelayed[norm[vec[Pattern[x, Blank[]], Pattern[y, Blank[]]]], Plus[sq[x], sq[y]]]"
    ]
      <> [ "Plus[" <> T.intercalate ", " [term k | k <- [1 .. 60 :: Int]] <> "]",
           "Times[" <> T.intercalate ", " ["Power[s" <> show (k `mod` 7) <> ", " <> show (k `mod` 4 + 1) <> "]" | k <- [1 .. 60 :: Int]] <> "]",
           "List[" <> T.intercalate ", " ["poly[" <> show k <> "]" | k <- [1 .. 30 :: Int]] <> "]",
           "List[" <> T.intercalate ", " ["sq[Plus[c, " <> show k <> "]]" | k <- [1 .. 20 :: Int]] <> "]",
           "List[" <> T.intercalate ", " ["pair[s" <> show k <> "][c]" | k <- [1 .. 20 :: Int]] <> "]",
           "Plus[" <> T.intercalate ", " ["norm[vec[s" <> show k <> ", c]]" | k <- [1 .. 20 :: Int]] <> "]",
           "List[Power[0, -1], Power[0, 0], Part[List[1, 2], 3]]"
         ]
  where
    term k = "Times[" <> show (k `mod` 5 + 1) <> ", Power[s" <> show (k `mod` 6) <> ", " <> show (k `mod` 3 + 1) <> "]]"
