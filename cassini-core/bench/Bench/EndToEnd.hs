-- | The end-to-end workload, the number CI gates on (DESIGN.md §8.6).
--
-- At milestone 1a it is a FullForm script of automatic simplification and
-- user rules through 'runScript'; 1b adds pattern replacement, with sequence
-- variables and @Orderless@ matching, and definitions that need them; 1c
-- adds infix inputs, parsed by "Cassini.Syntax.Parser", pure functions and
-- differentiation, and prints every output with "Cassini.Syntax.Pretty".
-- Each later milestone extends it, and each extension regenerates the
-- baselines deliberately: 2a adds polynomial arithmetic.
module Bench.EndToEnd (benchmarks, workload, run) where

import Cassini.Script (resolveName, runScript)
import Cassini.Syntax.FullForm (fullForm, parseFullForm)
import Cassini.Syntax.Parser (parseExpr)
import Cassini.Syntax.Pretty (pretty)
import Data.Text qualified as T
import Test.Tasty.Bench (Benchmark, bench, bgroup, nfIO)

benchmarks :: Benchmark
benchmarks = bgroup "EndToEnd" [bench "workload" (nfIO run)]

-- | Parse the infix inputs, run the whole script, and print every output.
run :: IO [Text]
run = do
  out <- runScript (workload <> T.unlines (map toFullForm infixInputs))
  pure [either id pretty (parseFullForm resolveName r) | l <- lines out, Just r <- [T.stripPrefix ": " (snd (T.breakOn ": " l))]]
  where
    toFullForm l = either (const l) fullForm (parseExpr resolveName l)

-- | Milestone 1c's inputs, in the infix syntax: pure functions in slot and
-- named form, user derivatives, the product and chain rules through them,
-- repeated and partial differentiation, and rules over the results.
infixInputs :: [Text]
infixInputs =
  [ "sq2 = #^2 + 1 &",
    "Derivative[1][u] = 3 #^2 &",
    "v[x_] := x^3 - 2 x",
    "Table2 = Function[{f, n}, f /@ {n, n + 1, n + 2}]",
    "{sq2 /@ {1, 2, 3}, Table2[sq2, 4], Function[{a, b}, a b + a/b][p, q]}",
    "D[u[x] v[x] w[x], x]",
    "D[u[x^2] + v[u[x]] + w[v[x]]^3, x]",
    "D[(x^2 + y)^4 u[x y], x, y]",
    "D[u[x]^5 v[x]^-2, {x, 4}]",
    "D[{x^3 y, x y^2, u[x] + y}, {{x, y}}]",
    "Derivative[2][v][t] + Derivative[1][#^4 &][t]",
    "D[s1 s2 s3 s4 s5 s6 u[x s1] u[x s2] u[x s3], x] /. u'[z_] :> 3 z^2",
    "% /. {s1 -> 1, s2 -> 2, s3 -> 3}"
  ]

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
