-- | "Cassini.Pattern.Commutative", through "Cassini.Pattern.Match":
-- Krebber's commutative examples, which are milestone 1b's criterion
-- (DESIGN.md §10), the backtracking example of §4.5.4, and the enumeration
-- order WL's documentation shows.
module Test.Cassini.Pattern.Commutative (tests) where

import Cassini.Core.Symbol (globalSymbol)
import Cassini.Eval.Kernel (KernelState)
import Cassini.Pattern (Binding (..), Subst)
import Cassini.Pattern.Match (matchAll)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V
import Test.Kernel (evalStd, parse, run, stateWith)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
  testGroup
    "Pattern.Commutative"
    [ testGroup
        "Krebber"
        [ -- krebber2017_ac_matching_thesis.pdf §3.3: brute force over
          -- permutations enumerates each match twice; each distinct mapping
          -- once here.
          testCase "§3.3: fc(x+, y+) against fc(a, b, c) gives six matches, none twice" $
            let ms = matches "fc[Pattern[x, BlankSequence[]], Pattern[y, BlankSequence[]]]" "fc[a, b, c]"
             in (length ms, length (ordNub (map (show @Text) ms))) @?= (6, 6),
          -- §3.3.1, Figures 3.1–3.2: six candidate mappings, one match.
          testCase "§3.3.1: six mappings of g-terms, exactly one match" $
            matches
              "fc[g[a, Pattern[x, Blank[]]], g[Pattern[x, Blank[]], Pattern[y, Blank[]]], g[Pattern[z, BlankSequence[]]]]"
              "fc[g[a, b], g[b, a], g[a, c]]"
              @?= [subst [("x", one "b"), ("y", one "a"), ("z", sq ["a", "c"])]],
          -- §3.3.1, regular variables: only a and b occur twice.
          testCase "§3.3.1: fc(x, x, y*) against fc(a, a, a, b, b, c) binds x to a or b" $
            map (Map.lookup (globalSymbol "x")) (matches "fc[Pattern[x, Blank[]], Pattern[x, Blank[]], Pattern[y, BlankNullSequence[]]]" "fc[a, a, a, b, b, c]")
              @?= [Just (one "a"), Just (one "b")],
          -- §3.3.2: the sequence variable equations have three solutions.
          testCase "§3.3.2: {x*, y+, y+} against {a, b, b, c, c, c} has exactly σ1, σ2, σ3" $
            sortOn (show @Text) (matches "fc[Pattern[x, BlankNullSequence[]], Pattern[y, BlankSequence[]], Pattern[y, BlankSequence[]]]" "fc[a, b, b, c, c, c]")
              @?= sortOn
                (show @Text)
                [ subst [("x", sq ["a", "b", "b", "c"]), ("y", sq ["c"])],
                  subst [("x", sq ["a", "c", "c", "c"]), ("y", sq ["b"])],
                  subst [("x", sq ["a", "c"]), ("y", sq ["b", "c"])]
                ]
        ],
      testGroup
        "phases"
        [ -- DESIGN.md §4.5.4: a phase that committed to its first submatch
          -- would bind x = 1 and fail.
          testCase "phase 3 backtracks: {g[x_], x_, y_} against {g[1], g[2], 2}" $
            matches "fc[g[Pattern[x, Blank[]]], Pattern[x, Blank[]], Pattern[y, Blank[]]]" "fc[g[1], g[2], 2]"
              @?= [subst [("x", one "2"), ("y", one "g[1]")]],
          testCase "phase 1: a constant missing from the subject fails" $
            matches "fc[d, Pattern[x, BlankNullSequence[]]]" "fc[a, b, c]" @?= [],
          testCase "phase 1: a constant is removed once per occurrence" $
            matches "fc[a, a, Pattern[x, BlankNullSequence[]]]" "fc[a, a, b]" @?= [subst [("x", sq ["b"])]],
          testCase "equal subjects are interchangeable: one mapping, not two" $
            length (matches "fc[Pattern[x, Blank[]], Pattern[y, Blank[]]]" "fc[a, a]") @?= 1,
          testCase "too few subjects for the patterns' least lengths fails at once" $
            matches "fc[Pattern[x, BlankSequence[]], Pattern[y, BlankSequence[]], Pattern[z, BlankSequence[]]]" "fc[a, b]" @?= []
        ],
      testGroup
        "WL's order"
        [ -- wolfram/Orderless/PossibleIssues/1
          testCase "regular variables enumerate permutations in subject order" $
            evalStd
              [ "SetAttributes[h, Orderless]",
                "ReplaceList[h[a, b, c], RuleDelayed[h[Pattern[x, Blank[]], Pattern[y, Blank[]], Pattern[z, Blank[]]], List[x, y, z]]]"
              ]
              @?= "List[List[a, b, c], List[a, c, b], List[b, a, c], List[b, c, a], List[c, a, b], List[c, b, a]]",
          -- wolfram/Flat/PossibleIssues/1
          testCase "under Flat and Orderless, blanks take sub-multisets by size, then in order" $
            evalStd
              [ "SetAttributes[f, List[Flat, OneIdentity, Orderless]]",
                "ReplaceList[f[a, b, c, d], RuleDelayed[f[Pattern[x, Blank[]], Pattern[y, Blank[]]], List[x, y]]]"
              ]
              @?= "List[List[a, f[b, c, d]], List[b, f[a, c, d]], List[c, f[a, b, d]], List[d, f[a, b, c]], List[f[a, b], f[c, d]], List[f[a, c], f[b, d]], List[f[a, d], f[b, c]], List[f[b, c], f[a, d]], List[f[b, d], f[a, c]], List[f[c, d], f[a, b]], List[f[a, b, c], d], List[f[a, b, d], c], List[f[a, c, d], b], List[f[b, c, d], a]]",
          -- wolfram/Orderless/BasicExamples/3
          testCase "a literal and a blank against a sorted Plus" $
            evalStd ["MatchQ[Plus[2, x], Plus[x, Blank[Integer]]]"] @?= "True"
        ]
    ]

-- | A state in which @fc@ is @Orderless@ and not @Flat@: Krebber's @f_c@.
orderless :: KernelState
orderless = stateWith ["SetAttributes[fc, Orderless]"]

matches :: Text -> Text -> [Subst]
matches p s = fromRight [] (fst (run orderless (matchAll (parse p) (parse s))))

subst :: [(Text, Binding)] -> Subst
subst bs = Map.fromList [(globalSymbol x, b) | (x, b) <- bs]

one :: Text -> Binding
one = BOne . parse

sq :: [Text] -> Binding
sq = BSeq . V.fromList . map parse
