# Cassini — Design

A computer algebra system for Haskell: a Wolfram-Language-style term rewriting kernel with an exact
numeric and polynomial substrate underneath it.

This document is the architecture. It says what to build, in what order, with which boundaries, and
how each piece is tested and measured. It is deliberately ahead of the code — `src/` is still
`cabal init` output — so where the two disagree, this document is the intent and the code is behind.

## 0. Scope and conventions

### 0.1 What this covers

All four build stages, at design depth:

| Stage | Substance | §  |
| :---- | :--- | :--- |
| 0 | Exact numbers, the `Expr` representation, interning, canonical order, traversal | [§3](#3-stage-0--foundations) |
| 1 | Attributes, rule tables, the evaluation sequence, the pattern matcher, automatic simplification, surface syntax | [§4](#4-stage-1--the-kernel) |
| 2 | Polynomials, GCD, factorization, zero testing | [§5](#5-stage-2--the-polynomial-substrate) |
| 3 | Gröbner bases, integration, summation | [§6](#6-stage-3--the-hard-algorithms) |

Plus the cross-cutting plans: [testing](#7-testing), [benchmarking](#8-benchmarking),
[risks](#9-risks), [milestones](#10-milestones).

### 0.2 What this does not cover

Numerics beyond exact arithmetic (arbitrary-precision floating point, interval arithmetic) — the
representation reserves a slot and the design says where, but the algorithms are out of scope.
Likewise notebooks, graphics, a package/context system beyond what the evaluator needs, and
parallelism. Each is noted at the point where the design must not foreclose it.

### 0.3 The citation convention, and why it is narrow

Design claims here are justified by sources in `references/`, cited **by path**:

> Automatic simplification follows `references/papers/textbooks/cohen2003_*.pdf` §3.2.

That is the whole citation. This document does **not** restate facts *about* a source — its edition,
page count, publisher, or who first proved what. Those live in `notes/cas-haskell.md` and
`notes/cas-haskell-bibliography.md`, and `notes/CLAUDE.md` rule 4 already tracks each of them across
six files. A seventh copy would be a seventh thing to correct and a seventh thing to get silently
wrong. **Design rationale lives here; source provenance lives there.**

The one exception is where a source's *content* is the design — the thirteen evaluation steps, the
ASAE conditions, the five commutative-matching phases. Those are transcribed, because a design that
merely pointed at them would not be implementable. They are marked where they appear.

### 0.4 Reading order

`notes/cas-haskell.md` first if you have not read it; it is the research this rests on and it will
not be repeated here. Then §1–§2 of this document for shape, then the stage you are building.

---

## 1. Architecture

### 1.1 The central decision: two layers, differently typed

The system is **two libraries that meet at one bridge**, and they make opposite typing choices on
purpose.

**The rewriting kernel is untyped.** One `Expr` sum type; everything is `head[args]`. Every
production Wolfram-alike works this way, and the Haskell-specific attempt to do otherwise
(`references/papers/haskell/olah_hasksymb_readme.html`) concluded that variables cannot be put into
types without dependent types. The kernel's job is uniform traversal and uniform matching over a
heterogeneous term language; a typed AST fights that job at every step.

**The algebra layer is typed.** Polynomial arity, coefficient ring, and monomial order become
type-level parameters, so ℚ[x,y,z] and ℚ[w,x,y] cannot be added by mistake
(`references/papers/haskell/ishii2018_*.pdf`). Here the type system buys real safety, because the
objects are homogeneous and their invariants are exactly what types express well.

**The bridge is explicit and lossy in one direction** (§5.1): recognizing an `Expr` as a polynomial
in given variables can fail, and returns `Maybe`. Going the other way always succeeds.

This split is the design's single most consequential commitment. Failure mode (a) in
`notes/cas-haskell.md` — "trying to make the core type-safe and drowning in type-level machinery" —
is what it exists to prevent.

### 1.2 Layers and the dependency rule

```
                       ┌─────────────────────────────────────┐
  L5  Frontend         │ Syntax.Lexer/.Parser/.Pretty · REPL │
                       └────────────────┬────────────────────┘
                       ┌────────────────┴────────────────────┐
  L4  Builtins         │ Builtins.* · Simplify.Automatic     │──┐
                       └────────────────┬────────────────────┘  │
                       ┌────────────────┴────────────────────┐  │  (L4 only)
  L3  Evaluation       │ Eval · Eval.Kernel · Rules          │  │
                       └────────────────┬────────────────────┘  │
                       ┌────────────────┴────────────────────┐  │
  L2  Matching         │ Pattern.* · Attributes              │  │
                       └────────────────┬────────────────────┘  │
                       ┌────────────────┴────────────────────┐  │
  L1  Terms            │ Core.Expr · .Intern · .Order         │  │
                       │ .Symbol · .Traversal · Structure    │  │
                       └────────────────┬────────────────────┘  │
                       ┌────────────────┴────────────────────┐  │
  L0  Numbers          │ Number                              │  │
                       └────────────────┬────────────────────┘  │
                                        │                       │
                       ┌────────────────┴────────────────────┐  │
  A   Algebra (side)   │ Algebra.* · Poly.* · Zero           │◀─┘
                       │ Calculus.* · Groebner.* · Integrate │
                       └─────────────────────────────────────┘
```

**The rule: imports go down, never up, and never sideways into `A` except from L4.** The algebra
tower hangs off `Number` and knows nothing about `Expr`; it is reached only through the builtin
functions that expose it, and through the bridges in `Poly.Convert` and `Zero`. This is what keeps
the polynomial code testable without a kernel and the kernel testable without polynomials.

**The two bridges are the stated exceptions to the "never up" half, and they are exceptions, not
counterexamples.** `Poly.Convert` names `Cassini.Core.Expr` (L1) and `Cassini.Zero` names
`Cassini.Eval.Kernel` (L3) — both upward from where the diagram draws `A`. That is the price of a
bridge: recognizing an `Expr` as a polynomial requires seeing an `Expr`, and deciding whether an
expression is zero requires evaluating one (§5.6). What makes it a boundary rather than a leak is
that it is exactly two modules, both named in §2.6's `within` lists and nowhere else, so `Poly.Uni`,
`Poly.Multi`, `Poly.GCD`, `Poly.Factor`, `Groebner` and the rest still cannot see an `Expr` at all
and still compile without the kernel. Every other module in `A` obeys the rule as stated.

**One seam in L3 is deliberately visible from L2.** The matcher evaluates side conditions (§4.5.2),
so its signatures name the `Kernel` effect, and `Kernel`'s constructors name `SymbolInfo` from
`Cassini.Rules`. The effect *declaration* and the rule tables are therefore the bottom of L3 and
`Cassini.Pattern.*` may import them; the evaluation *sequence* in `Cassini.Eval` is above matching
and may not be imported downward. §2.6 splits the lint rule along exactly that line.

The rule is enforced by lint, not by good intentions — see §2.6.

### 1.3 Two shapes of computation, and why they stay apart

Everything in the kernel is one of two things, and conflating them is the classic mistake:

- **Rewriting** — a rule table plus a strategy for applying it. Nondeterministic (a pattern may
  match many ways), effectful (side conditions can evaluate), and its cost is unpredictable.
- **Canonicalization** — a total function from expressions to a normal form. Deterministic,
  terminating, and its cost is bounded by the term size.

`Plus`, `Times` and `Power` are canonicalized (§4.6). Everything else is rewritten. The seam is
that canonicalization is installed *as* the built-in rules for those three heads, so from the
evaluator's point of view there is one mechanism — but the code behind that seam is a total function
with an idempotence law, not a rule set with a fixed-point loop.

---

## 2. Repository and package layout

### 2.1 One package, for now

A single cabal package `cassini` with one public library, one executable, several test-suites and
several benchmark suites. One internal sublibrary, `cassini-prelude` (§2.3).

**The trigger for splitting** into a multi-package `cabal.project` is dependency divergence, not
size: when the algebra tower wants `vector-sized`, `finite-typelits`, `singletons` and a type-checker
plugin that the kernel has no use for, `cassini-algebra` becomes its own package so that someone
depending on the rewriting kernel does not pay for Gröbner bases. Until that happens, one package is
less friction and better Haddock.

### 2.2 Module tree

Every module gets one job. `Internal` modules expose representations; their non-`Internal` siblings
expose the API, which is the `containers`/`vector`/`aeson` convention.

| Module | Charter |
| :--- | :--- |
| **L0** | |
| `Cassini.Number` | Exact rationals over `Integer`. Normalization, `RNE` evaluation, the numeric tower's one true representation. |
| **L1** | |
| `Cassini.Core.Symbol` | Interned symbol names with contexts. `Text`-backed, `Int`-compared. |
| `Cassini.Core.Expr` | The `Expr` API: smart constructors, pattern synonyms, accessors. **No representation.** |
| `Cassini.Core.Expr.Internal` | The representation: node shape, cached hash, optional id. Import only from `Cassini.Core.*`. |
| `Cassini.Core.Intern` | The hash-consing table, private, behind the one exported `intern`. Switchable (§3.4). |
| `Cassini.Core.Order` | `compareCanonical` — Cohen's order relation. The kernel's *only* ordering. |
| `Cassini.Core.Traversal` | Base functor, `recursion-schemes` instances, rebuilding traversals that respect interning. |
| `Cassini.Structure` | Structure-based operators: `exprKind`, `part`, `numberOfParts`, `construct`, `freeOf`, `substitute`. Serves the Haskell API and the builtins alike. |
| **L2** | |
| `Cassini.Attributes` | The attribute set as a bitmask, and the predicates the evaluator asks it. |
| `Cassini.Pattern` | The pattern language as a view over `Expr`, plus `Subst`. |
| `Cassini.Pattern.Match` | The matcher's public face: `matchOne`, `matchAll`, and the `MatchT` monad. |
| `Cassini.Pattern.Syntactic` | Structural matching, no attributes. |
| `Cassini.Pattern.Sequence` | `BlankSequence`/`BlankNullSequence` distribution over a flat argument list. |
| `Cassini.Pattern.Commutative` | The five-phase `Orderless` matcher (§4.5.4). |
| `Cassini.Pattern.Net` | Many-to-one discrimination net. Stage 1b; behind the same interface. |
| **L3** | |
| `Cassini.Rules` | The four rule tables, ordered by specificity; `Rule` and `RuleSet`. |
| `Cassini.Eval.Kernel` | The `Kernel` effect and its two interpreters. |
| `Cassini.Eval` | The standard evaluation sequence and the fixed-point loop. |
| `Cassini.Eval.Message` | Message emission and formatting; the failure model. |
| **L4** | |
| `Cassini.Simplify.Automatic` | Cohen's automatic simplification: `Plus`, `Times`, `Power` to canonical form. |
| `Cassini.Builtins` | Registry assembly — one `KernelState` with every builtin installed. |
| `Cassini.Builtins.Arithmetic` | `Plus`, `Times`, `Power`, `Divide`, `Subtract`, comparison. |
| `Cassini.Builtins.Structural` | `Head`, `Part`, `Length`, `Apply`, `Map`, `Level`, `FreeQ`, `ReplaceAll`. |
| `Cassini.Builtins.List` | List construction and manipulation. |
| `Cassini.Builtins.Pattern` | `MatchQ`, `Cases`, `Replace`, `ReplaceRepeated`, `RuleDelayed`. |
| `Cassini.Builtins.Assign` | `Set`, `SetDelayed`, `TagSet`, `Unset`, `Attributes`, `Protect`. |
| `Cassini.Builtins.Calculus` | `D`, `Integrate`, `Series`, `Limit`. |
| `Cassini.Builtins.Polynomial` | `Expand`, `Factor`, `Together`, `Apart`, `PolynomialGCD`, `Coefficient`, `Exponent`, `Variables`. |
| **L5** | |
| `Cassini.Syntax.Lexer` | Tokens. |
| `Cassini.Syntax.Parser` | Infix surface syntax to `Expr`. |
| `Cassini.Syntax.FullForm` | `Plus[a, Times[2, b]]` — read and print. The golden-test format. |
| `Cassini.Syntax.Pretty` | Infix output with precedence-driven parenthesization. |
| `Cassini.REPL` | The read-eval-print loop; `In[]`/`Out[]`; the `cassini` executable's body. |
| **A** | |
| `Cassini.Algebra.Class` | The coefficient-tower classes actually used (§5.3). |
| `Cassini.Poly.Uni` | Dense univariate over a coefficient ring. |
| `Cassini.Poly.Multi` | Sparse distributed multivariate; monomial order a parameter. |
| `Cassini.Poly.Convert` | The `Expr` ↔ polynomial bridge (§5.1). |
| `Cassini.Poly.GCD` | The GCD ladder (§5.4). |
| `Cassini.Poly.Factor` | Squarefree, finite-field, Hensel, recombination (§5.5). |
| `Cassini.Poly.Resultant` | Resultants and subresultant PRS. |
| `Cassini.Zero` | The layered zero test, and the one place `Maybe Bool` is load-bearing (§5.6). |
| `Cassini.Groebner` | Buchberger, then F4 (§6.1). |
| `Cassini.Integrate.*` | Rules, rational, transcendental (§6.2). |
| `Cassini.Summation.*` | Gosper, Zeilberger (§6.3). |

### 2.3 The prelude

`relude` is the prelude, wired in through cabal `mixins` rather than imported per module. But
`relude` re-exports mtl's `State`/`Reader` vocabulary — `get`, `put`, `modify`, `gets`, `state`,
`ask`, `asks`, `local`, `withReader`, `State`, `StateT`, `Reader`, `ReaderT`, `MonadState`,
`MonadReader` — and those names collide, one for one, with `Effectful.State.Static.Local` and
`Effectful.Reader.Static`.
Fixing that with qualified imports in fifty modules is fifty chances to get it wrong.

So it is fixed once, in an internal sublibrary:

```cabal
library cassini-prelude
  import:           warnings
  exposed-modules:  Cassini.Prelude
  hs-source-dirs:   prelude
  build-depends:    base, relude
  mixins:
      base   hiding (Prelude)
    , relude (Relude as Prelude)
    , relude
  default-language: GHC2024

library
  import:           warnings
  build-depends:    base, cassini:cassini-prelude, effectful, ...
  mixins:
      base                   hiding (Prelude)
    , cassini:cassini-prelude (Cassini.Prelude as Prelude)
  ...
```

The `package:sublibrary` form is required in both `build-depends` and `mixins`; cabal rejects the
bare `cassini-prelude` with *unknown package*. Verified against cabal 3.16.1.0.

**The sublibrary takes relude's own three-line `mixins`, and all three lines are load-bearing.**
This is the form relude's README calls the recommended way to use a custom prelude, and it does
three things: `base hiding (Prelude)` drops base's `Prelude` from what the stanza can see,
`relude (Relude as Prelude)` puts relude's in its place, and the bare `relude` additionally keeps
relude's modules importable under their own names — which is what lets `Cassini.Prelude` say
`import Relude hiding (...)` at all.

**The middle line is not optional, and dropping it is the tempting mistake.** relude *redefines*
rather than re-exports a number of `Prelude` names — `show` is the `ToText`-polymorphic one (see
below), and `lines`, `words`, `readFile`, `error` and friends are the `Text` versions — so leaving
base's `Prelude` in scope inside the sublibrary puts each of those in scope twice as two different
entities and the `module Relude` re-export is ambiguous. But `hiding` only removes the module from
what the stanza provides; it does not cancel the implicit import GHC still makes. Hiding with no
replacement therefore fails with *Could not load module 'Prelude'. It is a member of the hidden
package 'base-4.21.2.0'*, reported against `Cassini.Prelude`'s own module header — a `hiding
(Prelude)` unaccompanied by a module to resolve to is a build error in any stanza. Both spellings
were built against GHC 9.12.4 and cabal 3.16.1.0.

The consuming stanzas are the same shape with a different replacement:
`cassini:cassini-prelude (Cassini.Prelude as Prelude)` supplies the subtracted prelude, and they
need no third line because nothing imports `Cassini.Prelude` by name.

`Cassini.Prelude` re-exports `Relude` minus the colliding names, and adds nothing else of substance —
it is a subtraction, not a second standard library. The same two `mixins` lines go in every stanza
that consumes the prelude: library, executable, each test-suite, each benchmark.

**The subtraction survives having relude as its own prelude, which is the question the three-line
form raises.** Inside `Cassini.Prelude`, `get`, `put`, `one` and `Undefined` are back in scope
through the implicit `Prelude` even though the explicit `import Relude` hides them — but scope
inside the module is not the export list. `module Relude` exports an entity only if it is in scope
*qualified as `Relude.…`*, which the `hiding` clause is what denies, so the hidden names are in
scope for this module's own body and absent from what it re-exports. Verified by building a
consumer of the sublibrary: `show` is relude's `Text`-returning one, a local definition of `one`
compiles with no clash, and `State`/`put`/`modify` are *Not in scope*.

```haskell
module Cassini.Prelude (module Relude) where

import Relude hiding
  ( -- collides with effectful's State and Reader effects
    State, StateT, MonadState, get, put, modify, modify', gets, state
  , evalState, execState, runState, evalStateT, execStateT, runStateT
  , Reader, ReaderT, MonadReader, ask, asks, local, runReader, runReaderT
  , withReader  -- Effectful.Reader.Static has one too, and it is not mtl's
    -- collides with this project's vocabulary
  , one        -- Relude.Container.One's singleton; we want the ring constant
  , Undefined  -- Relude.Debug's marker type; we want Cohen's Undefined (§4.6)
  )
```

**`withReader` is on that list and is the one an eyeball census misses.** relude re-exports it from
`Control.Monad.Reader`, and `Effectful.Reader.Static` exports a `withReader` of its own — the
`(r1 -> r2) -> Eff (Reader r2 : es) a -> Eff (Reader r1 : es) a` reinterpreter, not mtl's
`(r' -> r) -> Reader r a -> Reader r' a`. The list above was checked against the export lists of
`Relude.Monad.Reexport`, `Effectful.Reader.Static` and `Effectful.State.Static.Local` rather than
written from memory; going the other way, relude's `reader`, `withReaderT` and `withState` are
*not* subtracted, because effectful has no such names to collide with.

The second group is the one that will keep growing. **relude's namespace is large and it will
collide with CAS vocabulary**; `one` and `Undefined` are simply the first two, and both were found
by compiling this document's own fragments rather than by reading. The policy: where relude's
meaning is unrelated to ours, subtract it here — one line, one place — rather than renaming domain
types to dodge a prelude.

Four consequences to design around, rather than discover:

- **`Text` is the default string type.** `Symbol` is `Text`-backed. `String` appears only at the
  boundaries where a dependency demands it.
- **`show` is `ToText`-polymorphic in relude.** The pretty-printer must not lean on `Show`; `Show`
  instances exist for GHCi and test failure output only, and `Cassini.Syntax.Pretty` is the real
  rendering path. Stated so that the two never quietly swap roles.
- **Partial functions are not in scope.** No `head`, no `fromJust`, no `!!`. This is treated as a
  feature: a partial function in a simplifier is a latent bug that surfaces on someone else's input,
  and the places that want indexing (`Part`, argument access) should be returning `Either` with a
  message anyway, because that is what the language semantics require (§4.7).
- **Nor is `unsafePerformIO`.** relude withholds it, so the one module that needs it
  (`Cassini.Core.Intern`, §3.4) must `import System.IO.Unsafe` explicitly. That is a feature too:
  the unsafety is visible in the import list of exactly one file, and `grep -l System.IO.Unsafe src`
  is a complete audit of it.

### 2.4 Compiler and warnings

GHC 9.12.4, cabal 3.16, `default-language: GHC2024` throughout. A `common` stanza carries the
warning set, and it is not negotiable per-module:

```cabal
common warnings
  ghc-options:
    -Wall -Wcompat -Widentities
    -Wincomplete-record-updates -Wincomplete-uni-patterns
    -Wmissing-export-lists -Wpartial-fields -Wredundant-constraints
    -Wunused-packages
```

`-Wmissing-export-lists` is the load-bearing one: every module states its interface, which is what
makes the layering in §1.2 checkable and the `Internal` convention meaningful.

Extensions beyond GHC2024 are declared per-module, never in `default-extensions`, so that reading a
module tells you what it needs. The ones that actually need declaring, checked by compiling a
one-line module against bare `-XGHC2024` rather than by reading the release notes:
`PatternSynonyms` and `ViewPatterns` (§3.3), `TypeFamilies` (the algebra tower),
`OverloadedStrings`, and `DerivingVia`.

`DataKinds`, `GADTs` and `DerivingStrategies` are **already in GHC2024** and must not be declared —
`-Wall` does not warn on a redundant `LANGUAGE` pragma, so an unnecessary one is invisible noise that
implies the module needs something it does not. This is why §4.5.2's `deriving newtype` costs nothing
and §4.3's `Kernel` GADT carries no pragma.

### 2.5 Formatting and lint

`fourmolu` with a committed `fourmolu.yaml`; `hlint` with a committed `.hlint.yaml`. Both run in CI
in check mode. Both are already installed locally.

### 2.6 Layering, enforced

The dependency rule in §1.2 is a lint rule, so that breaking it fails the build rather than being
noticed in review three months later. `.hlint.yaml`:

```yaml
- modules:
    # The evaluation sequence is above matching: nothing below L3 may import it.
    - name: [Cassini.Eval, Cassini.Eval.Message]
      within: [Cassini.Eval, Cassini.Eval.*, Cassini.Simplify.*,
               Cassini.Builtins, Cassini.Builtins.*, Cassini.Syntax.*, Cassini.REPL,
               Main, Test.*, Bench.*]
    # The Kernel effect and the rule tables are the vocabulary the matcher needs for
    # side conditions (§4.5.2), so L2 may name them - but not the sequence above them.
    - name: [Cassini.Eval.Kernel, Cassini.Rules]
      within: [Cassini.Pattern, Cassini.Pattern.*, Cassini.Eval, Cassini.Eval.*,
               Cassini.Rules, Cassini.Simplify.*, Cassini.Builtins, Cassini.Builtins.*,
               Cassini.Syntax.*, Cassini.REPL, Cassini.Zero, Main, Test.*, Bench.*]
    # The algebra tower does not know about Expr; Poly.Convert and Zero are the bridges.
    - name: [Cassini.Core.Expr]
      within: [Cassini.Core.*, Cassini.Structure, Cassini.Attributes,
               Cassini.Pattern, Cassini.Pattern.*,
               Cassini.Rules, Cassini.Eval, Cassini.Eval.*, Cassini.Simplify.*,
               Cassini.Builtins, Cassini.Builtins.*, Cassini.Syntax.*, Cassini.REPL,
               Cassini.Zero, Cassini.Poly.Convert, Main, Test.*, Bench.*]
    # The representation is private to the core - and to the test that A/Bs interning.
    - name: Cassini.Core.Expr.Internal
      within: [Cassini.Core.*, Test.Cassini.Core.Intern]
    # Nondeterminism is private to the matcher's monad (§4.5.2).
    - name: [Control.Monad.Logic, Control.Monad.Logic.Class]
      within: [Cassini.Pattern.Match]
```

`Cassini.Poly.Convert` appears in the `Cassini.Core.Expr` rule's `within` and its siblings do not:
it is the bridge, and the only module in `Cassini.Poly.*` allowed to see an `Expr`.

**Why `Cassini.Eval.Kernel` and `Cassini.Rules` get their own rule.** §4.5.2's matcher evaluates side
conditions, so `match`, `matchOne` and `matchAll` all carry `(Kernel :> es)` — L2 must name the
`Kernel` effect, and `Kernel`'s own constructors mention `SymbolInfo` from `Cassini.Rules`. A single
rule naming `Cassini.Eval.*` would fail the whole matcher on its first import. The effect *declaration*
and the rule tables are shared vocabulary that sits at the bottom of L3; the evaluation *sequence*
(`Cassini.Eval`) and the message machinery stay above matching, which is what the `Cassini.Eval`
rule keeps.

**And why the constraint alone is not enough.** `(Kernel :> es)` grants the effect's *operations*,
not `Cassini.Eval`'s *functions*, so a matcher that needed to call `Cassini.Eval.evaluate` would
still have to import the module this rule forbids it. That is exactly why `Evaluate` is a
constructor of `Kernel` (§4.3) rather than a plain function: `Cassini.Pattern.Match` and
`Cassini.Zero` reach evaluation by `send`, `Cassini.Eval` supplies the sequence when it interprets
the effect, and the import graph stays acyclic. A `Kernel` without that constructor makes this rule
unsatisfiable, which is the failure this paragraph exists to prevent.

**`Cassini.Rules` is not in the first rule's `within`, and that is the point.** It sits at the
*bottom* of L3 so `Cassini.Pattern.*` may import it; letting it import `Cassini.Eval` back would put
`Cassini.Pattern.Match → Cassini.Rules → Cassini.Eval → Cassini.Pattern.Match` back in the graph —
the cycle the second rule's whole existence is arranged around. GHC would reject it eventually, but
only after the invariant this file is supposed to state had already been broken.

**`hlint .` walks `test/` and `bench/` too, so their namespaces have to be in every list.** The
suites import the very modules these rules guard — `Test.Cassini.Core.Order` imports
`Cassini.Core.Expr`, `Bench.Eval` imports `Cassini.Eval` — and `within` is an allow-list, so a
config naming only `src/` modules plus `Main` fails CI step 3 on the first test module rather than
on a layering violation. `Main` covers `test/Main.hs`, `bench/Main.hs` and `app/Main.hs`; `Test.*`
and `Bench.*` cover the rest. `Test.Cassini.Core.Intern` is named individually in the
`Cassini.Core.Expr.Internal` rule because §7.3's interning-agreement property has to reach the
representation, and that is the one exception worth writing out rather than widening.

Four things about this config that are not obvious, and were each found by running `hlint` against
sample modules rather than by reading the manual:

- **`within` is an allow-list and there is no negation.** `within: [-Cassini.Poly.Uni]` is not a
  restriction on `Cassini.Poly.Uni`; hlint rejects the file outright with *Bad classification rule*.
  The layering has to be written as "who may", not "who may not", which is why the
  `Cassini.Core.Expr` rule's list is long.
- **`within` lists union across rules that match the same module.** So `Cassini.Core.Expr.*` must not
  appear in the `Cassini.Core.Expr` rule's `name`: if it did, that rule's `within` would re-permit
  `Cassini.Core.Expr.Internal` everywhere it lists, silently defeating the
  `Cassini.Core.Expr.Internal` rule. The five rules name disjoint module sets on purpose, which is
  also why the first names `Cassini.Eval.Message` explicitly rather than `Cassini.Eval.*`: the
  wildcard would overlap the `Cassini.Eval.Kernel` rule and union the matcher into the sequence's
  allow-list.
- **`Foo.*` does not match bare `Foo`.** `Cassini.Builtins` and `Cassini.Builtins.*` are both listed,
  and so are `Cassini.Pattern` and `Cassini.Pattern.*`; omitting the bare form is a rule that quietly
  does not cover the registry module, or — the case that actually bit — `Cassini.Pattern` itself,
  which holds `viewPattern :: Expr -> PatternView` (§4.5.1) and so imports `Cassini.Core.Expr`.
- **And bare `Foo` does not match `Foo.Bar`** — the same fact from the other side, and the reason the
  `Control.Monad.Logic` rule names `Control.Monad.Logic.Class` as well. A rule naming only
  the latter passes a module that imports `MonadLogic` from the former, which is precisely the
  leak §4.5.2 is trying to prevent. Checked by running it, not by reading the manual.

The check that this config does what it claims belongs in CI beside `hlint` itself: a handful of
fixture modules asserting that `Cassini.Poly.Uni` importing `Cassini.Core.Expr` is reported and
`Cassini.Poly.Convert` doing the same is not — and, for the `Control.Monad.Logic` rule, that
`Cassini.Pattern.Commutative` importing `Control.Monad.Logic` is reported while
`Cassini.Pattern.Match` doing the same is not.

### 2.7 Documentation

Haddock on every export. Modules implementing a published algorithm carry a source line in the
module header:

```haskell
-- | Automatic simplification of sums, products and powers.
--
-- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.2 (procedure
-- @Automatic_simplify@ and its subordinate operators).
module Cassini.Simplify.Automatic (simplify, isASAE) where
```

This is not decoration. It is what lets a reader check the implementation against the thing that
justified it, and it makes this document's citations verifiable from the other end.

### 2.8 CI

`.github/workflows/ci.yml`, `haskell-actions/setup`, **matrix of one: GHC 9.12.4**, which is
therefore the required job:

1. `cabal build --enable-tests --enable-benchmarks all`
2. `cabal test cassini-test cassini-doctest` (unit, property, golden, Haddock examples)
3. `hlint .`
4. `fourmolu --mode check $(git ls-files '*.hs')`
5. `cabal haddock --haddock-quickjump` with a coverage floor
6. benchmark regression gate against the committed baseline (§8.6)

Steps 3–6 run on the newest GHC only — which today is the only one, and stays written that way so
that widening the matrix does not also mean re-deciding what runs where. A separate nightly job runs
`cabal test cassini-oracle cassini-slow`, which is where §7.1 puts the two suites that are too slow
or too environment-dependent to gate a commit; the oracle suite skips rather than fails when its
externals are absent (§7.5).

**There is no separate doctest step**, because §7.1 makes `cassini-doctest` a cabal *test-suite* and
step 2 already runs it. A `cabal run doctests` beside it would run the same examples twice and give
them two places to be disabled from — and the one that gets disabled is always the one whose failure
is less legible, which is the standalone step. The suite is where doctests belong for the same
reason `cassini-slow` is a suite and not a script: what CI runs is `cabal test`, so anything that
wants to be run at all has to be reachable from it.

**Step 2 names its suites rather than saying `all`**, because `cabal test all` would pull
`cassini-slow` into every commit — four minutes against a fast suite whose whole purpose (§7.1) is
to be seconds.

**Why one and not the usual three.** `cassini.cabal` carries `base ^>=4.21.2.0`, and `base` 4.21 is
GHC 9.12's; the bound admits no other compiler. A matrix over "the current and previous two majors"
would have been three jobs, two of which fail at `cabal build` on a dependency-resolution error
before reaching a single test — the sort of red CI that gets read as flaky and then ignored. The
choice is not "test fewer compilers", it is that the version bound and the matrix have to say the
same thing, and the bound is the one with teeth.

Widening is a deliberate act with a cost, not a maintenance chore: relaxing to `base >=4.21 && <4.23`
means every `Cassini.Prelude` subtraction (§2.3) has to hold across both `relude` builds, and §8.6's
benchmark baselines are committed per GHC version, so a second compiler is a second baseline to
regenerate and defend. D12 records the trigger.

### 2.9 Versioning

PVP. `CHANGELOG.md` is written as changes land, not at release. Until `1.0`, `Expr`'s representation
is explicitly unstable and the `Internal` modules carry no compatibility promise at all — said out
loud so that the interning decision in §3.4 stays reversible.

---

## 3. Stage 0 — foundations

The goal of Stage 0 is a term representation that is cheap to build, cheap to compare, and cheap to
traverse, over an exact numeric tower. Nothing here evaluates anything. It is the stage most likely
to be rushed and the stage whose mistakes are most expensive to undo, because every later layer is
written against these types.

**Exit criterion:** large expressions can be constructed, compared and traversed at measured cost,
and `compareCanonical` passes its order laws. See §10.

### 3.1 Numbers

The kernel's numeric tower is exact and small:

```haskell
-- | Cassini.Number
data Number
  = NInt  !Integer
  | NRat  !Rational   -- ^ invariant: denominator > 1, reduced, sign on numerator
  deriving stock (Eq, Show)

-- | Numeric order, not constructor order. This is the only 'Ord'-shaped thing
-- 'Cassini.Number' exports, and O-1 (§3.5) is its one caller of consequence.
instance Ord Number where compare = compareNumber

compareNumber :: Number -> Number -> Ordering
```

Three decisions.

**`Ord Number` is *not* derived, for the same reason `Ord Expr` is not (§3.5).** The derived instance
compares by constructor position, so `NInt 5 < NRat (3 % 2)` — a total order, and the wrong one. O-1
says "both constants: numeric `<`", and a derived `Ord` sitting in scope is exactly how the wrong
comparison gets used by accident on the way there. The invariant on `NRat` (denominator > 1) keeps
derived `Eq` correct, so `Eq` stays derived and `Ord` does not. The §7.3 `Number` row tests
`compareNumber` against `Rational` comparison over both constructors.

**`Integer` is the right starting point, and should be logged as revisitable rather than solved.**
Under `ghc-bignum`, `Integer` is `IS Int# | IP ByteArray# | IN ByteArray#`: values that fit a machine
word are an unboxed `Int#` and GMP is reached only for genuinely large ones. The small-integer fast
path that a naive `mpz_t` wrapper lacks is already there. That is the argument in
`notes/cas-haskell.md` §"University course materials and worked build-logs", and it is sound — but it is an argument about
today's `ghc-bignum`, and the polynomial layer at Stage 2 is where it would first fail to hold. The
deferred-decisions register (§11.2) carries it.

**`Rational` is `Ratio Integer`, but the invariant is ours to maintain.** `Ratio` normalizes on
construction through `%`, which is correct but pays a `gcd` on every operation. The kernel's
arithmetic goes through `Cassini.Number`, which is free to batch normalization — a sum of *n*
rationals normalizes once, not *n* times. This matters because sums of rationals are the single
hottest operation in automatic simplification.

Inexact numbers are **not** in the Stage 0 representation. When they arrive they become a third
constructor, and the design constraint recorded now is that `compareCanonical` (§3.5) must place
them without disturbing the existing order — Cohen's rule O-7 puts every number before every
non-number, which leaves room.

Cohen's `Simplify_RNE` — evaluate a rational-number expression, `Nothing` on division by zero — is
`simplifyRNE :: Expr -> Maybe Number`, and it lives in `Cassini.Simplify.Automatic` (§4.6), **not
here**. It takes an `Expr`, and `Cassini.Number` is L0: a `Number` module importing
`Cassini.Core.Expr` inverts §1.2's layering and is rejected by §2.6's `Cassini.Core.Expr` rule,
which does not list it. What `Cassini.Number` owns is the arithmetic `simplifyRNE` calls — exact
`+`, `*`, `^` and the division-by-zero result — which is the part that genuinely needs no `Expr`.

### 3.2 Symbols

```haskell
-- | Cassini.Core.Symbol
data Symbol = Symbol { symId :: {-# UNPACK #-} !Int, symContext :: !Text, symName :: !Text }
instance Eq  Symbol where (==)    = (==)    `on` symId

-- | Map-key order only. Interning order, therefore session-dependent.
-- The canonical order is 'compareSymbolName'; see below.
instance Ord Symbol where compare = compare `on` symId

-- | Cohen's O-2. The only symbol comparison any *output* may depend on.
compareSymbolName :: Symbol -> Symbol -> Ordering
compareSymbolName = comparing symContext <> comparing symName
```

**`Ord Symbol` is `symId` order, and `symId` is allocation order.** It is the right instance for a
`Map Symbol` key — an `Int` compare in the hottest loop there is — and the wrong one for anything a
user sees, because which symbol got the smaller id depends on what the session interned first. Two
places would silently inherit that: O-2 in §3.5, which Cohen defines as *lexicographic*, and
`Cassini.Poly.Convert.variables` (§5.1), whose result order fixes the exponent-vector layout of
every `Monomial`. Reaching for the in-scope `compare` in either makes `Plus[b, a]` sort one way from
a `--script` run and the other way from a REPL session that had already mentioned `b`, so the golden
files in §7.4 pass or fail on evaluation history. `compareSymbolName` exists so that O-2 does not
have to reach for `compare`, and `Cassini.Core.Order` is its one caller. `variables` avoids the same
trap by a different route — its elements are generalized variables and therefore `Expr`s, not
symbols (§5.1), so it sorts with `compareCanonical`, which reaches `compareSymbolName` through O-2
and is likewise free of `symId`. This is the same trap §3.1 and §3.5 avoid by not deriving `Ord`;
here the instance is genuinely wanted, so the containment is a second named function rather than an
absence.

Symbols are interned unconditionally — unlike expressions (§3.4), where interning is a decision.
Symbol interning is cheap, obviously correct, and buys `Int` comparison in the hottest inner loop
there is, since every rule lookup is keyed by symbol. The table is a global `IORef (HashMap Text
Symbol)` behind `unsafePerformIO`/`NOINLINE`, which is the standard idiom and is safe here because
the table is append-only and the `Int` is allocated under a lock.

Contexts (`System\`Plus`, `Global\`x`) are carried from the start rather than retrofitted, because
retrofitting a namespace into a symbol table means touching every rule key.

### 3.3 `Expr` — abstract, with pattern synonyms

This is the design's most important piece of Haskell technique, so it is spelled out.

The representation lives in `Cassini.Core.Expr.Internal` and is not exported past `Cassini.Core.*`:

```haskell
-- | Cassini.Core.Expr.Internal
data Expr = Expr
  { exprHash  :: {-# UNPACK #-} !Int     -- ^ cached structural hash
  , exprId    :: {-# UNPACK #-} !Int     -- ^ intern id, or 'notInterned'
  , exprShape :: !Shape
  }

data Shape
  = SNumber !Number
  | SString !Text
  | SSymbol !Symbol
  | SApp    !Expr !(Vector Expr)   -- ^ head and arguments, mirroring FullForm
```

`Cassini.Core.Expr` exports the type abstractly, plus **bidirectional pattern synonyms** and a
`COMPLETE` pragma:

```haskell
-- | Cassini.Core.Expr
module Cassini.Core.Expr
  ( Expr
  , pattern Num, pattern Str, pattern Sym, pattern App
  , pattern Int_, pattern Rat_
  , exprHead, exprArgs, exprArity
  ) where

pattern Num :: Number -> Expr
pattern Num n <- (exprShape -> SNumber n) where Num n = mkNumber n

pattern App :: Expr -> Vector Expr -> Expr
pattern App h as <- (exprShape -> SApp h as) where App h as = mkApp h as

{-# COMPLETE Num, Str, Sym, App #-}
```

Callers write ordinary pattern matches:

```haskell
derivative :: Symbol -> Expr -> Expr
derivative x = \case
  Sym s | s == x -> one
        | otherwise -> zero
  Num _ -> zero
  App (Sym f) args -> ...
```

…and the compiler still checks exhaustiveness, thanks to `COMPLETE`. But every *construction* goes
through `mkNumber`/`mkApp`, which compute the hash and consult the intern table. **That is the
whole point:** the interning decision lives in four smart constructors, not in every call site, and
§3.4 can be revisited without a repository-wide edit.

Two representation notes.

`SApp` stores head and arguments separately rather than as one non-empty vector. WL's `FullForm`
treats the head as element 0, and `Part[expr, 0]` returns it — but the head is asked for on every
single evaluation step while arguments are indexed comparatively rarely, so separating them keeps
`exprHead` a field access instead of a bounds-checked read. `Cassini.Structure.part` reconstructs
the 0-index convention at the API boundary.

Arguments are a boxed `Vector`. `Orderless` sorting, `Flat` flattening and `Listable` threading all
want bulk operations with known lengths; a list would make every arity check O(n). The cost is that
consing an argument on the front is O(n), which matters in the sequence matcher — so
`Cassini.Pattern.Sequence` works on slices (`Vector.slice` is O(1)) rather than rebuilding.

### 3.4 Interning — designed to be switchable

`notes/cas-haskell.md` recommends hash-consing from day one, and failure mode (e) is not doing it.
The recommendation is right about the destination and this design takes it, but it commits in two
steps rather than one, because a global weak-reference table is real complexity to carry through
every early bug.

**Step 1 (day one): cached hashes.** Every node stores its structural hash. `Eq` short-circuits on
hash inequality before descending. This is nearly free, needs no `IO`, and gets most of the win on
the comparison-heavy paths (`Orderless` sorting, rule lookup, `MatchQ`).

**Step 2 (gated on measurement): the intern table.** A global weak-value hash table, so that GC can
reclaim nodes nothing references and the table does not grow without bound:

```haskell
-- | Cassini.Core.Intern
internTable :: MVar (HashMap Int [(Int, Weak Expr)])  -- keyed by hash, bucketed;
                                                      -- the Int is the entry serial 'reap' deletes
{-# NOINLINE internTable #-}
internTable = unsafePerformIO (newMVar mempty)

intern :: Shape -> Expr
```

**Weak references reclaim the node, not the entry.** A `Weak Expr` whose key dies leaves a dead
`Weak` in its bucket, so a table that only ever appends buckets grows without bound even though every
`Expr` it once held has been collected — the leak is the size of the bucket lists, not of the terms.
Each weak pointer is therefore created with a finalizer (`mkWeakPtr v (Just (reap h n))`) that
deletes its own entry from the bucket, and lookups additionally drop the entries whose `deRefWeak`
returns `Nothing` as they scan. Neither alone is enough: the finalizer can lag, and lookup only
visits buckets that are asked for.

**The finalizer must not mention the node, and this is the pitfall that silently disables the whole
mechanism.** `mkWeakPtr v fin` makes `v` the weak pointer's *key*, and GHC's reachability rule is
that a finalizer keeps its own free variables alive: a `reap` closing over `v` — or over the `Weak
Expr` that holds `v` as both key and value — makes every interned node permanently reachable, the
finalizer never runs, and the table becomes a strong-value table that leaks the terms themselves
rather than the bucket entries. The failure is invisible: everything still returns the right answer,
residency just climbs, so it will be found by §8.2's allocation numbers or not at all. So `reap`
closes over the bucket key `h` and a per-entry serial `n` only — both `Int`s, neither reaching the
node — and the bucket holds `(Int, Weak Expr)` pairs so that `n` identifies the entry to delete
without dereferencing anything. §7.3's interning-agreement property does not catch this, because a
table that never reaps is still *correct*; the residency line in §8.2's A/B is what catches it.

**The table is an `MVar`, not an `IORef`, and that is forced by the finalizers.** Unlike the symbol
table (§3.2), which is append-only and never mutated from anywhere but `internSymbol`, this table has
a second writer: GHC runs weak-pointer finalizers on its own thread, so `reap` can fire *between* the
read and the write of a `modifyIORef` inside `intern` and have its deletion silently overwritten,
leaving a dead `Weak` that lookup then has to re-collect — or, in the other order, have a
freshly-interned entry dropped, which is worse, because two structurally equal `Expr`s then get two
different `exprId`s and `(==)` starts returning `False` on equal terms. Read-modify-write on the
table, in both `intern` and `reap`, is therefore under one `MVar`. `atomicModifyIORef'` would also be
correct; the `MVar` is preferred because the critical section allocates an id and must not be
retried.

The mechanism needs immutable terms plus a collector that traces through weak references, which is
exactly Haskell's model — the observation is ours, from reading
`references/papers/haskell/zhu2025_hash_consing.pdf`, not the paper's.

Three things to be honest about:

- **`unsafePerformIO` with `NOINLINE` and `-fno-full-laziness` on that module.** This is the
  standard global-variable idiom and it is used correctly here, but it is genuinely unsafe if the
  table is ever read outside the smart constructors. That is why `Cassini.Core.Intern` exports
  `intern` and nothing else — and why the explicit `import System.IO.Unsafe` that relude forces
  (§2.3) is welcome rather than a nuisance: it makes this the only file in the tree that names it.
- **Interning *displaces* derived `Eq`; it does not join it.** With a table, `(==)` is `exprId`
  comparison and `hashWithSalt` is `exprHash`. Without one, `(==)` is structural with a hash
  short-circuit. These are alternatives. The `Eq` instance is defined once, in
  `Cassini.Core.Expr.Internal`, in terms of whichever is active — and the property test in §7.3
  asserts the two agree, which is how the switch stays safe.
- **The gate is a number, not a feeling.** The Stage 0 benchmark (§8.2) runs the same workload with
  interning on and off. Interning ships if it wins on the expression-swell workload; otherwise it
  stays behind the flag and the decision is recorded in §11.2 with the measurement attached.

The flag is a cabal `manual` flag, not a CPP maze: `Cassini.Core.Intern` has two implementations
selected by `hs-source-dirs`, both satisfying the same one-function interface.

### 3.5 Canonical order

**The kernel has exactly one ordering, and it is not `deriving Ord`.**

Derived `Ord` compares by constructor position: `NRat (1%2)` and `NInt 1` never compare numerically,
and `App` nodes compare head-then-arguments rather than by the rules a CAS needs. It is a fine
*total* order — determinism arrives before fidelity — but shipping it and replacing it later means
every golden file changes, which is a bad trade for a week of early convenience.

So `Cassini.Core.Order` implements Cohen's order relation directly:

```haskell
-- | Cassini.Core.Order
--
-- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.2, rules O-1 … O-13.
compareCanonical :: Expr -> Expr -> Ordering
```

The rules, transcribed because they are the specification:

| Rule | Case | Order |
| :--- | :--- | :--- |
| O-1 | both constants | numeric `<` |
| O-2 | both symbols | lexicographic — `compareSymbolName` (§3.2), never `Ord Symbol` |
| O-3 | both products (or both sums) | compare last operands, then next-to-last, …; if one is a suffix of the other, shorter first |
| O-4 | both powers | bases first; if equal, exponents |
| O-5 | both factorials | operands |
| O-6 | both functions | names first; if equal, arguments left-to-right, first argument most significant; if one argument list is a **prefix** of the other, shorter first |
| O-7 | number vs anything else | the number first |
| O-8 | product vs power/sum/factorial/function/symbol | compare as products (recur into O-3) |
| O-9 | power vs sum/factorial/function/symbol | compare as powers, `v` read as `v^1` (recur into O-4) |
| O-10 | sum vs factorial/function/symbol | compare as sums (recur into O-3) |
| O-11 | factorial vs function/symbol | `false` if the operand equals `v`, else compare as factorials |
| O-12 | function vs symbol | `false` if the function's name is the symbol, else compare names |
| O-13 | otherwise | `not (v ▹ u)` — the swap rule |

**O-3's and O-6's length tiebreaks are both load-bearing, and O-6's is the one that gets dropped.**
Cohen states each of them (O-3-3 and O-6-2(c)): when the compared operands run out equal, the
expression with fewer operands comes first. Leaving it off O-6 is not a lost tiebreak but a hang —
`g[x]` against `g[x, y]` then satisfies no rule, falls to O-13, and swaps back and forth forever.
It is written into the table above for that reason, and §7.3's totality property is what proves it.

**Strings need a rule, and Cohen does not supply one.** `Shape` has an `SString` constructor
(§3.3) and the Stage 1 parser accepts string literals (§4.10), but Cohen's algebra has no strings and
O-1…O-13 therefore never mention them. That is not a harmless omission: with O-13 as the fallback,
two expressions that no rule covers send `compareCanonical u v` to `compareCanonical v u` and back
forever, so `compareCanonical (Str "a") (Str "b")` — and string-versus-symbol — is a hang, not a
wrong answer. **Every pair of expression *kinds* must be covered by a rule that is not O-13** — kinds,
not `Shape` constructors, because product, power, sum, factorial and function are all `SApp` and the
rules distinguish them. The design adds two, placed so the existing rules are undisturbed:

| Rule | Case | Order |
| :--- | :--- | :--- |
| O-S1 | both strings | lexicographic on the `Text` |
| O-S2 | string vs any non-number | the string first |

O-7 still puts every number ahead of every string, so numbers < strings < everything else, and the
slot §3.1 reserves for inexact numbers is still inside O-7. The totality property in §7.3 is what
catches a future constructor that repeats this mistake: it exercises every pair of *kinds*, and an
uncovered pair diverges rather than returning the wrong `Ordering`.

**Curried heads are a kind, and `exprKind` must say so.** Cohen's O-6 and O-12 read a function's
`Kind` as its *name*, which presumes the head is a symbol; `f[x][y]` — which §4.4's step 12 and
§4.10's grammar both admit — has an `App` for a head and no name. `exprKind` therefore classifies it
as a function whose kind is the head *expression*, and O-6/O-12 compare heads with `compareCanonical`
rather than with O-2. That recursion is well-founded (the head is a strict subterm), which is the
property that keeps it from being a second instance of the O-13 hang.

Two more things fall out that are worth stating, because they look like bugs otherwise. O-3 compares
products **from the right**, so `a·x²` sorts before `x³` and a polynomial comes out in increasing
degree. And O-13 means the table above is upper-triangular: the missing cases are the transposes,
handled by recursion with the arguments swapped. The implementation mirrors that structure —
fourteen cases and one `flip`-with-negate — rather than writing out all sixty-four cells of the
eight-kind table.

`Ord Expr` is defined as `compare = compareCanonical`, or it is not defined at all. There is no third
option in which both exist, because that is exactly how the wrong one gets used by accident.

### 3.6 Traversal

`Cassini.Core.Traversal` provides a base functor and `recursion-schemes` instances:

```haskell
data ExprF r = NumberF !Number | StringF !Text | SymbolF !Symbol | AppF !r !(Vector r)
  deriving stock (Functor, Foldable, Traversable)
type instance Base Expr = ExprF

instance Recursive Expr where
  project e = case exprShape e of
    SNumber n -> NumberF n
    SString t -> StringF t
    SSymbol s -> SymbolF s
    SApp h as -> AppF h as

instance Corecursive Expr where
  embed = \case
    NumberF n -> mkNumber n
    StringF t -> mkString t
    SymbolF s -> mkSymbol s
    AppF h as -> mkApp h as
```

**Both instances are written out, and neither may be left empty.** `recursion-schemes` supplies
`Generic`-based defaults for `project`/`embed`, but they need `Rep Expr` and `Rep (ExprF Expr)` to
line up, and they do not: `Expr` is a three-field record carrying a hash and an intern id that the
base functor has no room for. An empty instance therefore does not compile — and the tempting
repair, rebuilding the record by hand, is worse than the error, because it produces nodes with a
stale `exprHash` and `notInterned` in `exprId`: everything still *works*, `Eq` is quietly wrong, and
nothing fails until a golden file does. Naming `mkNumber`/`mkString`/`mkSymbol`/`mkApp` in `embed`
is the entire argument below, made mechanical.

**`recursion-schemes` over `uniplate`**, for one reason that outweighs the extra concept: `embed`
goes through the smart constructors, so every `cata`/`ana`/`para` automatically maintains the hash
and the intern id. With `uniplate`'s `transform`, rebuilding is the caller's business and a single
place that forgets is a silently un-interned subtree with a stale hash — a bug that survives testing
because everything still *works*, just slower and with `Eq` quietly wrong.

For the handful of places where a plain "rewrite everywhere until fixed" is what is meant,
`Cassini.Core.Traversal` exports `rewriteM :: (Monad m) => (Expr -> m (Maybe Expr)) -> Expr -> m
Expr`, so callers never touch the generic machinery directly. It is written as a direct recursion
over `project`/`embed` and not "on top of `apo`": `recursion-schemes` 5.2.3 exports no monadic
folds or unfolds at all — no `apoM`, no `cataM` — so an `m`-valued rewrite cannot be expressed in
terms of `apo`, whose coalgebra is pure. Checked against the package's export list. The monadic
shape is not optional, because the callers that want this are the ones whose rewrite step evaluates
(§4.3), and a pure `rewrite` would only ever serve the cases that could have used `cata`.

`Foldable`/`Traversable` on `ExprF` gives `Cassini.Structure` its whole implementation almost for
free, which is the other half of the argument.

### 3.7 Structure-based operators

`Cassini.Structure` implements the primitive expression-inspection operators — Cohen calls them
`Kind`, `Operand`, `Number_of_operands`, `Construct`, `Free_of`, `Substitute`,
`Sequential_substitute`, `Concurrent_substitute`
(`references/papers/textbooks/cohen2002_*.pdf` §3.3).

The observation that shapes the module: **those are the same operators the Wolfram Language exposes
as `Head`, `Part`, `Length`, `Apply`, `FreeQ` and `ReplaceAll`.** Cohen's structure-based operators
and WL's structural builtins are one set of functions with two names. So `Cassini.Structure` is
written once as a Haskell API, and `Cassini.Builtins.Structural` is a thin layer that binds those
functions to symbols. Nothing is implemented twice.

```haskell
-- | Cassini.Structure
exprKind      :: Expr -> Kind
part          :: Expr -> Int -> Either PartError Expr   -- 0 is the head
numberOfParts :: Expr -> Int
construct     :: Expr -> Vector Expr -> Expr
freeOf        :: Expr -> Expr -> Bool
substitute    :: Expr -> Expr -> Expr -> Expr           -- in u, t -> r
substituteSeq :: Expr -> [(Expr, Expr)] -> Expr
substituteAll :: Expr -> [(Expr, Expr)] -> Expr         -- concurrent
```

`part` returns `Either` rather than being partial — the relude constraint in §2.3 and the language's
own semantics agree here, since `Part` on an out-of-range index must produce a message, not a crash.

Note that `substitute` compares **complete subexpressions** structurally, which is why interning
pays for itself here: with a table, the comparison at every node is an `Int` test.

---

## 4. Stage 1 — the kernel

Stage 1 is a Wolfram-Language-subset evaluator: attributes, four rule tables, the standard
evaluation sequence, a pattern matcher, automatic simplification, differentiation, and enough
surface syntax to type at it.

**Exit criterion:** `Plus[a, Plus[b, a]]` flattens, sorts and *collects* to `2a + b`; `D` gets the
product and chain rules right. See §10.

### 4.1 Attributes

```haskell
-- | Cassini.Attributes
newtype AttributeSet = AttributeSet Word32
  deriving newtype (Eq)
  deriving (Semigroup, Monoid) via (Ior Word32)   -- Data.Bits: union of attribute sets

data Attribute
  = Orderless | Flat | OneIdentity | Listable
  | HoldFirst | HoldRest | HoldAll | HoldAllComplete
  | SequenceHold | Protected | Constant | ReadProtected
  | NHoldFirst | NHoldRest | NHoldAll | Locked | Stub | Temporary
```

A bitmask, because the evaluator asks four or five attribute questions per step and a `Set`
allocation per question is not acceptable in that loop. The monoid is bitwise-or, taken via
`Data.Bits.Ior` rather than `deriving newtype` — `Word32` has no `Semigroup` instance of its own, so
the newtype-derived version does not compile, and naming `Ior` says which of the four plausible
bitwise monoids is meant. The predicates the evaluator actually calls
are named functions (`holdsArgument :: AttributeSet -> Int -> Int -> Bool` — attributes, index,
arity), not raw bit tests, so the `HoldFirst`/`HoldRest` index arithmetic lives in one place.

`OneIdentity` is not an evaluator attribute at all: it affects matching only, and is consumed in
`Cassini.Pattern.Commutative` and `.Sequence`. It is listed here and used there, which is a seam
worth flagging because getting it backwards is a documented easy mistake.

### 4.2 Rules and the four tables

```haskell
-- | Cassini.Rules
data Rule = Rule
  { ruleLhs      :: !Expr          -- ^ the pattern
  , ruleBody     :: !RuleBody
  , ruleSpecificity :: !Specificity
  , ruleOrigin   :: !Origin        -- ^ which rung of the §4.4 ladder this rule is on
  }

data RuleBody
  = Immediate !Expr                -- ^ '->': RHS already evaluated at definition time
  | Delayed   !Expr                -- ^ ':>': RHS evaluated after substitution
  | Native    !BuiltinId           -- ^ a Haskell implementation; 'Builtin' origin only

newtype BuiltinId = BuiltinId Int
  deriving newtype (Eq, Ord)

-- | The ladder, in one place. 'Ord'/'Enum' on 'ValueKind' is EnumMap key order,
-- *not* this order: never walk 'siValues' in key order to drive steps 10-13.
--
-- The lower two rungs are 'DownValue' or 'SubValue' according to the shape of the
-- expression being evaluated, so the ladder is a function of it and not a constant.
ladder :: Expr -> [(ValueKind, Origin)]
ladder e = [(UpValue, User), (UpValue, Builtin), (down, User), (down, Builtin)]
  where
    down = case e of
      App (App _ _) _ -> SubValue   -- h[...][...]
      _               -> DownValue  -- h[e1, ...]

data ValueKind = OwnValue | DownValue | UpValue | SubValue
  deriving stock (Eq, Ord, Enum, Bounded)

data Origin = User | Builtin
  deriving stock (Eq, Ord, Enum, Bounded)

newtype RuleSet = RuleSet (Seq Rule)     -- ^ ordered; first applicable wins

data SymbolInfo = SymbolInfo
  { siAttributes :: !AttributeSet
  , siValues     :: !(EnumMap ValueKind RuleSet)
  }
```

**A `Rule` must be able to hold Haskell, or no builtin can be installed.** §4.6 says `simplify` is
"the built-in downvalues for `Plus`, `Times` and `Power`", §4.9 says `D`'s rules are downvalues on
`Derivative`, and steps 11 and 13 of §4.4 apply *built-in* up- and downvalues. None of `Plus`,
`Part`, `Map`, `Set` or `Factor` is expressible as an `Expr`-to-`Expr` rewrite, so a `Rule` whose
right-hand side is only an `Expr` leaves those four steps with nothing to apply and `Plus[1, 2]`
comes back unevaluated. Hence `RuleBody`, whose third case is a native implementation.

**Why `Native` holds an id and not a function.** A field of type
`forall es. (Kernel :> es) => Subst -> Eff es Expr` would make `Cassini.Rules` import
`Cassini.Eval.Kernel`, which already imports `Cassini.Rules` for `SymbolInfo` — the one import cycle
§2.6's shared rule for those two modules exists to keep out. So `Rule` stays a plain data type and
carries an index; `KernelState` carries the vector of implementations, assembled by
`Cassini.Builtins` (L4) when it builds the initial state, which is what "registry assembly" in §2.2
means. `Cassini.Eval` resolves the id when it interprets `Kernel`. A `BuiltinId` with no entry is a
construction error in `Cassini.Builtins`, not a user-reachable failure.

**`Ord ValueKind` is not the ladder, and the constructor order says the opposite.** Derived `Ord`
and `Enum` put `DownValue` before `UpValue`, so walking `siValues` in `EnumMap` key order tries
downvalues first — precisely the "built-in upvalue beats user downvalue" inversion of §4.4, arrived
at by writing the obvious fold. The order is kept for the same reason §3.1 and §3.5 keep `Number`'s
and `Expr`'s: it is a fine *map key* order and a wrong *semantic* order, and the fix is to never
derive the semantics from it. `ladder e` above is the only list steps 10-13 may iterate, and §7.3's
`Rules` row asserts that `applicableRules` visits the rungs in exactly that sequence.

**`ruleOrigin` is not bookkeeping.** §4.4's ladder is four rungs, not two axes, and the rungs are
`(UpValue, User)`, `(UpValue, Builtin)`, `(DownValue, User)`, `(DownValue, Builtin)` in that order.
A `RuleSet` sorted by specificity alone would let a more specific *user* downvalue be tried before a
less specific *built-in upvalue*, which is exactly the inversion step 11-vs-12 exists to forbid. So
`Cassini.Rules.applicableRules` takes a `(ValueKind, Origin)` pair and scans only the rules carrying
that origin: steps 10-13 walk four disjoint subsets, and specificity orders *within* a rung and never
across one.

**`SubValue` does not add rungs; it is chosen by the expression's shape.** Steps 12 and 13 read
"downvalues (and subvalues)" because which of the two applies is decided by the expression, not by
precedence: `h[e₁, …]` with a symbol head consults `DownValues[h]`, and `h[…][…]` consults
`SubValues[h]`. The two are never both candidates for the same expression, so each of the two lower
rungs resolves to exactly one `(ValueKind, Origin)` lookup and the ladder stays four steps long.

**That is why `ladder` takes the expression.** A four-element constant naming `DownValue` outright
reads as "written once" and is the same bug from the other direction: it would send `f[x][y]` to
`DownValues[f]`, which by construction holds no rule that could match it, so `f[x_][y_] := x + y`
would never fire and the `SubValue` constructor would be dead weight in the type. Making the rung
depend on the shape is one `case`, and it keeps "four rungs, in this order" true while letting the
lower two name the table the expression actually has.

`OwnValues` is not on the ladder at all — it is consulted when a bare symbol is evaluated, which is
§4.4's step 0 guard, not steps 10-13. Step 2 is *not* where it happens, even though step 2
evaluates a head: step 2 evaluates the head by calling `evaluate` on it, and it is that recursive
call's step 0 that applies the ownvalue. Putting the lookup in step 2 itself would apply ownvalues
to heads and to nothing else, so `x = 5; x` would still return `x`.

Four tables, one per `ValueKind`, keyed by symbol — including `OwnValues`, because that is what makes
plain assignment (`x = 5`) fall out of the same machinery as everything else instead of being a
special case in the evaluator.

Ordering within a table is by specificity, with insertion order breaking ties, and
`Cassini.Rules.insertRule` does the ordering at definition time so that lookup is a scan of an
already-sorted sequence. Specificity is a coarse structural measure (fewer blanks and more literal
structure is more specific); it does not need to match WL's exactly, and where it cannot, the
documented behaviour is that definition order decides. Saying so is better than pretending to a
fidelity the design cannot test.

### 4.3 The kernel effect

The kernel monad is `effectful`, and specifically it is **a custom dynamically dispatched effect**
rather than a concrete stack:

```haskell
-- | Cassini.Eval.Kernel
data Kernel :: Effect where
  LookupSymbol  :: Symbol -> Kernel m SymbolInfo
  ModifySymbol  :: Symbol -> (SymbolInfo -> SymbolInfo) -> Kernel m ()
  EmitMessage   :: Symbol -> MessageTag -> [Expr] -> Kernel m ()
  Evaluate      :: Expr -> Kernel m Expr   -- ^ the knot-tying operation; see below
  Iterations    :: Kernel m Int            -- ^ remaining fixed-point fuel
  SpendIteration:: Kernel m ()
  WithFuel      :: Int -> m a -> Kernel m a  -- ^ run with a fresh fuel budget
  Descend       :: m a -> Kernel m a       -- ^ one level deeper; '$RecursionLimit' aborts
type instance DispatchOf Kernel = Dynamic

lookupSymbol :: (Kernel :> es) => Symbol -> Eff es SymbolInfo
lookupSymbol = send . LookupSymbol
```

Kernel functions are written constraint-polymorphically over what they actually need:

```haskell
evaluate :: (Kernel :> es) => Expr -> Eff es Expr
matchOne :: (Kernel :> es) => Expr -> Expr -> Eff es (Maybe Subst)
```

**`Evaluate` is what makes the layering in §1.2 hold, and it is not a convenience.** Two modules
below `Cassini.Eval` have to evaluate: the matcher, for `/;` side conditions and `?f` tests
(§4.5.2), and `Cassini.Zero`, for structural simplification and evaluation at random points (§5.6).
Both are outside the `within` list of §2.6's `Cassini.Eval` rule and must stay there — importing the
evaluation *sequence* downward is the cycle the layering exists to forbid. Carrying `(Kernel :> es)`
alone does not solve it: a constraint gives you the effect's operations, not `Cassini.Eval`'s
functions. So `evaluate` is an *operation* of the effect, `Cassini.Eval` installs the real evaluation
sequence when it interprets `Kernel`, and callers below L3 reach it through `send` without naming the
module. This is the one place the effect is dynamically dispatched for a reason other than testing.

**`WithFuel` is the reset, and its absence would be a slow-burning bug.** `Iterations` and
`SpendIteration` alone give one monotonically draining counter for the life of the `KernelState`,
so a REPL session would spend its previous inputs' budget — every session would eventually hit
`$IterationLimit::itlim` on inputs that terminate in one round. `WithFuel n` is a higher-order
operation (hence the `m a` argument): it runs its body with the counter set to `n` and restores the
caller's remaining fuel afterwards.

**Exactly one caller sets the budget, and it is the REPL.** `$IterationLimit` bounds *one top-level
evaluation*, so `WithFuel` is called once per input, with the limit from `EvalConfig`; §4.4's
`fixpoint` only reads `Iterations` and calls `SpendIteration`. Letting `fixpoint` open a fresh
`WithFuel` instead would make the REPL's call dead code and hand every nested `evaluate` a full
budget — the bound on a runaway input would become the limit raised to the recursion depth rather
than the limit, and a rule whose right-hand side evaluates a subexpression each round would spin for
minutes before anything stopped it. Per-*evaluate* fuel and per-*input* fuel are different designs;
this is the second.

**"Once per input" means once per *top-level* evaluation, and the test suite is a caller too.**
There is no REPL under `runKernelPure`, so a property that calls `evaluate` twice on one interpreter
run — §7.3's `evaluate . evaluate ≡ evaluate` is exactly that — has the second call spending what
the first left. A subject taking `k` rounds followed by a subject taking `k` more exhausts a budget
of `2k - 1` and the second call returns `Hold[…]`, so the law fails on a property of the harness
rather than of the evaluator, and it fails intermittently as generated sizes vary. Each `evaluate`
a test performs is a top-level evaluation and gets its own `WithFuel`; `Test/Gen.hs`'s evaluation
helper opens it, which is why the rule is "one per top-level evaluation" and not "one call site in
the tree".

**`Descend` is the other limit, and it is not the same one.** `$IterationLimit` counts rounds of one
fixed point; `$RecursionLimit` bounds how deep nested evaluation nests, and §4.7 makes its exhaustion
an `Abort`. Nothing in `Iterations`/`SpendIteration` measures depth, so without a second operation
`f[x_] := f[x] + 1` recurses through nested `Evaluate` calls until the RTS stack overflows — which is
a crash, not the message the language promises. `Descend` wraps the body one level deeper and throws
`Abort` past `$RecursionLimit`; `Evaluate`'s interpretation in `Cassini.Eval` is its only caller,
which is what makes the count automatic rather than something each builtin has to remember.

**Why this and not `ReaderT Env IO` with `IORef`s.** Two interpreters over one effect:

```haskell
runKernelIO   :: (IOE :> es)
              => EvalConfig -> IORef KernelState -> Eff (Kernel : es) a
              -> Eff es (Either Abort a)

runKernelPure :: EvalConfig
              -> KernelState
              -> Eff (Kernel : es) a
              -> Eff es (Either Abort a, KernelState)
```

`runKernelPure` is `reinterpret (runReader cfg . runState s0 . runErrorNoCallStack) handler`: it
introduces `Reader EvalConfig`, `State KernelState` and `Error Abort` for its own use and discharges
all three, so the caller's `es` never mentions them. The config and the initial state have to be
arguments and the final state has to be in the result — a signature that dropped any of them would
not be implementable, since there is nowhere for them to come from or go. `runKernelIO` takes the
same `EvalConfig` alongside its `IORef`.

**Both interpreters return `Either Abort a`, and the `IO` one is not exempt.** `Abort` is not a
testing artefact: `Abort[]`, an interrupt and `Descend`'s `$RecursionLimit` exhaustion (below) all
raise it, and they raise it in production, which is the only place a user can type `Abort[]` at all.
So `runKernelIO` introduces and discharges `Error Abort` exactly as `runKernelPure` does, and hands
the `Left` to the REPL to report as `$Aborted`. An `Eff es a` there would leave the effect
undischarged — a type error if `Descend` uses `throwError`, and a raw `IO` exception escaping the
kernel if it does not, which is the one thing §4.7 says the evaluator never does. It keeps
`KernelState` out of its result for the reason `runKernelPure` keeps it in: the state is the
caller's `IORef` and the caller already has it.

`runKernelIO` is production — mutable state, the intern table, timing, interrupts. `runKernelPure`
has no `IOE` at all, and is what the property tests run under: the evaluator becomes a pure function
from an initial `KernelState` and an expression to a final state and an expression, which is
testable, shrinkable and reproducible in a way an `IORef`-in-a-`Reader` never is. That is the
argument for the effect system here, and it is a testing argument first and an elegance argument
second.

`Reader EvalConfig` carries the knobs that never change mid-evaluation (`$IterationLimit`,
`$RecursionLimit`, output form). `State KernelState` carries the symbol table.
`Error Abort` carries `$Aborted` and interrupt. `IOE` appears **only** in `runKernelIO`'s
constraint and in the REPL — every other signature in the kernel is `IOE`-free, and CI enforces that
by compiling the pure interpreter's test suite without it.

`Effectful.State.Static.Local` rather than `.Shared`: the kernel is single-threaded, and `Local` is
the faster of the two. Parallel evaluation, if it ever arrives, changes this line and is noted in
§11.2 so that it is a decision rather than a discovery.

### 4.4 The standard evaluation sequence

This is a transcription, not a design. The source is
`references/papers/wolfram-language/wolfram_ref_evaluation.html`, "The Standard Evaluation Sequence",
and the numbering below is this repository's (see `references/papers/wolfram-language/CLAUDE.md` for
how it relates to the page's own).

For `h[e₁, …, eₙ]`:

1. If the expression is a raw object (number, string), leave it unchanged.
2. Evaluate the head `h`.
3. Evaluate each element `eᵢ` in turn.
4. If `h` has `HoldFirst`/`HoldRest`/`HoldAll`/`HoldAllComplete`, skip evaluation of certain elements.
5. Unless `h` has `SequenceHold` or `HoldAllComplete`, flatten out all `Sequence` objects among the `eᵢ`.
6. Unless `h` has `HoldAllComplete`, strip the outermost of any `Unevaluated` wrappers.
7. If `h` has `Flat`, flatten out all nested expressions with head `h`.
8. If `h` has `Listable`, thread through any `eᵢ` that are lists.
9. If `h` has `Orderless`, sort the `eᵢ` into order.
10. Unless `h` has `HoldAllComplete`, apply **user** upvalues for `h[f[…], …]`.
11. Apply **built-in** upvalues associated with `f`.
12. Apply **user** downvalues (and subvalues) for `h[e₁, …]` or `h[…][…]`.
13. Apply **built-in** downvalues (and subvalues) for the same.

Then the fixed point: every time the expression changes, start over.

The implementation is one function whose body is thirteen named calls plus one guard the source does
not number, each separately testable:

```haskell
-- | Cassini.Eval
evaluate :: (Kernel :> es) => Expr -> Eff es Expr
evaluate = fixpoint step
  where
    -- Steps 0 and 1 are *guards* on the other twelve, not stages before them.
    step e
      | evalStep1Raw e = pure e
      | Sym s <- e     = evalStep0Own s          -- OwnValues; see below
      | otherwise =
              evalStep2Head e
          >>= evalStep34ArgsHold
          >>= evalStep5Seq   >>= evalStep6Uneval  >>= evalStep7Flat
          >>= evalStep8List  >>= evalStep9Order   >>= evalStep10UserUp
          >>= evalStep11BuiltinUp >>= evalStep12UserDown >>= evalStep13BuiltinDown

    -- Step 4 is a *gate* on step 3, not a stage after it.
    evalStep34ArgsHold e = evalStep4Hold e >>= \held -> evalStep3Args held e
```

**Step 1 is a guard, for the same reason step 4 is.** "Leave raw objects unchanged" is not a stage
that can sit at the head of a `>>=` chain: a link can only return the expression and let the other
twelve run on it. `evalStep1Raw` is therefore a predicate, not an `Expr -> Eff es Expr`. Written as
a link it would hand `Num 3` to `evalStep2Head`, which has no head to evaluate, and to
`evalStep34ArgsHold`, whose held-position mask is computed from an argument list a number does not
have — a partial function reached on every integer literal, forbidden by §2.3 and found by whichever
test evaluates `2` first. It would also send every raw object round the ladder, looking up
downvalues on `Integer` once per fixed-point round for an expression that by construction can never
change.

**A bare symbol is the second guard, and the transcription above does not cover it.** The source
page's sequence is written for `h[e₁, …, eₙ]` and says nothing about an expression that is just
`x` — but `evaluate` is called on every subterm, so `Sym x` reaches `step` constantly, and
`evalStep1Raw` is false for it: a symbol is not a raw object. Falling through to `evalStep2Head`
gives it exactly the treatment the paragraph above forbids for `Num 3` — no head to evaluate, no
argument list from which to compute the held-position mask. So `evalStep0Own` is a second guard,
numbered 0 because it is not one of the source's steps, and it is where `OwnValues[x]` is consulted:
`x = 5` is an ownvalue on `x`, and steps 10–13 are all keyed on an application's head or an
argument's head, so none of them can ever apply it. Without this guard `x = 5; x` returns `x`, and
that is not a missing feature — it is the whole of plain assignment.

`evalStep0Own` is a guard rather than a link for the reason step 1 is: it returns the ownvalue
replacement (or the symbol unchanged) and the remaining twelve steps do not apply to it. The
fixed point then re-enters `step` with whatever the ownvalue was, which is what makes `x = y; y = 5;
x` reach `5`.

**Steps 3 and 4 are one pass, and this is the one place the repository's numbering misleads.**
The numbering comes from splitting the source page's third bullet in two
(`references/papers/wolfram-language/CLAUDE.md`), and the split is a *description* of two things to
implement, not a sequence of two passes. Running `evalStep3Args` and then `evalStep4Hold` would
evaluate every element and only afterwards decide which ones were held, which is not skipping
evaluation — it is doing it and then forgetting. `Hold[1+1]` would return `Hold[2]`, and
`SetDelayed` would evaluate its right-hand side. So `evalStep4Hold` computes the held-position mask
from the head's attributes and `evalStep3Args` consumes it; both stay separately named and
separately testable, and the golden traces (§7.4) still record them as two entries.

Not because an eleven-link `>>=` chain is beautiful, but because each step is then a function with
a name, a unit test, and a golden trace — and because the three easy mistakes below are structurally
impossible to make once the steps are separate values in a fixed order.

**The three traps, called out because the sequence exists to prevent them:**

- **Attribute order is `Flat` → `Listable` → `Orderless`** (steps 7–9). Flattening must precede the
  canonical sort. The coarser summary in the companion tutorial names them in a different order; it
  is a summary of *what* happens, not of sequence.
- **`Sequence` splicing precedes `Unevaluated` stripping** (steps 5–6).
- **Rule application is a four-way ladder** (steps 10–13), not two independent axes: user upvalues →
  built-in upvalues → user downvalues → built-in downvalues. The consequence that a two-axis
  implementation gets wrong is that **built-in upvalues beat *user* downvalues.** `Cassini.Rules`
  models this as a single ordered list of four `(ValueKind, Origin)` pairs, so there is no place to
  put the axes and no way to nest the loops the wrong way round.

`Hold`, `HoldComplete`, `HoldForm`, `ReleaseHold` and `Unevaluated` are **not** evaluator special
cases. They are attributes plus ordinary definitions, and **none of the thirteen steps may contain a
branch naming any of them**. Any patch that adds one is a bug.

The one exception is stated here so that it is not read as a violation of that rule: `fixpoint`
*constructs* a `Hold` on iteration-limit exhaustion (below). Constructing the wrapper is not
special-casing the head — no step asks whether an expression *is* a `Hold`, which is the property the
rule is protecting.

**The fixed point is fuelled.** `fixpoint` calls `SpendIteration` on each round, reads `Iterations`,
and on exhaustion emits `$IterationLimit::itlim` and returns the expression wrapped in `Hold` — the
language's own behaviour, and the alternative to a hang. Non-termination is a *user* error in a
rewriting system, so it gets a message, not an exception. `fixpoint` does **not** call `WithFuel`:
the budget is opened once per REPL input (§4.3), so the limit is per top-level evaluation and a
nested `evaluate` spends its caller's rounds, which is what makes the bound a bound. Depth is the
other limit and is `Descend`'s job, not this one's.

### 4.5 Pattern matching

The hard engineering, and the part with no off-the-shelf Haskell answer.

#### 4.5.1 The pattern language

Patterns are `Expr`s, as in WL — `Blank[]` is just a symbol applied to nothing — with a view type for
the matcher's convenience:

```haskell
-- | Cassini.Pattern
data PatternView
  = PBlank      !(Maybe Symbol)               -- ^ _h
  | PBlankSeq   !(Maybe Symbol)               -- ^ __h  (one or more)
  | PBlankNull  !(Maybe Symbol)               -- ^ ___h (zero or more)
  | PNamed      !Symbol !PatternView          -- ^ x:patt, x_
  | PCondition  !PatternView !Expr            -- ^ patt /; test
  | PTest       !PatternView !Expr            -- ^ patt ? f
  | PAlternative ![PatternView]               -- ^ p | q
  | PRepeated   !PatternView !(Int, Maybe Int)
  | POptional   !PatternView !(Maybe Expr)
  | PLiteral    !Expr
  | PCompound   !PatternView !(Vector PatternView)

viewPattern :: Expr -> PatternView
```

`Subst` is a `Map Symbol Binding` where a binding is either one expression or a sequence, because
sequence variables bind argument runs rather than single terms.

#### 4.5.2 The matcher monad, and why nondeterminism cannot be an effect

**No `effectful` handler can enumerate matches, and this is structural rather than a gap awaiting a
release.** `Eff es` is `Env es -> IO a`; a handler runs its continuation once, and there is no way to
run one branch, return, and run the next from the same suspension point. `effectful`'s README states
the limitation and names the remedy:

> The `Eff` monad in `effectful` does not support effect handlers that require suspending or
> capturing and resuming computations. This limitation prevents the implementation of certain
> features like a `NonDet` effect handler for collecting results from multiple `Alternative`
> branches or a `Coroutine` effect. However, existing libraries like `conduit` or `list-t` can be
> used with `effectful` if these capabilities are needed.

`Effectful.NonDet` is what that limitation forces, not an unambitious choice: it is `Maybe`-shaped,
obeying left-catch, so `a :<|>: b` runs `b` only if `a` calls `Empty`. That gives first-success
backtracking. But `ReplaceList`, `//.`, `Cases`, and Krebber's algorithm itself all need *every*
match enumerated, and a `Maybe`-shaped alternative cannot produce a second one.

So nondeterminism sits outside the effect system, in a transformer over `Eff` — the shape the README
points at. `Eff` is the base monad, not `Identity`, because side conditions must evaluate: `patt /;
test` requires evaluating `test` under the current substitution — through the `Kernel` effect's
`Evaluate` operation (§4.3), not by importing `Cassini.Eval`, which §2.6 forbids it — and `?f` requires
applying a function. The matcher genuinely needs kernel access, and a transformer over `Eff` gives it
without giving up enumeration.

**`MatchT` is a newtype, and deliberately not a synonym.** A
`type MatchT es = LogicT (Eff es)` would put `logict` in scope in all four matchers of §4.5.3 and
make `observeAllT` callable from any of them; the containment §9.2 relies on would be a claim about
programmer restraint. The newtype plus an export list makes it a property of the module graph, and
the `Control.Monad.Logic` rule in §2.6 confines it to this one module so CI fails on a
violation:

```haskell
-- | Cassini.Pattern.Match
newtype MatchT es a = MatchT (LogicT (Eff es) a)
  deriving newtype (Functor, Applicative, Monad, Alternative, MonadPlus)

-- The three functions the rest of the matcher is allowed to know about.
liftMatch    :: Eff es a -> MatchT es a          -- MatchT . lift; the kernel call
observeFirst :: MatchT es a -> Eff es (Maybe a)  -- observeManyT 1, lazily
observeAll   :: MatchT es a -> Eff es [a]        -- observeAllT

match    :: (Kernel :> es) => PatternView -> Expr -> Subst -> MatchT es Subst

matchOne :: (Kernel :> es) => Expr -> Expr -> Eff es (Maybe Subst)
matchOne p s = observeFirst (match (viewPattern p) s mempty)

matchAll :: (Kernel :> es) => Expr -> Expr -> Eff es [Subst]
matchAll p s = observeAll (match (viewPattern p) s mempty)
```

`deriving newtype` needs no `LANGUAGE` pragma: `GeneralisedNewtypeDeriving` is in GHC2021 and
`DerivingStrategies` in GHC2024, so this costs nothing against §2.4's rule that extensions are
declared per module.

**Those three functions and those five instances are the entire surface a replacement backend must
reproduce.** Nothing else in `Cassini.Pattern.*` may name `LogicT`, which is what makes D11's swap a
one-module change rather than an audit — see §9.2 for the two candidate replacements and §11.2 for
the trigger.

One implementation, two observation functions. The laziness of the underlying `LogicT` is why
`matchOne` genuinely stops at the first success rather than computing all matches and taking the
head — which matters, because the number of matches is exponential in the general case. A
replacement backend that lost that would be a regression even if it were faster on `matchAll`.

**The backtracking rule, stated once:** all matcher state lives in the `Subst` value threaded through
`match`, never in an effect. A failed branch is abandoned by dropping a value, so nothing needs
rolling back. This sidesteps the hazard `effectful` documents as `OnEmptyPolicy` — the design avoids
the question rather than configuring an answer to it, and the property test in §7.3 (matching leaves
`KernelState` unchanged except for messages) is what keeps it true.

**The rule is about the matcher, not about what a side condition does.** `/;` and `?f` evaluate
arbitrary expressions through `Evaluate`, and an expression may assign: `MatchQ[3, _?((z = 5;
IntegerQ[#]) &)]` writes `z` on a branch that may then fail, and the write stays. That is WL's
behaviour and not something to fix — but it means the §7.3 property has to be stated over
side-condition-free patterns, or it fails on the first generated `PCondition` containing a `Set` and
gets read as a matcher bug. `genPattern` (§7.3) does not build side conditions, so the property is
exercised on exactly the patterns it holds for; the restriction is written down so that widening the
generator later does not quietly turn a true law into a flaky one. It is also what makes the choice
of backend inside `MatchT` a performance question and nothing more: no backend can be obliged to
restore state that was never mutated.

#### 4.5.3 Staging

Four matchers, one interface, added in order:

1. **`Cassini.Pattern.Syntactic`** — structural, no attributes. Blanks, named patterns, conditions,
   alternatives, literals. Every later matcher calls back into this one.
2. **`Cassini.Pattern.Sequence`** — `BlankSequence`/`BlankNullSequence` against a flat argument list.
   This is the combinatorial part even without commutativity: distributing *n* arguments among *m*
   sequence variables. Implemented over `Vector` slices so a candidate distribution costs no copying.
3. **`Cassini.Pattern.Commutative`** — `Orderless` heads. §4.5.4.
4. **`Cassini.Pattern.Net`** — many-to-one discrimination net. Stage 1b, behind the same interface.

#### 4.5.4 Commutative matching: the five phases

Matching a commutative head by trying all *n!* permutations is correct and unusable. The design
follows the ordering in `references/papers/pattern-matching/krebber2017_ac_matching_thesis.pdf`
§3.3.1, which does cheap submatches first so that expensive ones face a smaller search space.

Given a multiset `P` of pattern arguments and `S` of subject arguments:

1. **Constant patterns** (ground terms). Form `P ∩ G`. If it is not a sub-multiset of `S`, fail
   immediately. Otherwise remove the matched pairs from both. Cheap, and prunes hard.
2. **Already-bound variables.** For `x` already in the substitution, build the multiset of its
   binding repeated once per occurrence in `P`; if that is not contained in `S`, fail; otherwise
   remove. Also cheap, also prunes.
3. **Non-variable patterns.** Group patterns and subjects by head — only equal heads can match — and
   chain the resulting submatches in `MatchT`, because two patterns may share a variable and the
   matches are therefore not independent. After this phase, **repeat phase 2**, since new bindings
   have appeared.
4. **Regular variables.**
5. **Sequence variables.** The most expensive, facing the smallest remaining problem.

**Every phase stays in `MatchT`; none of them may call `matchOne`.** `matchOne` is `observeFirst`
(§4.5.2) — it commits to a submatch and throws the alternatives away, and a later phase then has
nothing to backtrack into. Concretely, with `P = {g[x_], x_}` against `S = {g[1], g[2], 2}`, phase 3
matching `g[x_]` with `matchOne` binds `x = 1`, phase 4 cannot then find `1` among the leftovers, and
the matcher reports failure even though `x = 2` matches. `matchOne` and `matchAll` are the two
*observation* functions at the boundary of the matcher; inside it, phases compose in `MatchT` and the
alternatives stay live.

Phases 1–2 are the whole reason this is tractable in practice; they are also the phases most
tempting to skip when writing the first version. They are not optional.

The complexity facts that set expectations: general AC matching is NP-complete, and *linear* AC
matching (no repeated pattern variable) is O(|s|·|t|³) — both results are in
`references/papers/pattern-matching/benanav1987_complexity_of_matching_problems.pdf`. The practical
algorithm for the general case, via a hierarchy of bipartite graph matching problems, is
`references/papers/pattern-matching/eker1995_associative_commutative_matching.pdf`; phase 3's
head-grouping is the cheap approximation of it, and the full construction is where phase 3 goes when
it becomes the bottleneck.

#### 4.5.5 The discrimination net, and when to build it

Not now. `Cassini.Pattern.Net` exists in the module tree from the start as an *interface* — a
`RuleIndex` type that `Cassini.Rules` consults, whose first implementation is a linear scan — so that
swapping in a net later is a new module rather than a refactor.

The trigger is measured, and the measurement is specifically designed (§8.3) to answer the question
`references/papers/pattern-matching/krebber2017_ac_matching_thesis.pdf` ch. 4–5 poses: **the
break-even is in the number of subjects matched, not the size of the pattern set** — the win arrives
for applications matching more than a few hundred subjects, because the net's construction cost has
to be amortized. A large rule table alone is not the signal.

### 4.6 Automatic simplification

The "boring" part that is actually the hard part — failure mode (b) in `notes/cas-haskell.md`.

`Cassini.Simplify.Automatic` implements Cohen's algorithm
(`references/papers/textbooks/cohen2003_*.pdf` §3.2), which is a procedure tree, not one function:

```haskell
-- | Cassini.Simplify.Automatic
simplify :: Expr -> Either Undefined Expr   -- ^ Cohen's Automatic_simplify

-- the subordinate operators, each its own function with its own tests
simplifyRNE       :: Expr -> Maybe Number                       -- Simplify_RNE (§3.1)
simplifyRational  :: Number -> Either Undefined Number
simplifyPower     :: Expr -> Expr -> Either Undefined Expr      -- base, exponent
simplifyIntPower  :: Expr -> Integer -> Either Undefined Expr   -- SINTPOW
simplifyProduct   :: Vector Expr -> Either Undefined Expr       -- SPRD
simplifyProductRec:: [Expr] -> Either Undefined [Expr]          -- SPRDREC
simplifySum       :: Vector Expr -> Either Undefined Expr
simplifySumRec    :: [Expr] -> Either Undefined [Expr]
simplifyQuotient  :: Expr -> Expr -> Either Undefined Expr
simplifyDifference:: Vector Expr -> Either Undefined Expr
simplifyFactorial :: Expr -> Either Undefined Expr
simplifyFunction  :: Expr -> Vector Expr -> Either Undefined Expr
```

Three signature notes, because each is the kind of thing that only shows up when the body is written
and is expensive to change once callers exist.

`simplifyPower` is **binary** — a base and an exponent, as `Power` is. The `Vector Expr` shape
belongs to `simplifyFunction`, whose argument list really is variadic.

The `*Rec` operators return `Either Undefined [Expr]`, not `[Expr]`. They are the merge steps — the
recursive workers that combine two already-simplified operand lists — and they are where like terms
are collected, which means they call `simplifyPower` and `simplifySum` to fuse equal bases and equal
terms. Those can answer `Undefined`, and a total `[Expr] -> [Expr]` has nowhere to put that answer
except a partial function, which §2.3 does not allow. They are separate functions because they are
separately testable and because they are where the bugs live.

`simplifyRNE` is the one operator in `Either`'s place using `Maybe`, and deliberately: it has exactly
one failure, division by zero, and `Maybe` says so without inventing an `Undefined` value for a
`Number`. Its callers map `Nothing` to `Left Undefined`. §3.1 explains why it lives here and not in
`Cassini.Number`.

**The normal form is a specification, not a hope.** Cohen calls it an ASAE (automatically simplified
algebraic expression) and gives it as eight conditions: integers; reduced fractions; symbols other
than `Undefined`; products whose operands are each ASAEs with at most one constant first, no nested
products, no two operands with the same base, at least two operands, and operands in canonical
order; sums under the corresponding conditions; powers with a simplified base and exponent and a
base that is not `0` or `1`; factorials of non-integer ASAEs; and functions of ASAEs.

`isASAE :: Expr -> Bool` implements those eight conditions directly, and it is not test-only code —
it is exported, and it is the postcondition assertion the property tests use.

**Two contracts the source states, which become two free property tests:**

- For a basic algebraic expression `u`, `simplify u` returns an ASAE or `Undefined`.
- **For an ASAE `u`, `simplify u` returns `u`.** Idempotence, stated by the source, and a much
  stronger test than `simplify (simplify x) == simplify x` because it also asserts that `isASAE`
  and `simplify` agree about what "simplified" means.

**Where this attaches to the evaluator.** `simplify` is installed as the built-in downvalues for
`Plus`, `Times` and `Power` — step 13. It is not called from the evaluation loop directly, and it is
not a preprocessing pass. From the evaluator's side it is a rule like any other; from its own side it
is a total function with a normal form. That seam is §1.3, made concrete.

### 4.7 Failure, messages, and `Undefined`

**The evaluator never throws on user error.** A malformed expression evaluates to itself, with a
message emitted. `Part[{1,2},5]` returns `Part[{1,2},5]` unevaluated and emits `Part::partw`. This is
the language's semantics and it is also the right engineering: in a rewriting system, "no rule
applied" and "the input was wrong" are the same situation, and there is no stack to unwind to.

```haskell
-- | Cassini.Eval.Message
data Message = Message { msgSymbol :: !Symbol, msgTag :: !MessageTag, msgArgs :: ![Expr] }
```

Messages accumulate in `KernelState` and are drained by the REPL. `Error Abort` is reserved for
things that genuinely stop evaluation: `Abort[]`, interrupt, and `$RecursionLimit` exhaustion.

Cohen's `Undefined` and the language's unevaluated-plus-message are reconciled at one point:
`simplify` returns `Either Undefined Expr`, and `Cassini.Builtins.Arithmetic` turns a `Left` into
`Indeterminate` or `ComplexInfinity` plus the appropriate message, per the operation. Keeping
`simplify` in `Either` rather than in the kernel effect is what allows it to be tested as a pure
function.

### 4.8 Zero testing is not available here

Stated in Stage 1 because it constrains Stage 1's ambitions: **there is no general algorithm for
deciding whether a symbolic expression is zero** (`references/papers/foundations/richardson1968_*.pdf`).

The consequence for automatic simplification is that it must never *need* a zero test it cannot
perform. Cohen's algorithm is written to this constraint — it decides zero only for rational numbers
and for structurally identical operands — and the design's job is to not add a rule that quietly
requires more. The full layered zero test arrives with the polynomial substrate (§5.6); until then,
`Cassini.Zero` exports only the rational case.

### 4.9 Differentiation

`D` is the classic early win and is genuinely easy, so the design note is short and is about the
thing that is *not* easy: `D` is a builtin whose rules are ordinary downvalues on `Derivative`, not a
Haskell function switching on `Expr` shape. Writing it as a rule table exercises the whole engine —
patterns, attributes, upvalues for user-defined functions — at a point where the engine is small
enough to debug. Writing it as a Haskell `case` would be faster to get working and would test
nothing.

Chain and product rules, `Derivative[n]` for repeated differentiation, and upvalue-based extension so
that a user's own function can define its derivative. The acceptance test is in §10.

### 4.10 Surface syntax and the REPL

Needed for two reasons beyond ergonomics: text fixtures for the regression corpus (§7.4), and the
ability to read a golden file and see what it says.

`Cassini.Syntax.Lexer` and `.Parser` use `megaparsec` — a hand-rolled parser is not where this
project's difficulty should go, and `megaparsec`'s error messages are worth the dependency. The
precedence table is data, in one place, and drives both the parser and `Cassini.Syntax.Pretty`, so
the two cannot disagree about whether `a /. b -> c` parses the way it prints. A round-trip property
(§7.3) enforces that.

The subset for Stage 1: numbers, strings, symbols with contexts, `f[...]`, `{...}`, `a[[i]]`, the
arithmetic and comparison operators, `=`/`:=`/`^=`/`^:=`, `->`/`:>`, `/.`/`//.`, `/;`, `?`, `|`,
`_`/`__`/`___` with names and head constraints, `&`/`#`, `@`/`//`/`~f~`, and `;`. Deferred and noted:
`Span`, string patterns, boxes, anything notebook-shaped.

`Cassini.Syntax.FullForm` is separate from `.Pretty` and is the canonical machine-readable form. All
golden files are FullForm, because pretty-printed output changes when precedence handling improves
and that should not invalidate three hundred regression cases.

`Cassini.REPL` fills the existing `cassini` executable: `In[n]`/`Out[n]` history, `%`, message
display, `Trace`, timing, and a `--script` mode that reads FullForm and writes FullForm, which is the
mode the golden tests drive.

---

## 5. Stage 2 — the polynomial substrate

Everything hard in a CAS runs on polynomial arithmetic and GCD. Building integration or factorization
before this is solid is failure mode (c), and it is the ordering error that kills projects.

**Exit criterion:** correct multivariate GCD and content/primitive-part on non-trivial inputs, and a
zero test that is honest about what it does not know. See §10.

### 5.1 The bridge

`Cassini.Poly.Convert` is the only module in `Cassini.Poly.*` permitted to see an `Expr` (§2.6), and
it is deliberately asymmetric:

```haskell
-- | Cassini.Poly.Convert
--
-- Source: @references/papers/textbooks/cohen2002_*.pdf@ §6.2 (general polynomial
-- expressions), §6.5 (general rational expressions).

-- | A generalized variable is an /expression/, not a symbol: @Sin[x]@ and @x@ are
-- both legitimate here. Ordered by 'compareCanonical' (§3.5), which fixes the
-- exponent-vector layout of every 'Monomial'.
newtype GenVars = GenVars (Vector Expr)

toPolynomial   :: (MonomialOrder ord) => GenVars -> Expr -> Maybe (Multi ord Rational)
fromPolynomial :: (MonomialOrder ord) => GenVars -> Multi ord Rational -> Expr

isPolynomialGPE :: GenVars -> Expr -> Bool
degreeGPE       :: GenVars -> Expr -> Maybe Integer
coefficientGPE  :: Expr -> Integer -> Expr -> Maybe Expr   -- variable, degree, subject
variables       :: Expr -> GenVars
```

Recognition can fail; construction cannot. The `Maybe` is the design's honesty about *generalized
variables*: `Sin[x]` is a legitimate polynomial variable in `Sin[x]^2 + 1`, and whether a
subexpression is a variable or a coefficient depends on the variable list you supply. Cohen treats
this at length and the design does not try to guess — `variables` reports what it found, and callers
say what they want.

**Which is why the variable list is `Expr`s and not `Symbol`s.** A `[Symbol]` cannot name `Sin[x]`,
so an API spelled that way would state the generalized-variable story in prose and then make it
unrepresentable: `toPolynomial` could never be given the variable list that recognizes
`Sin[x]^2 + 1`, `variables` could not report it, and the `Maybe` would be failing on inputs the
design says are in scope. `GenVars` is a newtype rather than a bare `Vector Expr` because its
*order* is load-bearing — it is the exponent-vector layout — and because a bare vector at four call
sites is four chances to pass an unsorted one. Ordering by `compareCanonical` rather than
`compareSymbolName` follows for the same reason: the elements are not all symbols, so there is no
name to compare. Sorting must not use the session-dependent `Ord Symbol` (§3.2) at any point;
`compareCanonical` is deterministic across sessions and `Ord Symbol` is not.

`Cassini.Builtins.Polynomial` is where the guessing happens, once, so that `Factor[x^2-1]` works
without a variable list while the library API stays explicit.

### 5.2 Representations

Two, both parameterized by coefficient type:

```haskell
-- | Cassini.Poly.Uni — dense, coefficients ascending, no trailing zeros.
-- A newtype over @poly@'s 'VPoly', not over 'Vector' directly (§5.3).
newtype Uni a = Uni (VPoly a)

-- | Cassini.Poly.Multi — sparse distributed
newtype Monomial ord = Monomial (Vector Word)   -- exponent vector, fixed variable order
  deriving newtype (Eq)

class MonomialOrder ord where
  compareMonomial :: Monomial ord -> Monomial ord -> Ordering

instance (MonomialOrder ord) => Ord (Monomial ord) where
  compare = compareMonomial

newtype Multi ord a = Multi (Map (Monomial ord) a)
```

**Dense univariate** because that is what fast univariate arithmetic wants and what the modular and
Hensel algorithms operate on. **Sparse distributed multivariate** because multivariate polynomials in
a CAS are overwhelmingly sparse, and because Gröbner bases (§6.1) need a distributed representation
with an explicit monomial order anyway. A recursive representation is deliberately *not* provided: it
is better for some GCD algorithms, and adding it later behind the same operations is a contained
change, whereas maintaining two representations from the start is not.

The monomial order is a type-level parameter, following
`references/papers/haskell/ishii2018_*.pdf`, because mixing lex-ordered and grevlex-ordered
polynomials in one computation is a real bug that types genuinely prevent. Note where the parameter
has to sit: on the **`Monomial`**, so that `Ord` — and hence the `Map`'s ordering, and hence which
term is leading — is determined by it. Putting `ord` only on `Multi` type-checks nothing, because
the parameter would then not be reachable from the key type where it does its work.

### 5.3 Build or buy

The realistic options for the coefficient tower and the univariate arithmetic:

| Option | For | Against |
| :--- | :--- | :--- |
| **`poly` + `semirings`**<br>`references/papers/haskell/poly_hackage.html` | `Vector`-backed, Karatsuba multiplication, `GcdDomain`/`Euclidean` already defined, arity in the type via `vector-sized`, actively maintained | Its `GcdDomain` is not the full tower; multivariate support is a flag; the representation is its choice, not ours |
| **Kmett's `algebra`**<br>`references/papers/haskell/algebra_hackage.html` | The finest-grained hierarchy available, with the `Numeric.Domain.*` chain `Domain → IntegralDomain → GCDDomain → UFD → PID → Euclidean` that a coefficient tower actually wants | Large, and its maintenance cadence is slow |
| **`numeric-prelude` / `numhask`**<br>`references/papers/haskell/numhask_hackage.html` | Principled replacements for `Num`, axioms as QuickCheck properties | Both are whole-prelude commitments, and this project has already spent its prelude budget on relude (§2.3) |
| **Local `Cassini.Algebra.Class`** | Exactly the classes used, no more; no dependency risk | Reinvention, and the laws have to be written anyway |

**Recommendation: `poly` + `semirings` as the substrate, with a thin local `Cassini.Algebra.Class`
on top for the two or three classes `semirings` does not supply.** `poly` is the only option that is
fast, maintained, and already integrated with a class hierarchy; the local module is small precisely
because `semirings` carries `GcdDomain` and `Euclidean`.

The standard `Num` class is not used for coefficients. The reasons are set out in
`references/papers/haskell/numeric_prelude_hackage.html` and they are not stylistic: `Num` defines no
semantics for its operations, carries `Eq` and `Show` as superclasses that some rings cannot satisfy,
mixes representation-specific operations into a semantic interface, and is not finely grained enough,
so defining `+` forces `*` on you. A coefficient tower hits all four.

**The switching cost, stated so it is a decision and not a trap.** `Cassini.Poly.Uni` is a newtype
over `poly`'s `VPoly`/`UPoly` rather than a re-export, so the dependency is behind one module.
Replacing it means rewriting that module, not the GCD and factorization code above it.

### 5.4 GCD

A ladder, cheapest first, each rung a separate function with the same signature so the dispatcher can
choose:

1. **Euclidean** over a field. Correct, and catastrophic over ℤ[x] because of coefficient growth.
2. **Primitive PRS** — content and primitive part at every step. Correct, still slow.
3. **Subresultant PRS** — the standard remedy for coefficient explosion, and the default for small
   problems. Shares `Cassini.Poly.Resultant` with §6.
4. **Brown's modular algorithm** — dense multivariate, via evaluation/interpolation and CRT.
5. **Zippel's sparse interpolation** — sparse multivariate, and the right answer for the inputs a CAS
   actually sees.

Sources: `references/papers/textbooks/geddes_czapor_labahn1992_*.pdf` ch. 7 for the pipeline,
`references/papers/textbooks/vonzurgathen_gerhard2013_*.pdf` for the modular and fast-arithmetic
depth, `references/papers/textbooks/zippel1993_*.pdf` for rung 5.

Rungs 1–3 are Stage 2's requirement. Rungs 4–5 are Stage 2b and are where the benchmark in §8.5
starts to matter, because they are the first place where the asymptotically better algorithm is
slower on small inputs and a dispatcher has to choose.

`content` and `primitivePart` are exported, because they are needed independently by factorization
and by `Together`/`Apart`.

### 5.5 Factorization

The pipeline, each stage a module-level function:

1. **Squarefree decomposition** (Yun's algorithm). Cheap, and required by everything downstream —
   including integration (§6.2), which is why it lands here rather than in §6.
2. **Factorization over 𝔽ₚ** — distinct-degree and equal-degree splitting (Cantor–Zassenhaus), with
   Berlekamp available for small `p`.
3. **Hensel lifting** — from a factorization mod `p` to one mod `pᵏ`. The subtle part, and the one
   where a linear lift is much easier to get right than a quadratic one; ship linear first.
4. **Recombination** — Zassenhaus. Exponential in the number of modular factors in the worst case,
   which is a known and acceptable Stage 2 limitation.
5. **van Hoeij / LLL** — the fix for step 4's worst case. Explicitly out of scope for Stage 2, with
   the interface shaped so it drops in.

Multivariate factorization reduces to univariate by evaluation plus multivariate Hensel lifting, and
follows `geddes_czapor_labahn1992_*.pdf` ch. 8.

The design point worth stating: **steps 1–2 are worth shipping alone.** Squarefree decomposition and
finite-field factorization make `Factor` useful for a large fraction of real inputs, and they are
testable in isolation against a reconstruction property (§7.3). Steps 3–4 are where the schedule
slips, and knowing that 1–2 are independently valuable is what makes it possible to stop there
without the feature being useless.

### 5.6 Zero testing

The module whose type signature is the design.

```haskell
-- | Cassini.Zero
--
-- Source: @references/papers/foundations/richardson1968_*.pdf@ — for the class of
-- expressions over the rationals, π, ln 2, a variable, @+ - *@, composition, and
-- @sin@/@exp@/@abs@, the predicate @E = 0@ is undecidable.
isZero :: (Kernel :> es) => Expr -> Eff es (Maybe Bool)
```

The `Kernel` constraint is not optional: layer 2 needs automatic simplification and layer 4 needs
evaluation at random points, and neither is reachable from a fully polymorphic `es`. Both arrive
through the effect rather than through an import — layer 4 by `send . Evaluate` (§4.3), layer 2 by
the same route, since `Cassini.Zero` may not import `Cassini.Simplify.Automatic` any more than it may
import `Cassini.Eval`: `Cassini.Zero` is in the algebra tower, and §1.2 lets only L4 reach sideways
into it, never the reverse. It is also why `Cassini.Zero` sits with `Cassini.Poly.Convert` on the
`Expr` side of the algebra tower rather than inside it, and why both appear in §2.6's
`Cassini.Core.Expr` rule.

**`Maybe Bool` has three inhabitants and all three are used.** `Just True` and `Just False` are
proofs. `Nothing` is "I do not know", and it is returned honestly rather than being collapsed into
`Just False` — which is the bug that turns an incomplete simplifier into a wrong one.

The layers, tried in order:

1. **Exact numbers.** Decidable, immediate.
2. **Structural identity** after automatic simplification. Sound, not complete.
3. **Polynomial normal form.** For expressions recognizable as polynomials or rational functions in
   their generalized variables (§5.1), the normal form is canonical and zero-testing is decidable.
   This is the layer that does the real work.
4. **Randomized evaluation** at several random points, in exact arithmetic. **One-sided**: a non-zero
   value proves `Just False`; agreement at every point proves nothing and yields `Nothing`. Stated
   explicitly because a randomized zero test that returns `Just True` is the classic soundness bug.
5. **`Nothing`.**

Every caller must handle `Nothing`. In practice that means "leave the expression alone", which is the
correct conservative behaviour throughout: a simplifier that cannot prove a denominator non-zero does
not cancel it.

An SMT backend (`sbv`, offloading to Z3) is a plausible layer 4.5 for side conditions and is recorded
in §11.2 — not adopted, because the dependency is heavy and the payoff is narrow.

---

## 6. Stage 3 — the hard algorithms

Where hobby projects stall. The design's response is to sequence these last, to accept partial
coverage explicitly, and — in the case of integration — to ship a useful thing before the complete
thing.

### 6.1 Gröbner bases

```haskell
-- | Cassini.Groebner
groebnerBasis :: (Field a, MonomialOrder ord) => [Multi ord a] -> [Multi ord a]
reduce        :: (Field a, MonomialOrder ord) => Multi ord a -> [Multi ord a] -> Multi ord a
```

**Buchberger's algorithm first**, with the two Buchberger criteria for discarding S-pairs, and a
selection strategy (normal strategy: smallest lcm first) as a parameter rather than a constant.
Sources: `references/papers/term-rewriting/baader_nipkow1998_*.pdf` ch. 8 for the rewriting-theoretic
account — Gröbner bases *are* completion, and reading them that way is what makes the connection to
§4 visible — and `references/papers/textbooks/geddes_czapor_labahn1992_*.pdf` ch. 10 for the
algorithm as an implementer wants it.

**F4 second**, replacing the S-pair reduction loop with sparse linear algebra over a Macaulay matrix.
It is a strictly larger implementation, it shares nothing with Buchberger except the interface, and
`references/papers/haskell/ishii2018_*.pdf` is the reference for doing it in Haskell with the
monomial order at the type level. F5 is not planned.

The immediate CAS payoff is not Gröbner bases as a user-facing feature but **simplification with side
relations** (`references/papers/textbooks/cohen2003_*.pdf` ch. 8): reducing an expression modulo a set
of algebraic relations, which is how `Simplify` handles `x^2 + y^2 == 1`. That is the acceptance test
for this section, not `GroebnerBasis[...]` itself.

Double-exponential worst-case complexity is not a bug to fix. It is why the property tests here use
small, hand-chosen ideals and why the benchmark suite carries a timeout
(`references/papers/haskell/ishii2018_*.pdf` §3.2 makes the same point about property-testing
Gröbner code).

### 6.2 Integration — three tiers, deliberately

**Tier 1: a rule-based integrator.** This is the design's most opinionated Stage 3 choice.

A Rubi-style ordered decision tree of integration rules
(`references/papers/cas-architecture/rich_rubi_vision.html`) is *exactly* the kind of program this
architecture is: several thousand ordered pattern-matching rules with side conditions, applied by a
rewriting engine with attributes and a fixed-point loop. Everything Stage 1 built is what a
rule-based integrator needs, and nothing else is. Symbolica and Symja both took this route
(`references/papers/cas-architecture/symbolica_2_2_symbolic_integration.html`,
`references/papers/cas-architecture/symja_readme.html`).

So `Cassini.Integrate.Rules` is a rule set loaded into the ordinary rule tables — not Haskell code —
and the work is the loader, the rule syntax, and the side-condition vocabulary. A modest hand-written
rule set covering polynomials, rational functions of one linear denominator, exponentials,
logarithms and the basic trigonometric forms is a few hundred rules and covers most of what a person
types. Porting the full Rubi corpus is a separate, larger project, and its scale is a vendor-reported
figure recorded in `notes/cas-haskell.md` rather than a commitment here.

**Tier 2: rational functions, done properly.** A complete algorithm for a decidable subproblem, and
the right second step because it is finite work with a definite end.
`references/papers/textbooks/bronstein2005_*.pdf` ch. 2: Hermite reduction to split off the rational
part, then Rothstein–Trager or Lazard–Rioboo–Trager for the logarithmic part. Depends on §5.4's
subresultant PRS and §5.5's squarefree decomposition, which is the concrete reason Stage 2 comes
first.

```haskell
-- | Cassini.Integrate.Rational

-- | Variable, numerator, denominator. Total: every rational function has an
-- elementary antiderivative, so there is no failure case to report — see below.
integrateRational :: Symbol -> Uni Rational -> Uni Rational -> Result
```

**It is total, and a `NotElementary` case here would be a lie in the type.** Liouville's theorem
gives every rational function an elementary antiderivative — a rational part plus a sum of
logarithms — and Hermite plus Rothstein–Trager always find it. An `Either NotElementary Result`
would therefore carry a `Left` no input could produce, and every caller would write a branch that
never runs and cannot be tested; worse, the first caller to see the `Either` would read it as
licence to give up on hard inputs. `Result` carries the shape the answer actually has — rational
part, and the logarithmic part as a list of (constant, argument) pairs, which is where the algebraic
extension the constants may live in becomes visible. Tier 3 is where `NotElementary` becomes real,
because for the transcendental case it is an outcome rather than a placeholder.

**Tier 3: the transcendental Risch algorithm.** `bronstein2005_*.pdf` ch. 5–6: differential fields,
monomial extensions, the Risch differential equation, and the case analysis (primitive,
hyperexponential, hypertangent, nonlinear). This is a large, structured implementation and it is
where the schedule genuinely ends.

**The algebraic case is out of scope, and not as a backlog item.** There is no textbook treatment of
it — `notes/cas-haskell.md` §"Caveats" records why — so integration of algebraic functions is
research work rather than implementation work. Saying so here prevents it from appearing on a
roadmap as though it were a matter of effort.

### 6.3 Summation

`Cassini.Summation.Gosper` (indefinite hypergeometric summation) and `.Zeilberger` (creative
telescoping for definite sums), from `references/papers/textbooks/petkovsek_wilf_zeilberger1996_*.pdf`.
Both are compact algorithms resting on polynomial GCD and linear algebra over ℚ, so both become
available as soon as §5.4 lands — they are the cheapest real Stage 3 capability and are a good first
target for that reason.

Difference-field summation (Karr's algorithm, and Schneider's Sigma extending it) is a separate track
of comparable size to Risch, covering nested sums and products that Gosper–Zeilberger cannot reach.
Sources: `references/papers/textbooks/karr1981_*.pdf` and
`references/papers/textbooks/schneider2007_*.pdf`, the latter being the readable entry point. Not
scheduled; the module boundary exists so it has somewhere to go.

### 6.4 The rest of Stage 3, briefly

`Solve` (linear systems by fraction-free Gaussian elimination, polynomial systems by Gröbner),
`Series` (truncated power series as a coefficient ring, which reuses §5.2 wholesale), and `Limit`
(series-based, with the documented incompleteness). Each is a module in the tree with a stated
dependency on the substrate, and none of them is on the critical path.

---

## 7. Testing

A CAS is a program where "it ran without crashing" says almost nothing. The tests are the
specification, and they come in five kinds that catch genuinely different failures.

### 7.1 Layout and harness

`tasty` throughout, with the suite tree mirroring `src/`:

```
test/
  Main.hs                     -- the fast suite: unit + property + golden
  Test/Cassini/Number.hs
  Test/Cassini/Core/Expr.hs
  Test/Cassini/Core/Order.hs
  Test/Cassini/Core/Intern.hs
  Test/Cassini/Pattern/Syntactic.hs
  Test/Cassini/Pattern/Sequence.hs
  Test/Cassini/Pattern/Commutative.hs
  Test/Cassini/Eval.hs
  Test/Cassini/Simplify/Automatic.hs
  Test/Cassini/Syntax.hs
  Test/Cassini/Poly/...
  Test/Gen.hs                 -- shared generators (§7.3)
  Test/Golden.hs              -- the regression driver (§7.4)
  regress/                    -- the regression corpus (§7.4)
oracle/
  Main.hs                     -- the differential suite (§7.5), separate
```

Four cabal stanzas, because they have different run times and different reasons to fail:

| Suite | Contents | Runs |
| :--- | :--- | :--- |
| `cassini-test` | unit, property, golden | every commit; must be seconds |
| `cassini-oracle` | differential against external systems | when the externals are present; nightly in CI |
| `cassini-doctest` | Haddock examples | every commit |
| `cassini-slow` | Gröbner, factorization, integration at size | nightly |

Splitting `cassini-slow` out is deliberate. A test suite that takes four minutes stops being run,
and the fast suite's job is to be run compulsively.

### 7.2 Unit tests

`tasty-hunit`. The rule for this project: **unit tests are worked examples lifted from the sources,
and each one cites where it came from.**

```haskell
-- Source: cohen2003 §3.1, Example 3.23 (an ASAE and three non-ASAEs)
asaeExamples :: TestTree
asaeExamples = testGroup "ASAE-5 (sums)"
  [ testCase "2x + 3y + 4z is an ASAE"        $ isASAE [expr| 2*x + 3*y + 4*z |] @?= True
  , testCase "1 + (x + y) + z violates ASAE-5-1" $ isASAE ... @?= False
  ...
  ]
```

This has a property the usual "test what you just wrote" approach lacks: the expected values were
computed by someone else, before the implementation existed, so a test agreeing with the
implementation's bug is much less likely. The specific harvests worth doing:

- **Cohen** §3.1's ASAE examples and non-examples; §3.2's worked simplifications; the O-1…O-13
  order examples (`a·x² ▹ x³`, `(1+x)³ ▹ (1+y)`, `m! ▹ n`).
- **Wolfram's** evaluation traces from the *Evaluation of Expressions* tutorial — each one a golden
  trace (§7.4) as well as a unit test.
- **Krebber** §3.3's commutative-matching examples, including the one with six candidate mappings
  and exactly one match, which is a precise test of whether the five phases prune correctly.
- **Bronstein** ch. 2's worked Hermite reductions and Rothstein–Trager examples.

Plus the ordinary kind: every function with an edge case gets a test for the edge case, and every
bug gets one (§7.4).

### 7.3 Property tests

`tasty-quickcheck`. (`hedgehog`'s integrated shrinking is genuinely better, but QuickCheck's
`Arbitrary` is what the surrounding ecosystem's generators — including `poly`'s — are written
against, and hand-written shrinkers for the two or three types that matter is the smaller cost.
Recorded in §11.2.)

**The generators are the hard part, and they decide whether any of this pays.**
`Test/Gen.hs` provides:

- `genExpr :: Int -> Gen Expr` — size-bounded, generating *valid* expressions over a small fixed
  symbol pool, with the size budget split among arguments so that depth and breadth are both
  exercised. A small pool is essential: with fresh symbols everywhere, no two subterms are ever
  equal and every test that depends on collecting like terms passes vacuously.
- `genASAE :: Int -> Gen Expr` — already-simplified expressions, for the idempotence law.
- `genPattern :: Expr -> Gen Expr` — a pattern *derived from* a subject by replacing subterms with
  blanks, so that the generated pattern matches by construction. Random patterns almost never match
  anything, which makes matcher property tests worthless without this.
- `shrinkExpr` — structural: replace a node by one of its children, shrink numbers toward zero, drop
  arguments. Without a good shrinker the counterexamples are unreadable and the tests get ignored.

**The law table.** Each row is a property test, and the "why it catches something" column is what
justifies its cost:

| Layer | Property | Catches |
| :--- | :--- | :--- |
| `Number` | exact `+`/`*`/`^` agree with `Rational` arithmetic; `compareNumber` agrees with `compare` on `toRational`, across both constructors | normalization and sign errors, and a constructor-order `Ord` sneaking back in (§3.1) |
| `Simplify` | `simplifyRNE` agrees with `Rational` arithmetic, and is `Nothing` exactly on division by zero | normalization and sign errors |
| `Core.Order` | `compareCanonical` is reflexive (`x x ≡ EQ`), antisymmetric (`x y ≡ invert (y x)`), transitive, and terminates — over generated expressions *and* over one hand-written value of every expression **kind**, pairwise: constant, string, symbol, product, power, sum, factorial, function, and a function with a curried head | O-13's swap rule getting a case wrong, and a kind pair no rule covers, which diverges rather than answering (§3.5) |
| `Core.Order` | `sortBy compareCanonical` is a permutation of its input | dropped or duplicated operands in `Orderless` |
| `Core.Intern` | interned `==` agrees with structural `==`; `hash` agrees with `==` | the interning-on/off divergence (§3.4) |
| `Core.Traversal` | `cata embed ≡ id` | traversal that fails to rebuild through smart constructors |
| `Structure` | `substitute u t t ≡ u`; `freeOf u t` implies `substitute u t r ≡ u` | subexpression comparison errors |
| `Attributes` | `AttributeSet` is a commutative idempotent monoid; `holdsArgument` agrees with a naive reference for every (attributes, index, arity) triple | the `HoldFirst`/`HoldRest` index arithmetic, which is off-by-one bait |
| `Rules` | `insertRule` leaves the set sorted by specificity, and insertion order breaks ties; `applicableRules` visits the rungs in `ladder` order | rule shadowing, which presents as "my definition is ignored", and the `Ord ValueKind` inversion of §4.2 |
| `Simplify` | `simplify u` satisfies `isASAE` or is `Undefined` | the postcondition, directly |
| `Simplify` | **for `u` an ASAE, `simplify u ≡ u`** | the source's own stated contract; stronger than plain idempotence |
| `Simplify` | `simplify` preserves numeric value at random rational points | a canonicalization that is canonical but wrong |
| `Pattern` | soundness: every `σ` from `matchAll p s` satisfies `applySubst σ p ≡ s` modulo attributes | the whole matcher, in one line |
| `Pattern` | completeness on generated pairs: `genPattern` output always matches its subject | phases 1–2 over-pruning |
| `Pattern` | for side-condition-free patterns, matching leaves `KernelState` unchanged but for messages | the backtracking rule in §4.5.2 |
| `Pattern` | `matchOne ≡ listToMaybe <$> matchAll` | the two observation functions diverging |
| `Eval` | `evaluate . evaluate ≡ evaluate` | a non-converging fixed point |
| `Eval` | evaluation under `runKernelPure` is deterministic given the same initial state | hidden `IO` dependence |
| `Syntax` | `parse . pretty ≡ id`; `parse . fullForm ≡ id` | the precedence table and printer disagreeing (§4.10) |
| `Algebra` | ring/field axioms on every coefficient type | the axioms types do not check |
| `Poly` | for `q ≠ 0`: `p * q / q ≡ p`, and `gcd p q` divides both with `p*q` and `gcd * lcm` associates | every rung of the GCD ladder, uniformly |
| `Poly` | GCD ladder agreement: all implemented rungs return associates of one another | rung 4/5 bugs, against rung 3 as the trusted reference |
| `Poly.Factor` | factors multiply back to the input; each factor is irreducible over the base | recombination errors |
| `Zero` | `isZero e == Just True` implies `e` evaluates to 0 at random points | the soundness bug §5.6 exists to prevent |
| `Calculus` | `D` against numerical differentiation at random rational points | sign and chain-rule errors |
| `Groebner` | every input polynomial reduces to 0 modulo the basis; all S-polynomials of basis pairs reduce to 0 (the S-test) | Buchberger's termination condition, stated as a property |
| `Summation` | `Gosper`'s antidifference `T` satisfies `T(n+1) - T(n) ≡ t(n)` | the same self-verifying trick as integration, one section earlier |
| `Integrate` | `D (integrate f) ≡ f` — the check that needs no oracle | everything, and it is why integration is easier to test than to write |

Two of those rows deserve emphasis, because they are the reason Stage 3 is testable at all.
**Integration is self-verifying:** Differentiating the answer and
comparing to the input turns a hard correctness question into an easy one, and it means the
integration tests can be generated rather than hand-written. Summation has the same shape — verify
the antidifference by differencing it — and Gröbner bases have the S-test, which is Buchberger's own
termination criterion reused as a check. In all three cases the expensive algorithm is verified by a
cheap one, which is what makes property testing viable for Stage 3 at all.

**Determinism.** CI passes a fixed `--quickcheck-replay` seed so a failure is reproducible, and
prints the seed on failure. A nightly job runs with a random seed and a much larger test count; a
failure there is filed as a regression case (§7.4) with the seed recorded.

### 7.4 Regression tests

The mechanism is `tasty-golden`, and the corpus is text.

```
test/regress/
  0001-orderless-flatten-collect.in
  0001-orderless-flatten-collect.expected
  0002-builtin-upvalue-beats-user-downvalue.in
  0002-builtin-upvalue-beats-user-downvalue.expected
  ...
```

Each `.in` is a script of FullForm expressions; each `.expected` is the FullForm output plus any
messages. `Test/Golden.hs` uses `findByExtension` to discover them, so adding a case is adding two
files. The REPL's `--script` mode (§4.10) is the driver, which means the regression suite exercises
the whole stack including the parser.

**FullForm, not pretty-printed output.** Pretty-printing changes as precedence handling improves, and
that must not invalidate three hundred golden files.

**The protocol, which is the part that matters:**

1. **Every fixed bug adds a numbered case, in the same commit as the fix.** Not "when convenient".
   A bug without a regression test is a bug that will return, and this design has a specific reason
   to believe that: the four-way rule ladder (§4.4), the `Flat`/`Listable`/`Orderless` ordering, and
   the commutative matcher's phase order are all things a plausible-looking refactor breaks silently.
2. **Goldens are read before they are accepted.** `--accept` regenerates expected output, which makes
   it trivially easy to enshrine a bug. The rule is that a diff is looked at by a person, and the
   commit message says what changed and why it is right.
3. **Cases are named for the behaviour, not the bug.** `0002-builtin-upvalue-beats-user-downvalue`
   still means something in two years; `0002-issue-17` does not.

**Golden evaluation traces.** A second golden set records the *step sequence* for chosen expressions
— which of the thirteen steps fired, in order, and what the expression looked like after each. This
is how the evaluation sequence is locked down: a refactor that accidentally reorders `Flat` and
`Orderless` produces a correct-looking answer for most inputs and a visibly wrong trace for all of
them.

**Seeded corpus.** The first cases are not waiting for bugs. Every worked example in §7.2 that
exercises more than one module goes in as a golden case from the start, which gives the suite
something to regress against before the first bug is found.

### 7.5 Differential testing against external systems

An optional suite, `cassini-oracle`, that runs Cassini and an external CAS on the same inputs and
compares. It **skips** when the external is absent rather than failing, so it never breaks a clean
checkout.

The pattern is Ishii's: shell out to a trusted implementation from inside a property, for the cases
where the property cannot be stated internally
(`references/papers/haskell/ishii2018_*.pdf` §3.2, which does exactly this with Singular for Gröbner
bases). Targets and what each is good for:

| External | Compares | Notes |
| :--- | :--- | :--- |
| Mathics3 | evaluator semantics, attributes, rule precedence | the closest thing to a reference implementation of the language |
| SymPy | simplification, factorization, integration results | differing normal forms mean comparison is by `isZero (a - b)`, not equality |
| Singular | Gröbner bases | Ishii's own choice, and the fastest correct reference |

**Comparison is semantic, not syntactic.** Two CASs almost never agree on the printed form of an
answer, so the oracle compares `isZero (ours - theirs)` where §5.6 can decide it, and reports
`Nothing` as an inconclusive result requiring human review rather than as a failure. Getting this
wrong produces a suite that cries wolf and is then turned off.

The Rubi problem corpus is the aspirational end state for `Integrate`. Its size and the timings
reported for it are vendor-reported figures, recorded in `notes/cas-haskell.md`; nothing here should
restate them as measurements of this system.

### 7.6 Doctests

`doctest` over the library's Haddock examples, wired as the `cassini-doctest` test-suite of §7.1 and
run by §2.8's step 2 rather than by a CI step of its own. Every exported function whose behaviour is
non-obvious carries a runnable example, and those examples are tests. This is cheap, idiomatic, and
it solves the specific problem that a CAS's documentation is full of expression examples that go
stale the moment the normal form changes.

### 7.7 Coverage

HPC via `cabal test --enable-coverage`, reported but **not gated on a percentage**. Coverage
percentage is a poor target for this codebase: the pattern matcher's branch count is dominated by
combinatorial cases that a handful of tests reach and a hundred more would not improve. The useful
signal is *uncovered top-level functions*, which is checked, and *uncovered branches in
`Cassini.Eval` and `Cassini.Simplify.Automatic`*, which are the two modules where an unexercised
branch is genuinely alarming.

---

## 8. Benchmarking

### 8.1 Harness

`tasty-bench`, for three reasons: it shares the `tasty` command line and test-tree vocabulary already
in use; it is lightweight, with no dependency beyond what is already present; and it has first-class
**baseline comparison**, which is what turns benchmarking from an activity into a gate.

```
bench/
  Main.hs            -- the aggregate suite
  Bench/Core.hs
  Bench/Matcher.hs
  Bench/Eval.hs
  Bench/Simplify.hs
  Bench/Poly.hs
  Bench/EndToEnd.hs
  baseline/          -- committed CSV baselines, one per GHC version
```

Compiled with `-O2` and `-with-rtsopts=-T` so that allocation and residency are reported alongside
wall time. For a term rewriter, **allocation is the story** — the interesting regressions show up as
bytes allocated long before they show up as seconds — so every benchmark reports both.

The relevant flags are `--baseline`, `--fail-if-slower`, `--fail-if-faster` and `--csv`; exact
spellings to be confirmed against the installed version when the suite is first written.

**`--fail-if-slower` compares times, and only times.** `tasty-bench` puts the allocation column in
the CSV but thresholds only the time measurement against the baseline, so a gate spelled with that
flag alone passes a change that triples allocation at unchanged wall time — which is exactly the
regression this section says arrives first. The allocation gate is therefore ours to write: §8.6's
CI step diffs the committed baseline CSV against the run's CSV on the allocation column and fails on
the same threshold. Small, and the alternative is a gate that watches the number that moves second.

### 8.2 Core (Stage 0)

The suite that decides the interning question (§3.4), and therefore the first one written:

- Construct a large expression tree bottom-up; measure time and allocation.
- Structural equality on two large equal expressions; on two large expressions differing at the last
  leaf (the case a hash cache should make fast and a naive traversal slow).
- `compareCanonical` on pairs of increasing depth.
- `sortBy compareCanonical` on argument vectors of 10, 100, 1000 elements.
- `substitute` over a deep tree.
- **The A/B:** every one of the above, with interning on and with it off, on the same inputs.

**The gate:** interning ships if it wins on the expression-swell workload (§8.4) on both time and
allocation. If it does not, it stays behind the flag and §11.2 records the number.

### 8.3 Matcher

The suite designed to answer a specific question rather than to produce a number.

- Syntactic matching, pattern and subject of increasing size.
- Sequence-variable matching: *k* sequence variables against *n* arguments, over a grid, because this
  is where the combinatorial explosion lives. This grid records **allocation per match** and not only
  wall-clock time: `MatchT`'s continuation-passing interior degrades by allocating, and a time number
  alone cannot separate the monad from the search space it is exploring. This is the measurement D11
  turns on.
- Commutative matching at arity 3, 5, 8, 12 — with and without phases 1–2 enabled, which measures
  the pruning directly and is the honest way to know the phases are earning their complexity.
- A deliberately adversarial case: a linear AC pattern (polynomial) against a non-linear one
  (NP-complete) at the same size, to make the difference visible in the numbers.

**The net question.** `Cassini.Pattern.Net` is not built on a hunch. The benchmark sweeps the
**number of subjects matched against a fixed pattern set** — 1, 10, 100, 1000, 10000 — for both the
one-to-one matcher and a prototype net, because that is where the break-even lies: the net's
construction cost is one-time and must be amortized, so the win arrives with subject volume, not
with pattern-table size. The sweep is run once, the crossover is recorded, and the net is built if
and only if the crossover is below the volume the evaluator actually generates.

### 8.4 Evaluator and simplifier

- **Fixed-point convergence**: expressions requiring 1, 5, 20 rounds.
- **Expression swell**: `Expand` of `(a+b+c+d)^n` for growing `n` — the canonical stress case, and
  the one where structure sharing either pays or does not.
- **Deep `D`**: repeated differentiation of a nested product, which grows fast and exercises the rule
  engine rather than the arithmetic.
- **`//.` against a large rule set**: 10, 100, 1000 rules, which is the workload the discrimination
  net would serve.
- **Automatic simplification**: sums and products of 10, 100, 1000 terms, with and without like terms
  to collect — separating the sort cost from the merge cost.

### 8.5 Polynomial

Gröbner bases live in `cassini-slow` (§7.1), benchmarked on a small fixed set of ideals with a
timeout: double-exponential worst-case behaviour means a benchmark without one eventually becomes a
hang, and the number to watch is the ratio between Buchberger and F4 on the same inputs, not the
absolute time.

GCD and multiplication across the ladder (§5.4), measured against `poly` as an external reference so
that "our GCD is slow" can be distinguished from "polynomial GCD is slow". Sized to cross the point
where the modular algorithm overtakes subresultant PRS, because that crossover is the input the
dispatcher needs.

### 8.6 End-to-end, and the regression gate

One fixed workload — parse, evaluate and print a fixed script exercising simplification,
differentiation, pattern replacement and polynomial arithmetic — measured as a single number.

**This is the number the CI gate watches.** Microbenchmarks are advisory: they are noisy, they are
sensitive to GHC version and machine, and gating on them produces flaky builds that get disabled. The
end-to-end number is stable enough to gate, and a regression in it is always worth investigating.

The gate: `--baseline baseline/ghc-9.12.csv --fail-if-slower 10 --csv out.csv`, followed by the
allocation diff of §8.1 over the same two CSVs — `--fail-if-slower` does not look at allocation.
Ten percent is chosen for both, to sit above machine noise and below anything worth shipping.
Baselines are committed, regenerated deliberately with the commit message saying why, and kept per
GHC version because cross-version comparison is meaningless.

### 8.7 What is not measured, and why

No comparison against Mathematica, SymPy or Symbolica as a headline number. Cross-system performance
comparison requires equivalent workloads and equivalent tuning, and a number produced without both is
marketing. The oracle suite (§7.5) uses those systems for *correctness*, which is a question they can
answer.

---

## 9. Risks

### 9.1 The five documented ways this fails

`notes/cas-haskell.md` names five failure modes for exactly this project. Each is mapped to the
decision that addresses it, so that the mapping can be checked rather than assumed:

| Failure mode | Addressed by |
| :--- | :--- |
| (a) Making the core type-safe and drowning in type-level machinery | §1.1 — untyped kernel, typed algebra, one explicit bridge; the lint rule in §2.6 keeps them apart |
| (b) Underestimating automatic simplification | §4.6 — Cohen's full procedure tree, `isASAE` as an executable postcondition, the idempotence law in §7.3 |
| (c) Building integration/factorization before the substrate | §5 before §6, and §6.2's rational tier explicitly depending on §5.4 and §5.5 |
| (d) Ignoring matcher performance until the rule set is large | §4.5.5 — the `RuleIndex` interface exists from day one, the net is built on a measured crossover (§8.3) |
| (e) No memoization or structure sharing | §3.3–3.4 — hashes cached from day one, interning behind smart constructors with a measured gate |

### 9.2 Risks this design introduces

- **The `unsafePerformIO` intern table.** Correct as written, and genuinely unsafe if anyone reads
  the table outside the smart constructors. Mitigation: `Cassini.Core.Intern` exports one function;
  the module carries `-fno-full-laziness`; the on/off agreement property (§7.3) would catch a
  divergence. Residual risk: a GHC change to weak-reference or CSE behaviour. Accepted, and the
  reason the flag exists.
- **`logict` inside `MatchT` under deep backtracking.** `LogicT`'s continuation-passing structure
  over a non-trivial base monad can allocate heavily, and the `forall r. m r` quantification blocks
  the specialization that would make `Eff`'s bind cheap. Mitigation: the matcher benchmark (§8.3),
  whose sequence-variable grid records allocation per match for this reason. The fallback has two
  rungs, cheapest first, and is D11 in §11.2:

  1. Swap the newtype's interior to `logict-sequence`, whose `Seq`-based representation has different
     asymptotics under left-nested `>>=`. One module, no new correctness burden.
  2. Hand-roll the continuation type, specialized to `Eff es` and `INLINE`d:

     ```haskell
     newtype MatchT es a = MatchT
       { runMatchT :: forall r. (a -> Eff es r -> Eff es r) -> Eff es r -> Eff es r }
     ```

     It must reproduce `liftMatch`, `observeFirst`, `observeAll` and the five instances of §4.5.2,
     and nothing else — in particular not `msplit` or fair disjunction, which the §4.5.4 phases as
     specified never call for. That is a bounded amount of backtracking-monad correctness to own,
     which is why it is the second rung and not the first.

  Both rungs are genuinely one-module changes rather than audits, because §4.5.2 makes `MatchT` a
  newtype and §2.6's `Control.Monad.Logic` rule confines `Control.Monad.Logic` to the module that
  defines it. Under the type synonym this design previously specified, neither would have been.
- **Pattern-synonym indirection.** `COMPLETE`-annotated view patterns cost nothing at `-O2` and are
  visible at `-O0`, which makes the test suite slower than it would otherwise be. Accepted; the
  reversibility of §3.4 is worth more than fast unoptimized builds.
- **The dependency posture.** `relude` + `effectful` + a `mixins` stanza is a combination fewer
  Haskell contributors have seen than `base` + `mtl`, and it makes the first build longer. Accepted
  deliberately: the testability argument in §4.3 (a kernel that runs without `IOE`) is the payoff,
  and it is a payoff in the specific dimension this project needs most.
- **Cohen's order and WL's order are not the same order.** `compareCanonical` implements Cohen's
  O-1…O-13, which is a well-specified canonical order but is not bit-for-bit what Mathematica's
  `Sort` produces. Where the oracle suite (§7.5) compares against Mathics3, ordering differences will
  appear as false positives. Mitigation: the oracle compares semantically (§7.5); ordering fidelity
  is a documented non-goal, recorded in §11.2 so that it is a choice.

### 9.3 The undecidability ceiling, stated as a design constraint

There is no general algorithm for deciding whether a symbolic expression is zero
(`references/papers/foundations/richardson1968_*.pdf`). Every real CAS's simplifier is therefore a
bundle of heuristics with a best-effort contract, not a decision procedure.

This is not a risk to mitigate. It is a constraint that shapes three decisions already made:
`Cassini.Zero` returns `Maybe Bool` and callers must handle `Nothing` (§5.6); canonical forms are
promised only for the sub-domains where they exist — rational numbers, polynomials, rational
functions (§4.6, §5.2); and `Simplify` is documented as best-effort rather than complete. The failure
this prevents is the one where an incomplete simplifier quietly becomes a *wrong* one by treating "I
could not prove it non-zero" as "it is zero".

---

## 10. Milestones

Each stage has an acceptance criterion that is a *behaviour*, the tests that encode it, and a number
recorded on completion.

### Stage 0

**Done when** large expressions can be constructed, compared and traversed at measured cost, and
`compareCanonical` passes its order laws.

- Tests: the `Number`, `Core.Expr`, `Core.Order`, `Core.Intern`, `Core.Traversal` and `Structure`
  rows of §7.3, plus Cohen's O-1…O-13 examples as unit tests.
- Benchmark: §8.2 run in full, with the interning A/B recorded in §11.2 whichever way it goes.

### Stage 1

**Done when** `Plus[a, Plus[b, a]]` flattens, sorts and collects to `2a + b`, and `D` gets the
product and chain rules right.

That criterion is chosen because it is not one feature but four: `Flat` flattening (step 7),
`Orderless` sorting (step 9), Cohen's `Simplify_sum_rec` merge, and the evaluator's fixed-point loop,
all of which must be right simultaneously for `2a + b` to come out. Getting `Plus[a, b, a]` to
*flatten and sort* is the easy half; **collecting like terms is the half that is automatic
simplification proper**, and it is the one worth gating on.

- Tests: the `Simplify`, `Pattern`, `Eval` and `Syntax` rows of §7.3; the Wolfram evaluation traces
  as golden traces; Krebber's commutative examples.
- Benchmark: §8.3 and §8.4 baselined; the discrimination-net crossover measured and recorded.

### Stage 2

**Done when** multivariate GCD and content/primitive-part are correct on non-trivial inputs, and
`isZero` never returns `Just` wrongly.

- Tests: the `Poly` and `Zero` rows of §7.3, including GCD-ladder agreement, which is the property
  that makes rungs 4 and 5 safe to add.
- Benchmark: §8.5, with the subresultant/modular crossover recorded so the dispatcher has an input.

### Stage 3

**Deliberately partial, and that is the plan.** Three independent acceptance criteria, any of which
is worth reaching alone:

- `Cassini.Integrate.Rules` handles the standard first-year-calculus table.
- `integrateRational` is complete for rational functions, verified by the `D ∘ ∫ ≡ id` property.
- Simplification with side relations works via Gröbner reduction.

Full transcendental Risch is a further milestone; the algebraic case is not a milestone at all
(§6.2).

---

## 11. Appendix

### 11.1 Dependency budget

The preference throughout is boring and maintained over clever and abandoned. Every dependency below
is named because a decision in this document requires it.

| Package | For | Layer |
| :--- | :--- | :--- |
| `relude` | the prelude (§2.3) | all |
| `effectful` | the kernel effect and its two interpreters (§4.3) | L3+ |
| `text`, `vector`, `containers`, `unordered-containers`, `hashable` | representation | L0–L2 |
| `enummapset` | the `EnumMap ValueKind RuleSet` of the four rule tables (§4.2) | L3 |
| `logict` | matcher nondeterminism, behind `MatchT` and reachable from one module (§4.5.2) | L2 |
| `recursion-schemes` | traversal that rebuilds through smart constructors (§3.6) | L1 |
| `megaparsec` | surface syntax (§4.10) | L5 |
| `poly`, `semirings` | polynomial substrate and coefficient classes (§5.3) | A |
| `tasty`, `tasty-hunit`, `tasty-quickcheck`, `tasty-golden`, `tasty-bench`, `doctest` | §7, §8 | test |

Deliberately *not* dependencies: `lens` (the `Structure` operators are a dozen functions, not an
optics library); `uniplate` (§3.6); `sbv` (§5.6, recorded as a possible zero-test layer, not adopted);
`symengine` (FFI to a fast external core would resolve the two-layer question by outsourcing it, and
this project is the exercise of not doing that).

### 11.2 Deferred decisions

Recorded so that each is a decision with an owner and a trigger, not something rediscovered later.

| # | Decision | Trigger to revisit |
| :--- | :--- | :--- |
| D1 | `Integer` over a custom bignum (§3.1) | Stage 2 polynomial benchmarks showing `Integer` overhead dominating |
| D2 | Interning on or off (§3.4) | resolved by the §8.2 A/B; the number is recorded here when it exists |
| D3 | `recursion-schemes` over `uniplate` (§3.6) | traversal showing up in the §8.4 profile |
| D4 | QuickCheck over Hedgehog (§7.3) | shrinking quality becoming the reason counterexamples go uninvestigated |
| D5 | `poly` over Kmett's `algebra` (§5.3) | Gröbner work at Stage 3 needing the `Numeric.Domain.*` chain |
| D6 | `Effectful.State.Static.Local` over `.Shared` (§4.3) | any move toward parallel evaluation |
| D7 | Single package over multi-package (§2.1) | the algebra tower's dependency footprint diverging |
| D8 | Cohen's canonical order over WL fidelity (§9.2) | oracle-suite false positives becoming the dominant failure |
| D9 | Inexact numbers absent from `Number` (§3.1) | when they are needed; the O-7 slot is reserved |
| D10 | SMT-backed zero testing not adopted (§5.6) | side conditions needing more than layer 4 can decide |
| D11 | `logict` inside `MatchT` over a hand-rolled continuation type (§4.5.2, §9.2) | §8.3's allocation-per-match number dominating on the sequence-variable grid |
| D12 | Single-GHC CI matrix, pinned to `base ^>=4.21.2.0` (§2.8) | GHC 9.14 reaching a release Stackage or a Hackage upload needing a wider bound; widening the bound and the matrix is one change, not two |

### 11.3 Provenance of the design decisions

The research this rests on is `notes/cas-haskell.md`, with its bibliography in
`notes/cas-haskell-bibliography.md` and the documents themselves in `references/`. Per §0.3, this
document cites those by path and does not restate facts about them.

The corpus is gitignored — a fresh clone gets the indexes and none of the documents. To re-fetch,
`references/downloaded-references-summary.md`'s Source column has the provenance of every file, and
`references/CLAUDE.md` has the corpus rules, including which held copies have OCR defects that make
grep lie in both directions.
