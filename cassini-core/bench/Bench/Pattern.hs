{-# LANGUAGE PatternSynonyms #-}

-- | The matcher benchmarks (DESIGN.md §8.3), each built to answer a
-- question rather than to produce a number:
--
-- * syntactic matching, pattern and subject growing together;
-- * sequence variables, /k/ against /n/ arguments, every match enumerated:
--   the name of each benchmark carries its match count, so allocation per
--   match is the allocation column divided by it (D11);
-- * commutative matching at arity 3, 5, 8 and 12, with Krebber's steps 1–2
--   and without, which measures what they prune;
-- * a linear and a non-linear @Orderless@ pattern of the same size;
-- * the net question (§4.5.5): a fixed table of rules for one head against
--   1 to 10000 subjects, tried one by one in table order and through the
--   'Net.RuleIndex', built per run so that its construction is paid for.
--
-- The kernel state is built once, on the first iteration, as in
-- "Bench.Eval".
module Bench.Pattern (benchmarks) where

import Cassini.Builtins (standardState)
import Cassini.Core.Expr (Expr, apply, mkSymbol, pattern Int_)
import Cassini.Core.Symbol (Symbol, globalSymbol, sBlank, sBlankNullSequence, sBlankSequence, sPattern, systemSymbol)
import Cassini.Eval (evaluateTop, runEvalPure)
import Cassini.Eval.Kernel (Kernel, KernelState, defaultConfig)
import Cassini.Pattern (viewPattern)
import Cassini.Pattern.Match (MatchConfig (..), defaultMatchConfig, matchWith, observeAll, observeFirst)
import Cassini.Pattern.Net qualified as Net
import Data.Sequence qualified as Seq
import Effectful (Eff, runPureEff)
import Test.Tasty.Bench (Benchmark, bench, bgroup, nf)

benchmarks :: Benchmark
benchmarks =
  bgroup
    "Pattern"
    [ bgroup
        "syntactic"
        [ bench (show n <> " arguments") $ nf (firstMatch defaultMatchConfig (positional n)) (positionalSubject n)
        | n <- [4, 16, 64]
        ],
      bgroup
        "sequence"
        [ bench ("k=" <> show k <> " n=" <> show n <> " (" <> show (choose (n - 1) (k - 1)) <> " matches)") $
            nf (countMatches defaultMatchConfig (sequences k)) (plainArgs n)
        | k <- [1 .. 4],
          n <- [4, 8, 16, 32]
        ],
      bgroup
        "commutative"
        [ bench (show m <> " arguments, " <> label) $ nf (countMatches cfg (commutative m)) (commutativeSubject m)
        | m <- [3, 5, 8, 12],
          (label, cfg) <- [("steps 1-2 on", defaultMatchConfig), ("steps 1-2 off", MatchConfig {pruneCommutative = False})]
        ],
      bgroup
        "adversarial"
        [ bench "linear, 8 arguments" $ nf (countMatches defaultMatchConfig linear) pairs,
          bench "non-linear, 8 arguments" $ nf (countMatches defaultMatchConfig nonLinear) pairs
        ],
      bgroup
        "net"
        [ bgroup
            (show n <> " subjects")
            [ bench "one-to-one" $ nf (oneToOne table) (subjects n),
              bench "indexed" $ nf (indexed table) (subjects n)
            ]
        | n <- [1, 10, 100, 1000, 10000]
        ]
    ]

-- | A kernel with @o@ @Orderless@.
patternState :: KernelState
patternState = snd (runPureEff (runEvalPure defaultConfig standardState (evaluateTop setAttributes)))
  where
    setAttributes = apply (systemSymbol "SetAttributes") [sym "o", mkSymbol (systemSymbol "Orderless")]

-- | Run matcher code purely.
runMatch :: Eff '[Kernel] a -> Maybe a
runMatch m = rightToMaybe (fst (runPureEff (runEvalPure defaultConfig patternState m)))

-- | The first match's size: forcing it forces the substitution's spine.
firstMatch :: MatchConfig -> Expr -> Expr -> Maybe (Maybe Int)
firstMatch cfg p s = fmap length <$> runMatch (observeFirst (matchWith cfg (viewPattern p) s mempty))

countMatches :: MatchConfig -> Expr -> Expr -> Maybe Int
countMatches cfg p s = length <$> runMatch (observeAll (matchWith cfg (viewPattern p) s mempty))

-- | @f[g[x1_], …, g[xn_]]@ against @f[g[1], …, g[n]]@.
positional :: Int -> Expr
positional n = fn "f" [fn "g" [var ("x" <> show i) sBlank] | i <- [1 .. n]]

positionalSubject :: Int -> Expr
positionalSubject n = fn "f" [fn "g" [int i] | i <- [1 .. n]]

-- | @f[x1__, …, xk__]@: C(n−1, k−1) matches against @n@ arguments.
sequences :: Int -> Expr
sequences k = fn "f" [var ("x" <> show i) sBlankSequence | i <- [1 .. k]]

plainArgs :: Int -> Expr
plainArgs n = fn "f" [sym ("a" <> show i) | i <- [1 .. n]]

-- | @o[c1, …, c(m−2), g[x_], x_]@ against @o[c1, …, c(m−2), g[v], v]@: the
-- constants are step 1's, and @x_@ after @g[x_]@ is step 2's.
commutative :: Int -> Expr
commutative m = fn "o" ([sym ("c" <> show i) | i <- [1 .. m - 2]] <> [fn "g" [var "x" sBlank], var "x" sBlank])

commutativeSubject :: Int -> Expr
commutativeSubject m = fn "o" ([sym ("c" <> show i) | i <- [1 .. m - 2]] <> [fn "g" [sym "v"], sym "v"])

-- | Linear: four distinct variables and a rest. Non-linear: two variables
-- each twice, and a rest. Both against four pairs.
linear, nonLinear, pairs :: Expr
linear = fn "o" ([var ("x" <> show i) sBlank | i <- [1 .. 4 :: Int]] <> [var "r" sBlankNullSequence])
nonLinear = fn "o" [var "x" sBlank, var "x" sBlank, var "y" sBlank, var "y" sBlank, var "r" sBlankNullSequence]
pairs = fn "o" (concat [[sym s, sym s] | s <- ["a", "b", "c", "d"]])

-- | Fifty rules for one head, told apart by their first argument's head:
-- @f[gi[x_], y_]@, the shape of a table of integration rules.
table :: [Expr]
table = [fn "f" [fn ("g" <> show i) [var "x" sBlank], var "y" sBlank] | i <- [1 .. 50 :: Int]]

subjects :: Int -> [Expr]
subjects n = [fn "f" [fn ("g" <> show (1 + (i * 37) `mod` 50)) [int i], sym "z"] | i <- [1 .. n]]

-- | Each subject against the rules in order, to the first that matches.
oneToOne :: [Expr] -> [Expr] -> Maybe [Maybe Int]
oneToOne rules ss = runMatch (traverse (firstOf (zip [0 ..] rules)) ss)

-- | Index the rules, then each subject against its candidates only, in
-- table order.
indexed :: [Expr] -> [Expr] -> Maybe [Maybe Int]
indexed rules ss = runMatch (traverse (\s -> firstOf (Net.candidates index s) s) ss)
  where
    index = Net.fromSeq snd (Seq.fromList [(i, r) | (i, r) <- zip [0 :: Int ..] rules])

firstOf :: [(Int, Expr)] -> Expr -> Eff '[Kernel] (Maybe Int)
firstOf candidates s = case candidates of
  [] -> pure Nothing
  (i, p) : rest -> observeFirst (matchWith defaultMatchConfig (viewPattern p) s mempty) >>= maybe (firstOf rest s) (const (pure (Just i)))

choose :: Int -> Int -> Int
choose n k = product [n - k + 1 .. n] `div` product [1 .. k]

fn :: Text -> [Expr] -> Expr
fn f = apply (globalSymbol f)

sym :: Text -> Expr
sym = mkSymbol . globalSymbol

var :: Text -> Symbol -> Expr
var x b = apply sPattern [sym x, apply b []]

int :: Int -> Expr
int = Int_ . toInteger
