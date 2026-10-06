# Revision history for cassini

The changelog is written as changes land, not at release (DESIGN.md §2.9).

## Unreleased

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
