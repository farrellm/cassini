-- | The end-to-end workload, the number CI gates on (DESIGN.md §8.6).
--
-- At milestone 1a it is a FullForm script of automatic simplification and
-- user rules through 'runScript'; 1b adds pattern replacement, with sequence
-- variables and @Orderless@ matching, and definitions that need them. Each
-- later milestone extends it, and each extension regenerates the baselines
-- deliberately: 1c adds parsing, printing and differentiation, 2a
-- polynomial arithmetic.
module Bench.EndToEnd (benchmarks, workload) where

import Cassini.Script (runScript)
import Data.Text qualified as T
import Test.Tasty.Bench (Benchmark, bench, bgroup, nfIO)

benchmarks :: Benchmark
benchmarks = bgroup "EndToEnd" [bench "workload" (nfIO (runScript workload))]

-- | The script: definitions, then sums and products that collect, rules that
-- fire through own values, down values and subvalues, and messages; then
-- the pattern builtins over sequences, Orderless sums and Flat runs.
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
           "List[Power[0, -1], Power[0, 0], Part[List[1, 2], 3]]",
           "SetDelayed[rev[Pattern[x, Blank[]], Pattern[y, BlankNullSequence[]]], Append2[rev[y], x]]",
           "SetDelayed[Append2[rev[], Pattern[x, Blank[]]], List[x]]",
           "SetDelayed[Append2[List[Pattern[y, BlankNullSequence[]]], Pattern[x, Blank[]]], List[y, x]]",
           "rev[" <> T.intercalate ", " ["s" <> show k | k <- [1 .. 40 :: Int]] <> "]",
           "ReplaceList[List[" <> T.intercalate ", " ["s" <> show (k `mod` 9) | k <- [1 .. 14 :: Int]] <> "], RuleDelayed[List[BlankNullSequence[], Pattern[x, Blank[]], BlankNullSequence[], Pattern[x, Blank[]], BlankNullSequence[]], x]]",
           "ReplaceAll[Plus[" <> T.intercalate ", " [term k | k <- [1 .. 30 :: Int]] <> "], RuleDelayed[Times[Pattern[c, Blank[Integer]], Power[Pattern[v, Blank[]], 2]], g[c, v]]]",
           "ReplaceRepeated[Plus[" <> T.intercalate ", " ["h[s" <> show k <> ", " <> show k <> "]" | k <- [1 .. 20 :: Int]] <> "], RuleDelayed[Plus[h[Pattern[a, Blank[]], Pattern[m, Blank[]]], h[Pattern[b, Blank[]], Pattern[n, Blank[]]], Pattern[r, BlankNullSequence[]]], Plus[h[Times[a, b], Plus[m, n]], r]]]",
           "Cases[List[" <> T.intercalate ", " ["poly[" <> show k <> "], s" <> show k | k <- [1 .. 30 :: Int]] <> "], Blank[Integer]]",
           "List[" <> T.intercalate ", " ["MatchQ[Plus[s1, s2, s" <> show k <> "], Plus[s" <> show k <> ", Pattern[r, BlankSequence[]]]]" | k <- [3 .. 30 :: Int]] <> "]"
         ]
  where
    term k = "Times[" <> show (k `mod` 5 + 1) <> ", Power[s" <> show (k `mod` 6) <> ", " <> show (k `mod` 3 + 1) <> "]]"
