# Revision history for cassini

The changelog is written as changes land, not at release (DESIGN.md §2.9).

## Unreleased

* Milestone 1a, the evaluator (DESIGN.md §4, §10):
  * Attributes as a bitmask (`Cassini.Attributes`).
  * Rules, the four tables and the ladder (`Cassini.Rules`).
  * The `Kernel` effect with its pure and `IO` interpreters (`Cassini.Eval.Kernel`), and messages
    (`Cassini.Eval.Message`).
  * The standard evaluation sequence, step by step, with its fixed point and both limits
    (`Cassini.Eval`).
  * The pattern view and the syntactic matcher, over `logict` inside `MatchT`
    (`Cassini.Pattern`, `.Match`, `.Syntactic`), and the `RuleIndex` interface (`.Net`).
  * Cohen's automatic simplification (`Cassini.Simplify.Automatic`).
  * The arithmetic, structural and assignment builtins, and the registry (`Cassini.Builtins.*`).
  * FullForm, read and printed (`Cassini.Syntax.FullForm`).
  * Script mode: `runScript`, `traceScript`, and `cassini --script`/`--trace` (`Cassini.REPL`).
  * The regression corpus and golden traces (`test/regress/`, `test/trace/`).
* Stage 0 (DESIGN.md §3, §10):
  * Exact numbers (`Cassini.Number`).
  * Interned symbols (`Cassini.Core.Symbol`).
  * The abstract `Expr`, with pattern synonyms and smart constructors.
  * Hash-only and weak-table interning behind the `intern` flag (`Cassini.Core.Intern`).
  * Cohen's canonical order, extended to every term (`Cassini.Core.Order`).
  * `recursion-schemes` traversal and `rewriteM`.
  * Cohen's structural operators (`Cassini.Structure`).
* Tooling (DESIGN.md §2.3–§2.8):
  * The `cassini-prelude` sublibrary.
  * The full warning set.
  * `.hlint.yaml` layering rules with fixtures.
  * The `cassini-test` suite.
  * Doctests.
  * `cassini-bench` with committed baselines.
  * CI.
* Fixes after the Stage 0 review:
  * `neg` and `isInteger` handle a raw, unnormalized `NRat`: `neg` normalizes its result, and
    `isInteger (NRat (4 % 2))` is `True`.
  * Every node, whether built by a smart constructor or a fold's `embed`, goes through one
    function, so construction cannot drift between the two.
  * `Cassini.Core.Intern` is private to `Cassini.Core.**` under the layering rules.
  * The allocation gate allows 1 KiB of absolute slack (`--slack`), so near-zero baselines do not
    fail on noise.
  * CI's Haddock step uses the same cabal flags as the other steps.
  * Tests that could not fail now can: the `Power[x]` kind test, the sort property, and the
    linear-time equality test.
  * `lint/check-layering.sh` stops on a fixture hlint cannot parse, or when hlint is missing,
    instead of passing an allowed fixture vacuously.
  * DESIGN.md §8.1 and `bench/check-allocation.py` say how baselines are built (plain
    `cabal bench`), and that allocation under the `intern` flag varies by a few percent.
  * Both benchmark baselines are regenerated with plain `cabal bench` at the current code, and
    D2's figures are rewritten from them. The decision, provisionally off, stands.
