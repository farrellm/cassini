# Revision history for cassini

The changelog is written as changes land, not at release (DESIGN.md §2.9).

## Unreleased

* Milestone 1c, calculus in the kernel (DESIGN.md §4.9, §4.10, §4.13, §10):
  * Pure functions (`Cassini.Builtins.Control`): `Function` in slot and named form applies as a
    built-in subvalue, with `Slot`, `SlotSequence`, `Function::slotn`, `Function::slots` and
    `Function::fpct`; `CompoundExpression`. Substitution respects scoping constructs, renaming a
    construct's names to `x$` as WL does (`Cassini.Structure.substituteFree`, which a rule's
    right-hand side now uses too).
  * `D` as a table of built-in downvalues (`Cassini.Builtins.Calculus`): several variables,
    `{x, n}`, gradients, lists, the sum, product, power and chain rules; `Derivative`'s subvalues
    add orders and differentiate pure functions, numbers, `List` and functions given by user
    downvalues. `Derivative` is not `Protected`, so a user's derivative is an ordinary subvalue.
  * The infix parser (`Cassini.Syntax.Lexer`, `.Parser`) over a precedence table that the
    printer (`Cassini.Syntax.Pretty`) shares, with message formatting; `parse (pretty e) ≡ e` is a
    property.
  * The interactive loop (`Cassini.REPL`): `In[n]`/`Out[n]`, `%`, messages, `:trace`, `:timing`,
    `:fullform`, line editing and history, and Ctrl-C as an abort at the next evaluation step
    (`runKernelInterruptible`), a second one thrown at once. Script mode and the loop record
    each input (`In`, `Out`, `$Line`), so `%` works in scripts too, and an input ending in `;`
    records the value before the semicolon.
  * Expreduce (vendored) and Mathics3 (fetched by `corpus/fetch.sh`) join `cassini-corpus`, each
    with an extractor, an adapter and a ratchet.
  * Benchmarks of deep `D` and of `//.` against 10, 100 and 1000 rules; the end-to-end workload
    gains parsing, printing and differentiation, and both baselines are regenerated.
  * Regression cases 0055–0058 seed the criterion, renaming and `%`; 0059–0070 pin the triage's
    fixes below and the 1c behaviours the corpora checked.
  * Fix: `Protect` of something that is not a symbol or a name emits `Protect::pssl`
    (regression case 0059).
  * Fix: `Symbol["name"]` makes the symbol, and `Symbol::symname` refuses a string that is not a
    name (regression case 0060).
  * Fix: `Rational[n_, d_]` matches a fraction (regression case 0066).
  * Fix: under a `OneIdentity` head, a compound pattern whose arguments are all `Optional`, such as
    `a_. + b_.`, matches a subject without its head (regression case 0067).
  * Fix: a `Verbatim[h]` pattern head matches its arguments in order, without `h`'s `Flat` and
    `Orderless` (regression case 0068).
  * Fix: `ReplaceList` with a negative count stays, with `ReplaceList::innf`, and takes
    `Infinity` as no limit (regression case 0070).
  * Fix: a named pure function's derivative, `Function[x, x^2]'`, is taken in fresh variables, so
    a global value of `x` no longer leaves it unevaluated (regression case 0071).
  * Fix: only a literal `Rational` head sees a fraction as `Rational[n, d]`; `_[_, _]` no longer
    matches `1/2` (regression case 0072).
  * Fix: `substituteFree` traverses a scoping construct's inside once, not twice, so filling
    slots under nested pure functions is linear, not exponential, in their depth.
  * Fix: `:trace` is interruptible like any input, and a second Ctrl-C during it no longer ends
    the loop.
  * Fix: `D` differentiates a compound head that depends on the variable, as WL does:
    `D[f[x][y], x]` is `f'[x][y]`, not 0, while `D[x[t], x]` stays 0 (regression case 0073).

* Milestone 1b, the matcher (DESIGN.md §4.5, §10):
  * Sequence matching (`Cassini.Pattern.Sequence`): `__`, `___`, `Repeated` with its counts,
    `Optional` with explicit and built-in defaults, and blanks under `Flat` heads, shortest run
    first.
  * Commutative matching (`Cassini.Pattern.Commutative`): Krebber's five steps under `Orderless`
    heads, each distinct mapping once.
  * `match` dispatches among the matchers by the subject head's attributes; `OneIdentity` with
    `Optional` defaults; a `Flat` head's rules apply to a run of its arguments, in definitions and
    in the `Replace` family (`matchRuleOrRun`).
  * `MatchQ`, `Cases`, `Replace`, `ReplaceAll`, `ReplaceRepeated` and `ReplaceList`, with their
    operator forms (`Cassini.Builtins.Pattern`).
  * The matcher laws over sequence blanks and `Orderless`/`Flat` heads, Krebber's examples as unit
    tests, regression cases 0042–0046 and the oracle's `patterns` cases.
  * Fixes from the corpus triage, each with a regression case (0047–0048):
    * `Optional` takes what its pattern takes, a sequence or a `Flat` run, and an absent one binds
      its default without matching it;
    * `Replace` matches a `Flat` head's expression whole; only `ReplaceAll` applies a rule to a run.
  * The `RuleIndex` (`Cassini.Pattern.Net`), keyed on the first argument's head, built because
    §8.3's net sweep found no break-even to wait for; `Cassini.Rules` consults it for down-values.
  * Benchmarks of the matcher (`bench/Bench/Pattern.hs`, §8.3), and the end-to-end workload extended
    with pattern replacement; both baselines regenerated. D11 measured, not fired.
  * Fix: a sequence variable's binding splices into the argument list it is substituted into, as
    WL's does, so `ReplaceRepeated` keeps matching an unevaluated result and `Hold` sees the
    spliced arguments (regression case 0049).
  * Fix: a compound pattern with an `Optional` argument, such as `n_. x_`, matches a subject
    without its head, as `OneIdentity` allows, as a definition's first argument and among an
    `Orderless` head's arguments: neither the rule index nor the commutative matcher's step 3
    excludes it by head any more (regression case 0050).
  * Fix: a name bound by a sequence variable to a run of one argument agrees with the same name
    bound to that argument alone, so `f[x__, x_]` matches `f[a, a]` (regression case 0051).
  * Fix: a sequence object against one expression, rather than an argument list, takes it as a
    run of one, so `MatchQ[a, __]` is `True` and `Cases[{1, a}, __]` is `{1, a}` (regression
    case 0052).
  * Fix: `Repeated[p, Infinity]` is read as `Repeated[p, {1, Infinity}]`, not as a literal
    expression (regression case 0053).
  * Fix: a `Flat` head's rule whose left-hand side carries a condition, `f[a, b] /; t`, applies to
    a run of the arguments as an unconditioned one does, in definitions and in `ReplaceAll`
    (regression case 0054).
  * A rule table's index changes in place instead of being rebuilt, and files a rule with no
    pattern object under its whole left-hand side, so a memoising definition is linear, not
    quadratic: `f[1]` … `f[8000]` take 0.6 s, from 64 s (DESIGN.md §4.5.5).
* Fix: three flaky property tests. `genExpr` could build an exponent such as `Power[5, 13]`, and
  `genBAE` a factorial of a factorial, and evaluating those exactly hung the `Eval` and `Simplify`
  laws or ran them out of memory. Exponents and factorial operands are now small numbers or terms
  with a symbol in them. And `Test.Numeric` skips the periodic test functions at arguments too
  large to keep the tolerance, a false failure of "simplify preserves numeric value". These were
  test defects, not evaluator bugs, so there is no regression case; exact arithmetic's missing
  size limit is deferred as D33 (DESIGN.md §7.3, §11.2).
* Split into three packages under one `cabal.project` (DESIGN.md §2.1, D7): `cassini-prelude`,
  `cassini-core` (the library, its test suites and benchmarks) and `cassini-repl` (the `cassini`
  executable). Script mode is renamed `Cassini.REPL` → `Cassini.Script` and stays in core;
  `Cassini.REPL` is reserved for the interactive loop. Consumers depend on `cassini-prelude` by its
  bare name, and `scripts/check-common-stanzas.sh` keeps the per-package `common` stanzas equal.
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
  * Script mode: `runScript`, `traceScript`, and `cassini --script`/`--trace` (`Cassini.REPL`, now `Cassini.Script`).
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
  * Fixes from the fourth review of the milestone 1a PR, each with a regression case (0037–0038):
    * `Part` with `All` or a list of indices on an atom is `Part::partd`, not the atom's head
      applied to nothing;
    * an argument `Evaluate` forced in a held position is not evaluated again when a `Sequence`
      splices it out of that position, so its messages are emitted once.
  * Fix: a part assignment whose index is not a part specification, such as `m[[x]] = 1`, is
    `Set::pkspec1`, not `Set::partw` (regression case 0039).
  * Fix: an index that is not a part specification is `Part::pkspec1`, not `Part::pkspec`, and
    `Part` and part assignment check every index before taking a part, so it wins over an index
    out of range or an atom (regression cases 0039–0040).
  * Part assignment takes `All` (regression case 0041).
  * The `Kernel` effect's operations are generated by `effectful-th`'s `makeEffect`, not written
    by hand; their signatures gain `HasCallStack`.
  * `cassini-corpus` and `cassini-oracle` no longer count two different outputs as equal because
    neither reads as FullForm.
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
