-- | §4.12's benchmarks (DESIGN.md §8.4): the expression swell on @Expand@,
-- which is D2's workload, and trigonometric expansion in three parts.
--
-- @TrigExpand[Sin[a₁ + … + aₙ]]@ is the end-to-end cost, whose output has
-- 2ⁿ⁻¹ terms under any recursion. 'expandTrigRules' alone is the pair
-- recursion before algebraic expansion: each level builds a constant number
-- of nodes over shared subterms, so its allocation is linear in @n@, where
-- the naive recursion's 2ⁿ⁻¹ − 1 rule applications are exponential. Its
-- result is a DAG whose tree is exponential, so the benchmark forces it to
-- weak head normal form, which the strict cached hash makes complete, not
-- with 'nf', which would walk the tree. A nested product is the bottom-up
-- pass's own cost: each level's expansion takes the operands below it as
-- expanded, rather than walking them again.
module Bench.Trig (benchmarks) where

import Cassini.Core.Expr (Expr, apply, mkNumber, mkSymbol)
import Cassini.Core.Symbol (globalSymbol, sPlus, sPower, sTimes, systemSymbol)
import Cassini.Number (Number (NInt))
import Cassini.Simplify.Elementary (simplifyE)
import Cassini.Simplify.Rational (algebraicExpand)
import Cassini.Simplify.Trig (expandTrig, expandTrigRules)
import Test.Tasty.Bench (Benchmark, bench, bgroup, nf, whnf)

benchmarks :: Benchmark
benchmarks =
  bgroup
    "Trig"
    [ bgroup
        "Expand swell"
        [bench ("(a+b+c+d)^" <> show n) $ nf (rightToMaybe . expandSwell) n | n <- [10, 20, 30 :: Integer]],
      bgroup
        "TrigExpand of a sum"
        [bench ("Sin[a1 + … + a" <> show n <> "]") $ nf (rightToMaybe . expandTrig) (sinOfSum n) | n <- [4, 6, 8]],
      bgroup
        "expandTrigRules alone"
        [bench ("a1 + … + a" <> show n) $ whnf pairHash (sumOf n) | n <- [8, 16, 32, 64]],
      bgroup
        "TrigExpand of a nested product"
        [bench ("depth " <> show n) $ nf (rightToMaybe . expandTrig) (nestedProduct n) | n <- [10, 20, 40]]
    ]

-- | @Expand[(a + b + c + d)^n]@.
expandSwell :: Integer -> Either () Expr
expandSwell n =
  first (const ()) $
    simplifyE (apply sPower [apply sPlus (map var ["a", "b", "c", "d"]), mkNumber (NInt n)]) >>= algebraicExpand

-- | @a1 + … + an@, simplified.
sumOf :: Int -> Expr
sumOf n = fromRight (var "a1") (simplifyE (apply sPlus [var ("a" <> show k) | k <- [1 .. n]]))

sinOfSum :: Int -> Expr
sinOfSum n = apply (systemSymbol "Sin") [sumOf n]

-- | Force both results: a node's cached hash is strict and computed from its
-- children's, so evaluating a node to weak head normal form builds all of it.
pairHash :: Expr -> ()
pairHash a = either (const ()) (\(s, c) -> s `seq` c `seq` ()) (expandTrigRules a)

-- | @(…((x + a1 + Sin[b1 + c]) y1 + a2 + Sin[b2 + c]) y2 …) yn@: each level
-- expands into a sum one level up multiplies out, so a bottom-up pass that
-- re-expanded each node's operands from scratch would pay for every level
-- below it again (§4.12, §8.4).
nestedProduct :: Int -> Expr
nestedProduct n = fromRight (var "x") (simplifyE (foldr level (var "x") [1 .. n]))
  where
    level i e =
      apply
        sTimes
        [ apply sPlus [e, var ("a" <> show i), apply (systemSymbol "Sin") [apply sPlus [var ("b" <> show i), var "c"]]],
          var ("y" <> show i)
        ]

var :: Text -> Expr
var = mkSymbol . globalSymbol
