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
  * Benchmarks of the fixed point, automatic simplification and the end-to-end workload, and CI
    step 8, the allocation gate on the end-to-end workload (`bench/check-allocation.py --only`).
  * `cassini-corpus` over the Wolfram documentation corpus: the scope rule, the ratchet
    (`corpus/passing/wolfram.txt`) and the divergence manifest (`corpus/divergences.txt`).
  * Fixes from the corpus triage, each with a regression case (0014–0020):
    * level specifications and operator forms for `Map`, `Apply` and `Level`;
    * part assignment;
    * `Evaluate` inside a hold;
    * conditions on a rule's right-hand side;
    * multi-argument `Power`;
    * names and lists in `Protect` and `Unprotect`;
    * arity messages for `Head` and `Length`;
    * `Part` with no index.
  * `cassini-oracle`, differential testing against Mathics3, with its whitelist
    (`oracle/divergences.txt`); D30 registered for the recursion cut.
  * The four rule tables are a record, not an `EnumMap`, which drops `enummapset` and its
    `aeson` dependency.
  * Fix: a message from an unevaluated subterm was emitted again each time a sibling changed its
    parent (regression case 0013).
  * Fixes from the review of the milestone 1a PR, each with a regression case (0021–0025):
    * a condition on an assignment's left-hand side defines a rule for its head;
    * rules with one left-hand side and different right-hand-side conditions coexist, and `Unset`
      removes them all;
    * `Unset` refuses a protected symbol;
    * `Unevaluated` is restored on the argument it came from.
  * Fixes from the second review of the milestone 1a PR, each with a regression case (0026–0029):
    * a right-hand-side condition that fails tries the next match, and own values honour one;
    * a `Part` index beyond a machine integer is out of range, not wrapped;
    * a blank's head constraint makes a rule more specific, so `f[x_Integer]` precedes `f[x_]`;
    * list assignment recurses into nested lists.
  * Fix: automatic simplification nested a product in a product, or a sum in a sum, when like
    factors or terms collected into one (unit tests in `Test.Cassini.Simplify.Automatic`).
  * `SetAttributes` and `ClearAttributes` no longer evaluate their attributes twice.
  * Fixes from the third review of the milestone 1a PR, each with a regression case (0031–0034):
    * a condition on an upvalue's or tag assignment's left-hand side no longer hides its
      arguments' tags;
    * `HoldPattern` neither makes a rule more specific nor makes `f[2]` and `HoldPattern[f[2]]`
      two rules;
    * the attribute names are `System`` symbols;
    * `Part` of `{}` or `f[]` is `Part::partw`, not `Part::partd`.
  * Fixes from triaging the corpus cases the attribute names brought into scope, each with a
    regression case (0035–0036):
    * `Attributes` takes a name, and `Attributes[s] = {…}` replaces the attributes;
    * `Unprotect` on a `Locked` symbol is `Protect::locked`;
    * a `Sequence` spliced under `HoldFirst` or `HoldRest` goes round again, so an argument it
      moves out of the held position is evaluated.
  * The Wolfram documentation extractor holds the arguments of a symbol the example gave a hold
    attribute, rather than evaluating them while normalizing (D27).
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
