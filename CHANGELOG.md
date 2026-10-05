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
