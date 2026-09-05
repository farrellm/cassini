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
| `Cassini.Core.Intern` | The hash-consing table and the `internExpr` entry point. Switchable (§3.4). |
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
`ask`, `asks`, `local`, `State`, `StateT`, `Reader`, `ReaderT`, `MonadState`, `MonadReader` — and
those names collide, one for one, with `Effectful.State.Static.Local` and `Effectful.Reader.Static`.
Fixing that with qualified imports in fifty modules is fifty chances to get it wrong.

So it is fixed once, in an internal sublibrary:

```cabal
library cassini-prelude
  import:           warnings
  exposed-modules:  Cassini.Prelude
  hs-source-dirs:   prelude
  build-depends:    base, relude
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

`Cassini.Prelude` re-exports `Relude` minus the colliding names, and adds nothing else of substance —
it is a subtraction, not a second standard library. The same two `mixins` lines go in every stanza:
library, executable, each test-suite, each benchmark.

```haskell
module Cassini.Prelude (module Relude) where

import Relude hiding
  ( -- collides with effectful's State and Reader effects
    State, StateT, MonadState, get, put, modify, modify', gets, state
  , evalState, execState, runState, evalStateT, execStateT, runStateT
  , Reader, ReaderT, MonadReader, ask, asks, local, runReader, runReaderT
    -- collides with this project's vocabulary
  , one        -- Relude.Container.One's singleton; we want the ring constant
  , Undefined  -- Relude.Debug's marker type; we want Cohen's Undefined (§4.6)
  )
```

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
      within: [Cassini.Eval, Cassini.Eval.*, Cassini.Rules, Cassini.Simplify.*,
               Cassini.Builtins, Cassini.Builtins.*, Cassini.Syntax.*, Cassini.REPL, Main]
    # The Kernel effect and the rule tables are the vocabulary the matcher needs for
    # side conditions (§4.5.2), so L2 may name them - but not the sequence above them.
    - name: [Cassini.Eval.Kernel, Cassini.Rules]
      within: [Cassini.Pattern, Cassini.Pattern.*, Cassini.Eval, Cassini.Eval.*,
               Cassini.Rules, Cassini.Simplify.*, Cassini.Builtins, Cassini.Builtins.*,
               Cassini.Syntax.*, Cassini.REPL, Cassini.Zero, Main]
    # The algebra tower does not know about Expr; Poly.Convert and Zero are the bridges.
    - name: [Cassini.Core.Expr]
      within: [Cassini.Core.*, Cassini.Structure, Cassini.Attributes,
               Cassini.Pattern, Cassini.Pattern.*,
               Cassini.Rules, Cassini.Eval, Cassini.Eval.*, Cassini.Simplify.*,
               Cassini.Builtins, Cassini.Builtins.*, Cassini.Syntax.*, Cassini.REPL,
               Cassini.Zero, Cassini.Poly.Convert, Main]
    # The representation is private to the core.
    - name: Cassini.Core.Expr.Internal
      within: [Cassini.Core.*]
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

`.github/workflows/ci.yml`, `haskell-actions/setup`, matrix over the current and previous two GHC
majors, with the newest as the required job:

1. `cabal build --enable-tests --enable-benchmarks all`
2. `cabal test all` (unit, property, golden; oracle suite skipped when absent)
3. `cabal run doctests`
4. `hlint .`
5. `fourmolu --mode check $(git ls-files '*.hs')`
6. `cabal haddock --haddock-quickjump` with a coverage floor
7. benchmark regression gate against the committed baseline (§8.5)

Steps 4–7 run on the newest GHC only.

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
  deriving stock (Eq, Ord, Show)
```

Two decisions.

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
instance Ord Symbol where compare = compare `on` symId
```

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
internTable :: IORef (HashMap Int [Weak Expr])   -- keyed by hash, bucketed
{-# NOINLINE internTable #-}
internTable = unsafePerformIO (newIORef mempty)

intern :: Shape -> Expr
```

**Weak references reclaim the node, not the entry.** A `Weak Expr` whose key dies leaves a dead
`Weak` in its bucket, so a table that only ever appends buckets grows without bound even though every
`Expr` it once held has been collected — the leak is the size of the bucket lists, not of the terms.
Each weak pointer is therefore created with a finalizer (`mkWeakPtr v (Just reap)`) that deletes its
own entry from the bucket, and lookups additionally drop the entries whose `deRefWeak` returns
`Nothing` as they scan. Neither alone is enough: the finalizer can lag, and lookup only visits
buckets that are asked for.

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
| O-2 | both symbols | lexicographic |
| O-3 | both products (or both sums) | compare last operands, then next-to-last, …; if one is a suffix of the other, shorter first |
| O-4 | both powers | bases first; if equal, exponents |
| O-5 | both factorials | operands |
| O-6 | both functions | names first; if equal, arguments left-to-right, first argument most significant |
| O-7 | number vs anything else | the number first |
| O-8 | product vs power/sum/factorial/function/symbol | compare as products (recur into O-3) |
| O-9 | power vs sum/factorial/function/symbol | compare as powers, `v` read as `v^1` (recur into O-4) |
| O-10 | sum vs factorial/function/symbol | compare as sums (recur into O-3) |
| O-11 | factorial vs function/symbol | `false` if the operand equals `v`, else compare as factorials |
| O-12 | function vs symbol | `false` if the function's name is the symbol, else compare names |
| O-13 | otherwise | `not (v ▹ u)` — the swap rule |

**Strings need a rule, and Cohen does not supply one.** `Shape` has an `SString` constructor
(§3.3) and the Stage 1 parser accepts string literals (§4.10), but Cohen's algebra has no strings and
O-1…O-13 therefore never mention them. That is not a harmless omission: with O-13 as the fallback,
two expressions that no rule covers send `compareCanonical u v` to `compareCanonical v u` and back
forever, so `compareCanonical (Str "a") (Str "b")` — and string-versus-symbol — is a hang, not a
wrong answer. **Every pair of shapes must be covered by a rule that is not O-13.** The design adds
two, placed so the existing rules are undisturbed:

| Rule | Case | Order |
| :--- | :--- | :--- |
| O-S1 | both strings | lexicographic on the `Text` |
| O-S2 | string vs any non-number | the string first |

O-7 still puts every number ahead of every string, so numbers < strings < everything else, and the
slot §3.1 reserves for inexact numbers is still inside O-7. The totality property in §7.3 is what
catches a future constructor that repeats this mistake: it exercises every pair of shapes, and an
uncovered pair diverges rather than returning the wrong `Ordering`.

Two more things fall out that are worth stating, because they look like bugs otherwise. O-3 compares
products **from the right**, so `a·x²` sorts before `x³` and a polynomial comes out in increasing
degree. And O-13 means the table above is upper-triangular: the missing cases are the transposes,
handled by recursion with the arguments swapped. The implementation mirrors that structure — twelve
cases and one `flip`-with-negate — rather than writing out twenty-five.

`Ord Expr` is defined as `compare = compareCanonical`, or it is not defined at all. There is no third
option in which both exist, because that is exactly how the wrong one gets used by accident.

### 3.6 Traversal

`Cassini.Core.Traversal` provides a base functor and `recursion-schemes` instances:

```haskell
data ExprF r = NumberF !Number | StringF !Text | SymbolF !Symbol | AppF !r !(Vector r)
  deriving stock (Functor, Foldable, Traversable)
type instance Base Expr = ExprF
instance Recursive   Expr
instance Corecursive Expr
```

**`recursion-schemes` over `uniplate`**, for one reason that outweighs the extra concept: `embed`
goes through the smart constructors, so every `cata`/`ana`/`para` automatically maintains the hash
and the intern id. With `uniplate`'s `transform`, rebuilding is the caller's business and a single
place that forgets is a silently un-interned subtree with a stale hash — a bug that survives testing
because everything still *works*, just slower and with `Eq` quietly wrong.

For the handful of places where a plain "rewrite everywhere until fixed" is what is meant,
`Cassini.Core.Traversal` exports `rewriteM` implemented on top of `apo`, so callers never touch the
generic machinery directly.

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
  , ruleRhs      :: !Expr
  , ruleDelayed  :: !Bool          -- ^ ':>' rather than '->'
  , ruleSpecificity :: !Specificity
  , ruleOrigin   :: !Origin        -- ^ which rung of the §4.4 ladder this rule is on
  }

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

**`ruleOrigin` is not bookkeeping.** §4.4's ladder is four rungs, not two axes, and the rungs are
`(UpValue, User)`, `(UpValue, Builtin)`, `(DownValue, User)`, `(DownValue, Builtin)` in that order.
A `RuleSet` sorted by specificity alone would let a more specific *user* downvalue be tried before a
less specific *built-in upvalue*, which is exactly the inversion step 11-vs-12 exists to forbid. So
`Cassini.Rules.applicableRules` takes an `(ValueKind, Origin)` pair and scans only the rules carrying
that origin: steps 10-13 walk four disjoint subsets, and specificity orders *within* a rung and never
across one.

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
  Iterations    :: Kernel m Int            -- ^ remaining fixed-point fuel
  SpendIteration:: Kernel m ()
type instance DispatchOf Kernel = Dynamic

lookupSymbol :: (Kernel :> es) => Symbol -> Eff es SymbolInfo
lookupSymbol = send . LookupSymbol
```

Kernel functions are written constraint-polymorphically over what they actually need:

```haskell
evaluate :: (Kernel :> es) => Expr -> Eff es Expr
matchOne :: (Kernel :> es) => Expr -> Expr -> Eff es (Maybe Subst)
```

**Why this and not `ReaderT Env IO` with `IORef`s.** Two interpreters over one effect:

```haskell
runKernelIO   :: (IOE :> es)
              => IORef KernelState -> Eff (Kernel : es) a -> Eff es a

runKernelPure :: KernelState
              -> Eff (Kernel : es) a
              -> Eff es (Either Abort a, KernelState)
```

`runKernelPure` is `reinterpret (runState s0 . runErrorNoCallStack) handler`: it introduces
`State KernelState` and `Error Abort` for its own use and discharges both, so the caller's `es` never
mentions them. The initial state has to be an argument and the final state has to be in the result —
a signature that dropped either would not be implementable, since there is nowhere for the state to
come from or go.

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

The implementation is one function whose body is thirteen named calls, each separately testable:

```haskell
-- | Cassini.Eval
evaluate :: (Kernel :> es) => Expr -> Eff es Expr
evaluate = fixpoint step
  where
    step e = evalStep1Raw e
         >>= evalStep2Head  >>= evalStep34ArgsHold
         >>= evalStep5Seq   >>= evalStep6Uneval  >>= evalStep7Flat
         >>= evalStep8List  >>= evalStep9Order   >>= evalStep10UserUp
         >>= evalStep11BuiltinUp >>= evalStep12UserDown >>= evalStep13BuiltinDown

    -- Step 4 is a *gate* on step 3, not a stage after it.
    evalStep34ArgsHold e = evalStep4Hold e >>= \held -> evalStep3Args held e
```

**Steps 3 and 4 are one pass, and this is the one place the repository's numbering misleads.**
The numbering comes from splitting the source page's third bullet in two
(`references/papers/wolfram-language/CLAUDE.md`), and the split is a *description* of two things to
implement, not a sequence of two passes. Running `evalStep3Args` and then `evalStep4Hold` would
evaluate every element and only afterwards decide which ones were held, which is not skipping
evaluation — it is doing it and then forgetting. `Hold[1+1]` would return `Hold[2]`, and
`SetDelayed` would evaluate its right-hand side. So `evalStep4Hold` computes the held-position mask
from the head's attributes and `evalStep3Args` consumes it; both stay separately named and
separately testable, and the golden traces (§7.4) still record them as two entries.

Not because a twelve-link `>>=` chain is beautiful, but because each step is then a function with
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
cases. They are attributes plus ordinary definitions, and the evaluator must contain no branch
naming any of them. Any patch that adds one is a bug.

**The fixed point is fuelled.** `fixpoint` decrements `Iterations` on each round and, on exhaustion,
emits `$IterationLimit::itlim` and returns the expression wrapped in `Hold` — the language's own
behaviour, and the alternative to a hang. Non-termination is a *user* error in a rewriting system,
so it gets a message, not an exception.

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
test` requires calling `evaluate` on `test` under the current substitution, and `?f` requires
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
`KernelState` unchanged except for messages) is what keeps it true. It is also what makes the choice
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
   chain the resulting `matchOne` calls, because two patterns may share a variable and the matches
   are therefore not independent. After this phase, **repeat phase 2**, since new bindings have
   appeared.
4. **Regular variables.**
5. **Sequence variables.** The most expensive, facing the smallest remaining problem.

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
simplifyRational  :: Number -> Either Undefined Number
simplifyPower     :: Expr -> Vector Expr -> Either Undefined Expr
simplifyIntPower  :: Expr -> Integer -> Either Undefined Expr   -- SINTPOW
simplifyProduct   :: Vector Expr -> Either Undefined Expr       -- SPRD
simplifyProductRec:: [Expr] -> [Expr]                           -- SPRDREC
simplifySum       :: Vector Expr -> Either Undefined Expr
simplifySumRec    :: [Expr] -> [Expr]
simplifyQuotient  :: Expr -> Expr -> Either Undefined Expr
simplifyDifference:: Vector Expr -> Either Undefined Expr
simplifyFactorial :: Expr -> Either Undefined Expr
simplifyFunction  :: Expr -> Vector Expr -> Either Undefined Expr
```

The `*Rec` operators are the merge steps — the recursive workers that combine two already-simplified
operand lists — and they are where like terms are collected. They are separate functions because
they are separately testable and because they are where the bugs live.

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
toPolynomial   :: (MonomialOrder ord) => [Symbol] -> Expr -> Maybe (Multi ord Rational)
fromPolynomial :: (MonomialOrder ord) => [Symbol] -> Multi ord Rational -> Expr

isPolynomialGPE :: [Symbol] -> Expr -> Bool
degreeGPE       :: [Symbol] -> Expr -> Maybe Integer
coefficientGPE  :: Symbol -> Integer -> Expr -> Maybe Expr
variables       :: Expr -> [Symbol]
```

Recognition can fail; construction cannot. The `Maybe` is the design's honesty about *generalized
variables*: `Sin[x]` is a legitimate polynomial variable in `Sin[x]^2 + 1`, and whether a
subexpression is a variable or a coefficient depends on the variable list you supply. Cohen treats
this at length and the design does not try to guess — `variables` reports what it found, and callers
say what they want.

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
evaluation at random points, and neither is reachable from a fully polymorphic `es`. It is also why
`Cassini.Zero` sits with `Cassini.Poly.Convert` on the `Expr` side of the algebra tower rather than
inside it, and why both appear in §2.6's `Cassini.Core.Expr` rule.

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
integrateRational :: Symbol -> Uni Rational -> Uni Rational -> Either NotElementary Result
```

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
| `Number` | exact `+`/`*`/`^` agree with `Rational` arithmetic | normalization and sign errors |
| `Simplify` | `simplifyRNE` agrees with `Rational` arithmetic, and is `Nothing` exactly on division by zero | normalization and sign errors |
| `Core.Order` | `compareCanonical` is irreflexive, transitive, and total (trichotomy) — over generated expressions *and* over one hand-written value of every `Shape` constructor, pairwise | O-13's swap rule getting a case wrong, and a shape no rule covers, which diverges rather than answering (§3.5) |
| `Core.Order` | `sortBy compareCanonical` is a permutation of its input | dropped or duplicated operands in `Orderless` |
| `Core.Intern` | interned `==` agrees with structural `==`; `hash` agrees with `==` | the interning-on/off divergence (§3.4) |
| `Core.Traversal` | `cata embed ≡ id` | traversal that fails to rebuild through smart constructors |
| `Structure` | `substitute u t t ≡ u`; `freeOf u t` implies `substitute u t r ≡ u` | subexpression comparison errors |
| `Attributes` | `AttributeSet` is a commutative idempotent monoid; `holdsArgument` agrees with a naive reference for every (attributes, index, arity) triple | the `HoldFirst`/`HoldRest` index arithmetic, which is off-by-one bait |
| `Rules` | `insertRule` leaves the set sorted by specificity, and insertion order breaks ties | rule shadowing, which presents as "my definition is ignored" |
| `Simplify` | `simplify u` satisfies `isASAE` or is `Undefined` | the postcondition, directly |
| `Simplify` | **for `u` an ASAE, `simplify u ≡ u`** | the source's own stated contract; stronger than plain idempotence |
| `Simplify` | `simplify` preserves numeric value at random rational points | a canonicalization that is canonical but wrong |
| `Pattern` | soundness: every `σ` from `matchAll p s` satisfies `applySubst σ p ≡ s` modulo attributes | the whole matcher, in one line |
| `Pattern` | completeness on generated pairs: `genPattern` output always matches its subject | phases 1–2 over-pruning |
| `Pattern` | matching leaves `KernelState` unchanged but for messages | the backtracking rule in §4.5.2 |
| `Pattern` | `matchOne ≡ listToMaybe <$> matchAll` | the two observation functions diverging |
| `Eval` | `evaluate . evaluate ≡ evaluate` | a non-converging fixed point |
| `Eval` | evaluation under `runKernelPure` is deterministic given the same initial state | hidden `IO` dependence |
| `Syntax` | `parse . pretty ≡ id`; `parse . fullForm ≡ id` | the precedence table and printer disagreeing (§4.10) |
| `Algebra` | ring/field axioms on every coefficient type | the axioms types do not check |
| `Poly` | `p * q / q ≡ p`; `gcd p q` divides both and `p*q ≡ gcd * lcm` | every rung of the GCD ladder, uniformly |
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

`doctest` over the library's Haddock examples. Every exported function whose behaviour is
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
bytes allocated long before they show up as seconds — so every benchmark reports both and the
baseline gate watches both.

The relevant flags are `--baseline`, `--fail-if-slower`, `--fail-if-faster` and `--csv`; exact
spellings to be confirmed against the installed version when the suite is first written.

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

The gate: `--baseline baseline/ghc-9.12.csv --fail-if-slower 10`. Ten percent is chosen to sit above
machine noise and below anything worth shipping. Baselines are committed, regenerated deliberately
with the commit message saying why, and kept per GHC version because cross-version comparison is
meaningless.

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

### 11.3 Provenance of the design decisions

The research this rests on is `notes/cas-haskell.md`, with its bibliography in
`notes/cas-haskell-bibliography.md` and the documents themselves in `references/`. Per §0.3, this
document cites those by path and does not restate facts about them.

The corpus is gitignored — a fresh clone gets the indexes and none of the documents. To re-fetch,
`references/downloaded-references-summary.md`'s Source column has the provenance of every file, and
`references/CLAUDE.md` has the corpus rules, including which held copies have OCR defects that make
grep lie in both directions.
