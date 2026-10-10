# Cassini — Design

A computer algebra system for Haskell: a Wolfram-Language-style term rewriting kernel with an exact
numeric and polynomial substrate underneath it.

This document is the architecture: what to build, in what order, with which boundaries, and how each
piece is tested and measured. It is ahead of the code — `src/` is still `cabal init` output — so
where the two disagree, this document is the intent and the code is behind.

## 0. Scope and conventions

### 0.1 What this covers

All four build stages, at design depth:

| Stage | Substance | §  |
| :---- | :--- | :--- |
| 0 | Exact numbers, the `Expr` representation, interning, canonical order, traversal | [§3](#3-stage-0--foundations) |
| 1 | In three milestones (§10): 1a attributes, rule tables, the evaluation sequence, automatic simplification; 1b the pattern matcher; 1c pure functions, `D`, surface syntax. Not gating: elementary functions, control flow, logic, radicals and integer functions | [§4](#4-stage-1--the-kernel) |
| 2 | Polynomials, GCD, zero testing and their builtins (2a); modular GCD and factorization (2b) | [§5](#5-stage-2--the-polynomial-substrate) |
| 3 | Gröbner bases, integration, summation | [§6](#6-stage-3--the-hard-algorithms) |

Plus the cross-cutting plans: [testing](#7-testing), [benchmarking](#8-benchmarking),
[risks](#9-risks), [milestones](#10-milestones).

### 0.2 What this does not cover

Inexact numerics (arbitrary-precision floating point, interval arithmetic): the representation
reserves a slot (§3.1) and D9 records the trigger, but the algorithms are out of scope. Likewise
notebooks, graphics, a package/context system beyond what the evaluator needs, and parallelism. Each
is noted where the design must not foreclose it.

### 0.3 Citations

Design claims are justified by sources in `references/`, cited **by path**:

> Automatic simplification follows `references/papers/textbooks/cohen2003_*.pdf` §3.2.

This document does **not** restate facts *about* a source — edition, page count, who proved what
first. Those live in `notes/cas-haskell.md` and `notes/cas-haskell-bibliography.md`, where
`notes/CLAUDE.md` rule 4 tracks each across six files; a seventh copy would be a seventh thing to get
silently wrong. The exception is where a source's *content* is the design — the thirteen evaluation
steps, the ASAE conditions, the order relation, the five commutative-matching phases. Those are
transcribed, and marked as such, because a design that only pointed at them would not be
implementable.

### 0.4 Reading order

`notes/cas-haskell.md` first; it is the research this rests on and is not repeated here. Then §1–§2
for shape, then the stage being built.

---

## 1. Architecture

### 1.1 The central decision: two layers, differently typed

The system is **two libraries that meet at one bridge**, and they make opposite typing choices on
purpose.

**The rewriting kernel is untyped.** One `Expr` sum type; everything is `head[args]`. Every
production Wolfram-alike works this way, and the Haskell attempt to do otherwise
(`references/papers/haskell/olah_hasksymb_readme.html`) concluded that variables cannot be put into
types without dependent types. The kernel's job is uniform traversal and matching over a
heterogeneous term language, and a typed AST fights that at every step.

**The algebra layer is typed where types pay.** The coefficient ring and the monomial order are type
parameters, so a lex-ordered polynomial cannot meet a grevlex one and a ℤ coefficient cannot be
divided as if it were in ℚ (`references/papers/haskell/ishii2018_*.pdf`). **The variables are
runtime data carried by each polynomial**, and every operation aligns its operands' variables before
combining them (§5.2). Types cannot do this job here. Type-level arity misses the dangerous case —
ℚ[x,y] and ℚ[y,z] are both arity 2, and combining them by position is silently wrong — and Ishii's
type-level variable labels (`LabPoly`, §2.3 of the paper) cannot name a generalized variable such as
`Sin[x]` (§5.1), which is an `Expr`, not a type-level string. D13.

**The bridge is explicit and lossy in one direction** (§5.1): recognizing an `Expr` as a polynomial
in given variables can fail and returns `Maybe`; going the other way always succeeds.

This split is the design's most consequential commitment. It exists to prevent failure mode (a) in
`notes/cas-haskell.md`: "trying to make the core type-safe and drowning in type-level machinery".

### 1.2 Layers and the dependency rule

```
                       ┌─────────────────────────────────────┐
  L5  Frontend         │ Syntax.Lexer/.Parser/.FullForm/     │
                       │ .Pretty · REPL                      │
                       └────────────────┬────────────────────┘
                       ┌────────────────┴────────────────────┐
  L4  Builtins         │ Builtins.* · Simplify.*             │──┐
                       │ Integrate.Rules                     │  │
                       └────────────────┬────────────────────┘  │
                       ┌────────────────┴────────────────────┐  │  (L4 only)
  L3  Evaluation       │ Eval · .Kernel · .Message · Rules   │  │
                       └────────────────┬────────────────────┘  │
                       ┌────────────────┴────────────────────┐  │
  L2  Matching         │ Pattern.* · Attributes              │  │
                       └────────────────┬────────────────────┘  │
                       ┌────────────────┴────────────────────┐  │
  L1  Terms            │ Core.Expr · .Intern · .Order        │  │
                       │ .Symbol · .Traversal · Structure    │  │
                       └────────────────┬────────────────────┘  │
                       ┌────────────────┴────────────────────┐  │
  L0  Numbers          │ Number · Number.Integer             │  │
                       └────────────────┬────────────────────┘  │
                                        │                       │
                       ┌────────────────┴────────────────────┐  │
  A   Algebra (side)   │ Algebra.* · Poly.* · Zero           │◀─┘
                       │ Groebner · Summation.* · Solve      │
                       │ Integrate.Rational, .Risch          │
                       │ Series · Limit                      │
                       └─────────────────────────────────────┘
```

**Imports go down, never up, and never sideways into `A` except from L4.** The algebra tower hangs
off `Number` and knows nothing about `Expr`, which keeps the polynomial code testable without a
kernel and the kernel testable without polynomials.

**Two modules of `A` are bridges, and the only exceptions.** `Cassini.Poly.Convert` imports
`Cassini.Core.Expr`, because recognizing a polynomial requires seeing an `Expr`; `Cassini.Zero`
imports `Cassini.Eval.Kernel`, because deciding zero requires evaluating (§5.6). Nothing else in `A`
is in §2.6's `within` lists, so the rest cannot see an `Expr` and compiles without the kernel.

**One seam in L3 is visible from L2.** The matcher evaluates side conditions (§4.5.2), so it names
the `Kernel` effect, whose constructors name `SymbolInfo` from `Cassini.Rules`. The effect
*declaration* and the rule tables are the bottom of L3 and importable by `Cassini.Pattern.*`; the
evaluation *sequence* in `Cassini.Eval` is not. §4.3 explains how code below it still evaluates.

### 1.3 Two shapes of computation

Everything in the kernel is one of two things, and conflating them is the classic mistake:

- **Rewriting** — a rule table plus a strategy. Nondeterministic (a pattern may match many ways),
  effectful (side conditions evaluate), unpredictable in cost.
- **Canonicalization** — a total function to a normal form. Deterministic, terminating, bounded by
  term size.

`Plus`, `Times` and `Power` are canonicalized (§4.6); everything else is rewritten. Canonicalization
is installed *as* the built-in rules for those three heads, so the evaluator sees one mechanism — but
the code behind that seam is a total function with an idempotence law, not a rule set with a
fixed-point loop.

---

## 2. Repository and package layout

### 2.1 Three packages

A root `cabal.project` lists three packages, each in a directory of its own name:

| Package | Holds |
| :--- | :--- |
| `cassini-prelude` | `Cassini.Prelude` (§2.3), the prelude every other package builds against. |
| `cassini-core` | The library, L0–L5 below the interactive loop, including script mode (`Cassini.Script`); the `intern` flag (§3.4); every test suite and the benchmark suite (§7, §8). |
| `cassini-repl` | The `cassini` executable and, from milestone 1c, `Cassini.REPL`, the interactive loop (§4.10). |

The repository root keeps what spans packages: this document, `notes/`, `references/`, `lint/`,
`scripts/`, `.hlint.yaml` and CI. **Paths in this document under `src/`, `src-intern/`, `test/`,
`test-support/`, `bench/`, `corpus/` and `oracle/` are relative to `cassini-core/`**, which is also
the directory cabal runs that package's suites in, so the suites' relative paths are these.

**Why split, and why there.** The trigger is dependency divergence, not size. The interactive loop
wants terminal dependencies (line editing, history) that nothing else does, and a user of the
rewriting kernel should not pay for them. The prelude is the one thing every package needs, so it
is its own package rather than a sublibrary of one of them. Script mode stays in `cassini-core`
because the test suites, the oracle, the corpus and the benchmarks all run scripts. The rule still
holds for what comes next: when the algebra tower (`A`, §1.2) wants dependencies the kernel does
not, `cassini-algebra` becomes a fourth package so that a user of the kernel does not pay for
Gröbner bases. D7.

The layering of §1.2 is per module, not per package, and §2.6 enforces it across all three.

### 2.2 Module tree

Every module has one job. `Internal` modules expose representations; their non-`Internal` siblings
expose the API (the `containers`/`vector` convention).

| Module | Charter |
| :--- | :--- |
| **L0** | |
| `Cassini.Number` | Exact rationals over `Integer`: normalization, arithmetic, numeric order. |
| `Cassini.Number.Integer` | Integer roots, trial division, strong pseudoprimality, `factorInteger` (§4.15). No `Expr`. |
| **L1** | |
| `Cassini.Core.Symbol` | Interned symbol names with contexts. `Text`-backed, `Int`-compared. |
| `Cassini.Core.Expr` | The `Expr` API: smart constructors, pattern synonyms, accessors. **No representation.** |
| `Cassini.Core.Expr.Internal` | The representation: node shape, cached hash, intern id, `Eq`. Imported only by `Cassini.Core.*`. |
| `Cassini.Core.Intern` | The hash-consing table, private behind the one exported `intern`. Two implementations behind a flag (§3.4). |
| `Cassini.Core.Order` | `compareCanonical`, Cohen's order relation extended to all terms. The kernel's *only* ordering. |
| `Cassini.Core.Traversal` | Base functor, `recursion-schemes` instances, `rewriteM`. |
| `Cassini.Structure` | Structure-based operators: `exprKind`, `part`, `numberOfParts`, `construct`, `freeOf`, `substitute`. |
| **L2** | |
| `Cassini.Attributes` | The attribute set as a bitmask, and the predicates the evaluator asks it. |
| `Cassini.Pattern` | The pattern language as a view over `Expr`, plus `Subst`. |
| `Cassini.Pattern.Match` | The matcher's public face: `matchOne`, `matchAll`, and the `MatchT` monad. |
| `Cassini.Pattern.Syntactic` | Structural matching, no attributes. |
| `Cassini.Pattern.Sequence` | `BlankSequence`/`BlankNullSequence` distribution over a flat argument list. |
| `Cassini.Pattern.Commutative` | The five-phase `Orderless` matcher (§4.5.4). |
| `Cassini.Pattern.Net` | `RuleIndex`: candidate retrieval for rule lookup, keyed on the first argument's head (§4.5.5). Never imports `Pattern.Match`. |
| **L3** | |
| `Cassini.Rules` | `Rule`, `RuleSet`, `SymbolInfo`, the four rule tables and the ladder. |
| `Cassini.Eval.Kernel` | The `Kernel` effect, `KernelState`, and the two interpreters, parameterized by the evaluation sequence (§4.3). |
| `Cassini.Eval` | The standard evaluation sequence, the fixed-point loop, and the knot-tied interpreters. |
| `Cassini.Eval.Message` | The `Message` type and emission. Formatting is L5's job. |
| **L4** | |
| `Cassini.Simplify.Automatic` | Cohen's automatic simplification: `Plus`, `Times`, `Power` to canonical form. |
| `Cassini.Simplify.Elementary` | Automatic rules for the elementary functions: special values, parity, periodicity, `E^(c·Log[z])` (§4.11). |
| `Cassini.Simplify.Rational` | Algebraic expansion, `Expand_main_op`, rationalization, numerator and denominator over ASAEs (§4.12). |
| `Cassini.Simplify.Trig` | Trigonometric expansion, contraction and `Simplify_trig`, circular and hyperbolic (§4.12). |
| `Cassini.Simplify.Numeric` | Radical normalization of rational bases and the infinity pass for `Plus`/`Times`/`Power` (§4.15). |
| `Cassini.Builtins` | Registry assembly — one `KernelState` with every builtin installed, and the attribute-only symbols the evaluator relies on (`Hold` and its relatives, `Sequence`, `Unevaluated`, `Function`, the pattern heads, the atom heads). |
| `Cassini.Builtins.Define` | The `Definition` each builtin module exports (a symbol, its attributes, its native rules), and the helpers they share. |
| `Cassini.Builtins.Arithmetic` | `Plus`, `Times`, `Power`, `Divide`, `Subtract`, `Minus`, `Sqrt` (which evaluates to `Power[x, 1/2]`, as in WL), and the infinities as symbols: `ComplexInfinity` evaluates to `DirectedInfinity[]` and `Infinity` to `DirectedInfinity[1]`, as WL's outputs show. Comparison is `Builtins.Logic`'s. |
| `Cassini.Builtins.Structural` | `Head`, `Part`, `Length`, `Apply`, `Map`, `Level`, `FreeQ`. |
| `Cassini.Builtins.List` | List construction and manipulation. |
| `Cassini.Builtins.Pattern` | `MatchQ`, `Cases`, `Replace`, `ReplaceAll`, `ReplaceRepeated`, `ReplaceList`. `RuleDelayed` has no rules, only attributes, so `Cassini.Builtins` defines it beside `Rule`; `ReplaceList` is here because it is the language's way to see every match (§4.5.2). |
| `Cassini.Builtins.Assign` | `Set`, `SetDelayed`, `TagSet`, `Unset`, `Attributes`, `Protect`. |
| `Cassini.Builtins.Elementary` | `Sin` … `Csc`, `Sinh` … `Csch`, `ArcSin` … `ArcCsc`, `Exp`, `Log`: downvalues and `Derivative` subvalues (§4.11). |
| `Cassini.Builtins.Simplify` | `TrigExpand`, `TrigReduce`, `Simplify` (§4.12), and the internal ``Cassini`TrigZero`` that `isZero` evaluates (§5.6). |
| `Cassini.Builtins.Control` | `Function`, `CompoundExpression`, `If`/`Which`/`Switch`, `Module`/`Block`/`With`, `Catch`/`Throw`, `Do`/`While`/`For`/`Until`, `Scan`, iterators, `Nest`/`Fold`/`FixedPoint` (§4.13). |
| `Cassini.Builtins.Logic` | `Equal` and the orderings, `SameQ`, `TrueQ`, `And`/`Or`/`Not` (§4.14). |
| `Cassini.Builtins.Integer` | `Abs`, `Sign`, `Floor`, `Ceiling`, `Round`, `Mod`, `Quotient`, `GCD`, `LCM`, `Binomial`, `Factorial`, `Max`, `Min`, `PrimeQ`, `FactorInteger`, `Numerator`, `Denominator` (§4.15). |
| `Cassini.Builtins.Calculus` | `D`, `Integrate`, `Series`, `Normal`, `Limit`, `Sum`, `Product`; `RootSum` (§6.5). |
| `Cassini.Builtins.Polynomial` | `Expand`, `ExpandAll`, `Collect`, `Cancel`, `Factor`, `Together`, `Apart`, `PolynomialGCD`, `Coefficient`, `Exponent`, `Variables`, `Resultant`, `Discriminant`, `GroebnerBasis`, `PolynomialReduce`, `Solve` (§6.5). |
| `Cassini.Integrate.Rules` | The tier-1 integration rule set and its loader (§6.2). **L4 despite its namespace**: it names `Expr`, `Cassini.Rules` and the surface syntax exactly as `Cassini.Builtins.*` does. |
| **L5** | |
| `Cassini.Syntax.Lexer` | Tokens. |
| `Cassini.Syntax.Parser` | Infix surface syntax to `Expr`. |
| `Cassini.Syntax.FullForm` | `Plus[a, Times[2, b]]` — read and print. The golden-test format. |
| `Cassini.Syntax.Pretty` | Infix output with precedence-driven parenthesization; message formatting. |
| `Cassini.Script` | Script mode: `runScript` and `traceScript`, FullForm in and out (§4.10, §7.4). In `cassini-core`, because every suite runs scripts. |
| `Cassini.REPL` | The read-eval-print loop, `In[]`/`Out[]` (§4.10), from milestone 1c; the executable's body. The one L5 module in `cassini-repl`. |
| **A** | |
| `Cassini.Algebra.Class` | The coefficient-tower classes `semirings` does not supply (§5.3). |
| `Cassini.Poly.Uni` | Dense univariate over a coefficient ring. |
| `Cassini.Poly.Multi` | Sparse distributed multivariate carrying its variables; operations align them (§5.2). Monomial order a type parameter. `.Internal` is the positional core for aligned inputs. |
| `Cassini.Poly.Convert` | The `Expr` ↔ polynomial bridge (§5.1). |
| `Cassini.Poly.GCD` | The GCD ladder (§5.4). |
| `Cassini.Poly.Factor` | Squarefree, finite-field, Hensel, recombination (§5.5). |
| `Cassini.Poly.Resultant` | Resultants and subresultant PRS. |
| `Cassini.Zero` | The layered zero test (§5.6). The other bridge. |
| `Cassini.Groebner` | Buchberger, then F4 (§6.1). |
| `Cassini.Integrate.Rational`, `.Risch` | Rational and transcendental integration (§6.2). |
| `Cassini.Summation.*` | Gosper, Zeilberger (§6.3). |
| `Cassini.Series`, `Cassini.Limit` | Truncated power series as a coefficient ring over §5.2's representations, and series-based limits (§6.4); `Cassini.Builtins.Calculus` converts to `SeriesData` and back (§6.5). |
| `Cassini.Solve` | Fraction-free elimination and Gröbner-based polynomial systems (§6.4); returns triangular systems of polynomials, not `Expr` rules; `Solve` converts (§6.5). |

### 2.3 The prelude

`relude` is the prelude, wired in through cabal `mixins`. It re-exports mtl's `State`/`Reader`
vocabulary, and fifteen of those names — `State`, `get`, `put`, `modify`, `gets`, `state`,
`runState`, `evalState`, `execState`, `Reader`, `ask`, `asks`, `local`, `runReader`, `withReader` —
collide one for one with `Effectful.State.Static.Local` and `Effectful.Reader.Static`. Fixing that
with qualified imports in fifty modules is fifty chances to get it wrong, so it is fixed once, in a
package of its own (§2.1):

```cabal
-- cassini-prelude/cassini-prelude.cabal
library
  import:           warnings, extensions
  exposed-modules:  Cassini.Prelude
  build-depends:    relude
  mixins:
      relude (Relude as Prelude)
    , relude
  default-language: GHC2024

-- cassini-core/cassini-core.cabal, and every other consuming stanza
library
  import:           warnings, extensions
  build-depends:    base, cassini-prelude, effectful, ...
  mixins:
      base            hiding (Prelude)
    , cassini-prelude (Cassini.Prelude as Prelude)
  ...
```

Every stanza that consumes the prelude carries the same two `mixins` lines. Verified against GHC
9.12.4 and cabal 3.16.1.0:

- **The bare name `cassini-prelude`**, in both `build-depends` and `mixins`, now that it is a
  package. While it was an internal sublibrary of the single package, cabal required the qualified
  `cassini:cassini-prelude` in both places and rejected the bare one as *unknown package*.
- **The prelude package depends on `relude` alone, through two `mixins` lines.** Without
  `relude (Relude as Prelude)`, GHC's implicit `import Prelude` has nothing to resolve to (*Could not
  load module 'Prelude'*); base's `Prelude` must not be visible beside it, because relude
  *redefines* `show`, `lines`, `error` and others and the re-export becomes ambiguous. Relude's
  third recommended line, `base hiding (Prelude)`, is unnecessary here: `Cassini.Prelude` imports
  nothing from `base`, so `base` is not a dependency and its `Prelude` is not in scope at all.
  The bare `relude` line keeps `import Relude hiding (…)` possible. Consumers, which do import
  from `base`, carry `base hiding (Prelude)` instead of a third line.
- **The subtraction survives.** Inside `Cassini.Prelude` the hidden names are back in scope via the
  implicit `Prelude`, but `module Relude` exports only names in scope qualified as `Relude.…`, which
  `hiding` denies. A consumer gets *Not in scope* for `put` and may define its own `one`.

```haskell
module Cassini.Prelude (module Relude) where

import Relude hiding
  ( -- collides name-for-name with Effectful.State.Static.Local
    State, get, put, modify, gets, state, evalState, execState, runState
    -- collides name-for-name with Effectful.Reader.Static
    -- (its withReader is effectful's reinterpreter, not mtl's)
  , Reader, ask, asks, local, runReader, withReader
    -- no effectful counterpart, but the kernel has no transformer stack (§4.3):
    -- a module that wants one says so in its own import list
  , StateT, MonadState, modify', evalStateT, execStateT, runStateT
  , ReaderT, MonadReader, runReaderT
    -- collides with this project's vocabulary
  , one        -- Relude.Container.One's singleton; we want the ring constant
  , Undefined  -- Relude.Debug's marker type; we want Cohen's Undefined (§4.6)
  )
```

The list was checked against the export lists of `Relude.Monad.Reexport`, `Effectful.Reader.Static`
and `Effectful.State.Static.Local`, and is grouped by reason. In the source the grouping is a
comment above the import, because ormolu sorts import lists. **The last group will grow**; where
relude's meaning is unrelated to ours it is subtracted here, not dodged by renaming domain types.

Consequences:

- **`Text` is the string type**; `String` only where a dependency demands it.
- **`show` is `ToText`-polymorphic.** `Show` is for GHCi and test output; `Cassini.Syntax.Pretty` is
  the rendering path.
- **No partial functions** — no `head`, `fromJust`, `!!`. Indexing (`Part`, argument access) returns
  `Either` with a message, as the language requires anyway (§4.7).
- **No `unsafePerformIO`.** Two modules import `System.IO.Unsafe` explicitly: `Cassini.Core.Symbol`,
  for the symbol table (§3.2), and `Cassini.Core.Intern`, in each of its two implementations (§3.4).
  One more uses an unsafe primitive: `Cassini.Core.Expr.Internal`, whose `Eq` tests pointer
  equality first (§3.4). `grep -rlE 'System.IO.Unsafe|reallyUnsafe' src src-intern`, run in
  `cassini-core/`, listing exactly those four files is a complete audit of the tree's unsafety.

### 2.4 Compiler, warnings and extensions

GHC 9.12.4, cabal 3.16, `default-language: GHC2024`. A `common` stanza carries the warning set,
which is not relaxed per module:

```cabal
common warnings
  ghc-options:
    -Wall -Wcompat -Widentities
    -Wincomplete-record-updates -Wincomplete-uni-patterns
    -Wmissing-export-lists -Wpartial-fields -Wredundant-constraints
```

CI adds `-Werror` from the command line (§2.8) rather than in the cabal file, which Hackage rejects.

**`-Wunused-packages` is not in the set**, because under §2.3's prelude it cannot be satisfied.
GHC decides it from import names before compiling, and misses two kinds of use: a package used
only through the mixin-renamed implicit `Prelude` (`cassini-prelude`, in every stanza), and `base`
used only through modules that GHC 9.12's `base` re-exports from `ghc-internal` (`Text.Show`,
`System.IO.Unsafe`). Both are reported unused, and `-Werror` fails the build. Dependency hygiene
is a review item until GHC resolves renamed and re-exported modules for this check.
`-Wmissing-export-lists` is the load-bearing warning: every module states its interface, which is
what makes §1.2's layering checkable and the `Internal` convention meaningful.

Extensions are declared per module, so that a module's header says what it needs — with two
exceptions, project-wide in a second `common` stanza imported by every stanza (the prelude
package's included) as `import: warnings, extensions`:

```cabal
common extensions
  default-extensions:
    OverloadedRecordDot
    OverloadedStrings
```

**The test for the project-wide tier is whether a per-module pragma would still carry
information.** Both would appear in nearly every header (`Text` everywhere; `r.field` as the house
default) and so say nothing there. `OverloadedRecordDot` is *not* in GHC2024: without it `r.rName`
parses as `r . rName` and fails as a confusing type error.

**Both stanzas are copied into each package's `.cabal` (§2.1), and a script keeps the copies
equal.** A `.cabal` file cannot import a `common` stanza from another file, and a `cabal.project`
cannot carry `default-extensions`. Even if it could, ormolu reads extensions from the `.cabal`
file nearest the source file, not from the project (§2.5). `scripts/check-common-stanzas.sh`
fails when any package's two stanzas differ from `cassini-core`'s, and CI runs it (§2.8 step 5).

Per module, as needed: `PatternSynonyms` and `ViewPatterns` (§3.3), `TypeFamilies` (every `type
instance` — `Base Expr` in §3.6, `DispatchOf Kernel` in §4.3 — and the algebra tower), `DerivingVia`
(§4.1). `DataKinds`, `GADTs`, `LambdaCase` and `DerivingStrategies` are already in GHC2024, and
neither they nor the two project-wide extensions are ever declared: `-Wall` does not warn on a
redundant pragma, so one is invisible noise claiming a need the module does not have. (Checked by
compiling one-line modules against bare `-XGHC2024`.)

### 2.5 Formatting and lint

`ormolu` and `hlint` (with a committed `.hlint.yaml`), both run in CI in check mode.

**`ormolu` because it has no style configuration.** There is nothing to write, revisit or argue
about in review, which is the whole value being bought. The `.ormolu` file it reads carries operator
*fixities*, not style, and is needed only once a module declares custom operators.

**Ormolu must see the cabal file; never pass `--no-cabal`.** It reads `default-extensions` from the
`.cabal` file, resolving `common` stanza imports. With `--no-cabal` it parses `r.rName` without
`OverloadedRecordDot` and *rewrites the source* to `r . rName`, silently changing its meaning.
(Verified with ormolu 0.8.0.2.) It finds the cabal file by walking up from each source file, so
`ormolu --mode check $(git ls-files '*.hs')` at the root reads each package's own `.cabal`.

**hlint does not read the cabal file at all**, so `.hlint.yaml` passes the project-wide
extensions as `arguments`. Without them hlint parses `(f x).field` as composition and suggests
`f x . field`, which changes the meaning.

### 2.6 Layering, enforced

§1.2's rule is a lint rule, so that breaking it fails CI rather than being noticed in review.
`.hlint.yaml`:

```yaml
- modules:
    # 1. The evaluation sequence is above matching: nothing below L3 may import it.
    - name: [Cassini.Eval, Cassini.Eval.Message]
      within: [Cassini.Eval.**, Cassini.Simplify.**, Cassini.Builtins.**,
               Cassini.Integrate.Rules, Cassini.Syntax.**, Cassini.Script, Cassini.REPL,
               Main, Test.**, Bench.**]
    # 2. The Kernel effect and the rule tables are the vocabulary L2 needs for side
    #    conditions (§4.5.2). Cassini.Rules is deliberately absent: Eval.Kernel imports it.
    - name: [Cassini.Eval.Kernel, Cassini.Rules]
      within: [Cassini.Pattern.**, Cassini.Eval.**,
               Cassini.Simplify.**, Cassini.Builtins.**, Cassini.Integrate.Rules,
               Cassini.Syntax.**, Cassini.Script, Cassini.REPL, Cassini.Zero, Main, Test.**, Bench.**]
    # 3. The algebra tower does not see Expr; Poly.Convert and Zero are the bridges.
    #    Every L1 module whose API is over Expr is named, not just the type's own.
    - name: [Cassini.Core.Expr, Cassini.Core.Order, Cassini.Core.Traversal, Cassini.Structure]
      within: [Cassini.Core.**, Cassini.Structure, Cassini.Attributes,
               Cassini.Pattern.**, Cassini.Rules, Cassini.Eval.**,
               Cassini.Simplify.**, Cassini.Builtins.**, Cassini.Integrate.Rules,
               Cassini.Syntax.**, Cassini.Script, Cassini.REPL, Cassini.Zero, Cassini.Poly.Convert,
               Main, Test.**, Bench.**]
    # 4. The representation is private to the core, and to the interning-agreement test.
    #    The intern table builds nodes, so it is private to the core outright: only
    #    Internal's mkNode calls it.
    - name: Cassini.Core.Expr.Internal
      within: [Cassini.Core.**, Test.Cassini.Core.Intern]
    - name: Cassini.Core.Intern
      within: [Cassini.Core.**]
    # 5. L4 and L5 are the top: nothing below them, and nothing in A, may import them.
    #    L5 spans two packages: Cassini.Script is cassini-core's script mode, and
    #    Cassini.REPL is cassini-repl's interactive loop (§2.1).
    - name: [Cassini.Simplify.**, Cassini.Builtins.**, Cassini.Syntax.**, Cassini.Script, Cassini.REPL]
      within: [Cassini.Simplify.**, Cassini.Builtins.**, Cassini.Integrate.Rules,
               Cassini.Syntax.**, Cassini.Script, Cassini.REPL, Main, Test.**, Bench.**]
    # 6. Nondeterminism is private to the matcher's monad (§4.5.2).
    - name: [Control.Monad.Logic, Control.Monad.Logic.Class]
      within: [Cassini.Pattern.Match]
```

Rules 1 and 2 split L3 at §1.2's seam. Rule 5 guards the top of the stack: without it nothing stops
`Cassini.Zero` importing `Cassini.Simplify.Automatic`, and GHC would not object, since that is not a
cycle. `Main`, `Test.**` and `Bench.**` appear throughout because `hlint .`, run at the root, walks
every package's suite directories and `cassini-repl/app/`. The rules are by module name, so one
config covers all three packages. §4.11–§4.12's modules need no rule of their own: `Cassini.Simplify.**` and
`Cassini.Builtins.**` already place them, and they import only downward within L4
(`Simplify.Trig` → `.Elementary`, `.Rational`; `.Rational` → `.Elementary`, for `simplifyE`;
`.Elementary` → `.Numeric`; `.Numeric` → `.Automatic`; `Builtins.Arithmetic` → `Simplify.Elementary`, for `simplifyExpPower`,
and → `Simplify.Numeric`). The same holds for
§4.13–§4.15 and §6.5: `Cassini.Number.Integer` sees no `Expr`, and `Cassini.Solve` is in `A`, where
rule 3 keeps it off `Expr` and `Cassini.Builtins.Polynomial` converts its results.

The hlint behaviours this depends on (checked against fixture modules and hlint's
`Hint/Restrict.hs`, which matches module names with `filepattern` after turning `.` into `/`):

- **`within` is an allow-list with no negation**, so every rule says "who may".
- **`within` lists union across rules whose `name` matches the same module**, so rules name disjoint
  sets: rule 1 names `Cassini.Eval.Message` rather than `Cassini.Eval.**`, which would overlap
  rule 2 and admit the matcher to the sequence, and rule 3 must not name `Cassini.Core.Expr.*`, which
  would re-admit everyone to `.Internal`.
- **`Foo.*` is exactly one component; `Foo.**` is `Foo` and all descendants.** `Test.*` would miss
  `Test.Cassini.Core.Order`, hence `**` everywhere.
- **Bare `Foo` does not match `Foo.Bar`**, hence rule 6 names `Control.Monad.Logic.Class` too.

CI checks the config with fixture modules — at least one at `Test.Cassini.…` depth, where the
`*`/`**` mistake hides: `Cassini.Poly.Uni` importing `Cassini.Core.Expr` is reported and
`Cassini.Poly.Convert` is not; `Cassini.Poly.Uni` importing `Cassini.Core.Intern` is reported;
`Cassini.Pattern.Commutative` importing `Control.Monad.Logic` is
reported and `Cassini.Pattern.Match` is not; `Cassini.Zero` importing `Cassini.Simplify.Automatic`
is reported and `Cassini.Builtins.Polynomial` is not.

The fixtures are one-import modules in `lint/fixtures/reported/` and `lint/fixtures/allowed/`, and
`lint/check-layering.sh` asserts that hlint reports every import in the first set and none in the
second. They break the rules on purpose, so the tree-wide run excludes them:
`hlint --ignore-glob='lint/fixtures/**' .`.

### 2.7 Documentation

Haddock on every export. A module implementing a published algorithm names its source in the module
header, which lets a reader check the implementation against its justification and makes this
document's citations checkable from the other end:

```haskell
-- | Automatic simplification of sums, products and powers.
--
-- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.2 (procedure
-- @Automatic_simplify@ and its subordinate operators).
module Cassini.Simplify.Automatic (simplify, isASAE) where
```

### 2.8 CI

`.github/workflows/ci.yml`, `haskell-actions/setup`, **one GHC: 9.12.4**.

1. `cabal build --enable-tests --enable-benchmarks --ghc-options=-Werror all`
2. `cabal test cassini-test` (unit, property, golden)
3. `cabal test -f intern cassini-test` — the same suite with the interning flag flipped (§3.4), so
   both implementations of `Cassini.Core.Intern` are compiled and tested on every commit
4. doctests: `cabal repl --with-repl=doctest --repl-options=-Wno-missing-export-lists lib:cassini-core`
   (§7.6), under each `intern` setting
5. `hlint --ignore-glob='lint/fixtures/**' .`, plus `lint/check-layering.sh` (§2.6) and
   `scripts/check-common-stanzas.sh` (§2.4)
6. `ormolu --mode check $(git ls-files '*.hs')` — no `--no-cabal` (§2.5)
7. `cabal haddock --haddock-quickjump`, with a scripted floor on haddock's documented-percentage:
   `scripts/check-haddock.py`, at 100% for every module except `Cassini.Prelude`, whose exports are
   relude's
8. the benchmark gate (§8.6), from milestone 1a: the `bench` job runs the end-to-end workload under
   each `intern` setting (`cabal bench cassini-bench`, named, because the root is no package's
   directory) and checks its allocation with `bench/check-allocation.py --only All.EndToEnd`

Steps 1–7 are Stage 0's exit condition (§10); step 8 needs an evaluator to measure. Every cabal
command in the workflow takes the same `--enable-tests --enable-benchmarks --ghc-options=-Werror`,
so that no step reconfigures the build and the `intern` build is held to `-Werror` too. A
command-line `-f intern` reaches `cassini-core` whichever target is named, because cabal applies it
to every local package that declares the flag (checked in `plan.json`, cabal 3.16.1.0). The
dependencies carry `^>=` bounds at the versions CI first resolved. Step 2 names
its suite rather than `all`, which would pull the slow suite into every commit. A nightly job runs
`cassini-oracle`, `cassini-slow`, `cassini-corpus` and the random-seed property run (§7.1, §7.3,
§7.8). CI's `cassini-corpus` covers the vendored and fetched corpora only: the Wolfram documentation
corpus is never on a CI runner (§7.9), so its ratchet is checked on a developer machine.

**One compiler, because the version bound says so.** `base ^>=4.21.2.0` admits only GHC 9.12, so a
wider matrix would be jobs failing at dependency resolution, read as flaky and then ignored.
Widening the bound and the matrix is one deliberate change: every `Cassini.Prelude` subtraction must
hold across both `relude` builds, and each compiler needs its own benchmark baseline (§8.6). D12.

### 2.9 Versioning

PVP. `CHANGELOG.md` is written as changes land, not at release. Until `1.0`, `Expr`'s representation
is explicitly unstable and the `Internal` modules carry no compatibility promise — which keeps the
interning decision (§3.4) reversible.

---

## 3. Stage 0 — foundations

A term representation that is cheap to build, compare and traverse, over an exact numeric tower.
Nothing here evaluates anything. This is the stage most likely to be rushed and the most expensive
to get wrong, because every later layer is written against these types.

**Exit criterion:** large expressions can be constructed, compared and traversed at measured cost,
`compareCanonical` passes its order laws, and §2.3–§2.8's tooling exists. See §10.

### 3.1 Numbers

```haskell
-- | Cassini.Number
data Number
  = NInt  !Integer
  | NRat  !Rational   -- ^ invariant: denominator > 1, reduced, sign on numerator
  deriving stock (Eq, Show)

-- | Numeric order, not constructor order.
instance Ord Number where compare = compareNumber

compareNumber :: Number -> Number -> Ordering
```

**`Ord Number` is not derived.** The derived instance compares constructor position first, so
`NInt 5 < NRat (3 % 2)`: total, and wrong. O-1 (§3.5) needs numeric `<`, and a derived `Ord` in
scope is how the wrong one gets used by accident. The `NRat` invariant keeps derived `Eq` correct,
so `Eq` is derived and `Ord` is not.

**`Integer` is the starting point, logged as revisitable (D1).** Under `ghc-bignum`, `Integer` is
`IS Int# | IP ByteArray# | IN ByteArray#`: word-sized values are unboxed and GMP is reached only for
large ones, so the small-integer fast path a naive `mpz_t` wrapper lacks is already there
(`notes/cas-haskell.md` §"University course materials and worked build-logs"). Stage 2's polynomial
benchmarks are where that would first stop holding.

**`Rational` is `Ratio Integer`, but normalization is ours to schedule.** `%` pays a `gcd` on every
operation; `Cassini.Number` may batch it (normalize a sum of *n* rationals once) where measurement
shows that wins, since sums of rationals are the hottest operation in automatic simplification.

**Inexact numbers are absent** (D9). When they arrive they are a third constructor, and
`compareCanonical` must place them without disturbing the existing order; O-7 puts every number
before every non-number, which leaves room.

Cohen's `Simplify_RNE` is `simplifyRNE :: Expr -> Maybe Number` in `Cassini.Simplify.Automatic`
(§4.6), **not here**: it takes an `Expr`, and L0 cannot import L1. `Cassini.Number` owns the
arithmetic it calls — exact `+`, `*`, `^`, and division returning `Nothing` on a zero divisor.

### 3.2 Symbols

```haskell
-- | Cassini.Core.Symbol
data Symbol = Symbol { symId :: {-# UNPACK #-} !Int, symContext :: !Text, symName :: !Text }
instance Eq  Symbol where (==)    = (==)    `on` symId

-- | Map-key order only: interning order, therefore session-dependent.
instance Ord Symbol where compare = compare `on` symId

-- | Cohen's O-2: the only symbol comparison any output may depend on.
compareSymbolName :: Symbol -> Symbol -> Ordering
compareSymbolName = comparing symName <> comparing symContext
```

**`Ord Symbol` is allocation order**: right for a `Map Symbol` key (an `Int` compare in the hottest
loop), wrong for anything a user sees, because which symbol got the smaller id depends on what the
session interned first. If O-2 used it, `Plus[b, a]` would sort differently in a `--script` run and
in a REPL that had already mentioned `b`, and golden files would pass or fail on history. So O-2
calls `compareSymbolName`, and **any output produced by folding a `Map Symbol`** (`Names[]`, a
printed `Subst`) sorts with it first.

`compareSymbolName` compares **names first, context second**: Cohen's O-2 is on names, and
context-first would sort every ``Global` `` symbol before every ``System` `` one (`x` before `Pi`).
`Text` code-point order agrees with O-2's `0-9 < A-Z < a-z` on ASCII.

Symbols are interned unconditionally — cheap, obviously correct, and it buys `Int` comparison for
every rule lookup. The table is a global `IORef (HashMap (Text, Text) Symbol)` keyed on context and
name, plus a counter, behind `unsafePerformIO`/`NOINLINE`. It is append-only, so
lookup-or-allocate is one `atomicModifyIORef'`. This makes `Cassini.Core.Symbol` the second
module that imports `System.IO.Unsafe` (§2.3), compiled with `-fno-full-laziness -fno-cse` as
§3.4's table is.
Contexts (``System`Plus``, ``Global`x``) are carried from the start; retrofitting a namespace means
touching every rule key.

### 3.3 `Expr` — abstract, with pattern synonyms

The representation lives in `Cassini.Core.Expr.Internal` and is not exported past
`Cassini.Core.*`:

```haskell
-- | Cassini.Core.Expr.Internal
data Expr = Expr
  { exprHash  :: {-# UNPACK #-} !Int     -- ^ cached structural hash
  , exprId    :: {-# UNPACK #-} !Int     -- ^ intern id, or 'notInterned'
  , exprKey   :: !(IORef ())             -- ^ weak-pointer key (§3.4); one shared
                                         --   dummy when interning is off
  , exprShape :: !Shape
  }

data Shape
  = SNumber !Number
  | SString !Text
  | SSymbol !Symbol
  | SApp    !Expr !(Vector Expr)   -- ^ head and arguments, mirroring FullForm
```

`Cassini.Core.Expr` exports the type abstractly, with **bidirectional pattern synonyms** and a
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

Callers write ordinary, exhaustiveness-checked pattern matches:

```haskell
derivative :: Symbol -> Expr -> Expr
derivative x = \case
  Sym s | s == x -> one
        | otherwise -> zero
  Num _ -> zero
  App (Sym f) args -> ...
```

But every *construction* goes through `mkNumber`/`mkString`/`mkSymbol`/`mkApp`, which compute the
hash and consult the intern table. **That is the point:** the interning decision lives in four smart
constructors, not at every call site, so §3.4 can change without a repository-wide edit.

`SApp` stores the head apart from the arguments. `Part[expr, 0]` returns the head, but the head is
read on every evaluation step and arguments are indexed far less often, so `exprHead` stays a field
access; `Cassini.Structure.part` restores the 0-index convention at the API boundary. On an atom,
`exprHead` is WL's `Head`: the symbol `Integer`, `Rational`, `String` or `Symbol`.

`Int_` is bidirectional. `Rat_` matches only: building a fraction goes through
`Cassini.Number.fromRational'`, which normalizes `4/2` to an integer. A bidirectional `Rat_` would
build terms it does not match. `NRat` is still an exported constructor, so node construction
applies `Cassini.Number.normalize` as well: a raw `NRat (2 % 1)` would otherwise be a node unequal to
`2` that `compareCanonical` calls `EQ` to it. That happens once, in `Internal`'s `mkNode`, which
the `mk*` constructors and §3.6's `embed` both call: two copies of the construction policy would
let a fold build a node `mkNumber` never would.

Arguments are a boxed `Vector`: `Orderless`, `Flat` and `Listable` all want bulk operations with
known lengths, and a list makes every arity check O(n). Consing onto the front becomes O(n), which
matters in the sequence matcher, so `Cassini.Pattern.Sequence` works on O(1) slices.

### 3.4 Interning — designed to be switchable

`notes/cas-haskell.md` recommends hash-consing from day one; failure mode (e) is not doing it. This
design takes the destination but commits in two steps, because a global weak table is real
complexity to carry through every early bug.

**Step 1 (day one): cached hashes.** Every node stores its structural hash. Nearly free, needs no
`IO`, and most of the win on the comparison-heavy paths (`Orderless` sorting, rule lookup,
`MatchQ`).

**Step 2 (gated on measurement): the intern table**, a global weak-value hash table, so the collector
can reclaim nodes nothing references:

```haskell
-- | Cassini.Core.Intern
internTable :: MVar (HashMap Int [(Int, Weak Expr)])  -- keyed by hash, bucketed;
                                                      -- the Int is the entry serial 'reap' deletes
{-# NOINLINE internTable #-}
internTable = unsafePerformIO (newMVar mempty)

intern :: Shape -> Expr
```

**Equality never trusts the table.** `Eq` is defined once, in `Cassini.Core.Expr.Internal`, and is
the same whichever implementation is active:

```haskell
!x == !y = isTrue# (reallyUnsafePtrEquality# x y)                   -- same heap object
      || (exprId x == exprId y && exprId x /= notInterned)          -- same interned node
      || (exprHash x == exprHash y && exprShape x == exprShape y)   -- else hash, then structure
```

The same heap object proves equality, equal ids prove equality, unequal hashes prove inequality, and
only a hash collision or a duplicate node reaches the structural comparison. The pointer test can
report a false "different" (the collector moves objects), never a false "same", so a miss only falls
through. Ids alone would be wrong: `System.Mem.Weak` warns that weak pointers on ordinary Haskell
values are "particularly fragile" — the compiler may duplicate or unbox the key — so an entry can be reaped while its node is live, and the next `intern` of that shape then
gives an equal term a second id. With the definition above that costs a duplicate node, never an
answer, and `Eq` does not depend on the flag.

**The pointer test is for the hash-only build**, where every node is `notInterned`. Without it, a
term compared with itself, or with a term sharing its subterms, is walked in full at every level,
because the derived `Eq Shape` recurses through this `Eq`; a term built by repeated self-sharing
costs time exponential in its node count. With it, each shared subterm costs one comparison. It does
not help equal terms built apart, which stay the table's argument (D2). The bangs matter: the primop
does not force its arguments, so without them `==` is lazy, every caller's strictness is lost, and
`compareCanonical`'s arguments are passed as thunks; measured, that more than doubled its
allocation. Forcing also keeps the test from missing on a thunk and its value.

To make premature reaps rare as well as harmless, the weak pointer is keyed on a **primitive** object
the node carries — `exprKey`, a unit `IORef` allocated by `intern` and reachable only through the
node — not on the `Expr` itself: `mkWeak#` on the `IORef`'s underlying `MutVar#`, as `mkWeakIORef`
does, with the `Expr` as the value. Every copy of the node shares that `IORef`, so the key lives
exactly as long as some copy does. The extra word per node is part of what §8.2's A/B measures.

**Weak references reclaim the node, not the entry.** A dead `Weak` stays in its bucket, so each
weak pointer gets a finalizer `reap h n` (bucket key and entry serial, both `Int`s) that deletes its
own entry, and lookups drop dead entries as they scan. Neither alone suffices: finalizers lag, and
lookup visits only the buckets it is asked for.

**The table is an `MVar`, because finalizers are a second writer** on their own thread, and
`intern`'s critical section allocates the weak pointer, which is `IO` and must not be retried — so
`modifyMVar`, not `atomicModifyIORef'`.

The mechanism needs immutable terms and a collector that traces through weak references, which is
Haskell's model — our observation from `references/papers/haskell/zhu2025_hash_consing.pdf`, not the
paper's.

Also:

- **`unsafePerformIO` with `NOINLINE`, and `-fno-full-laziness -fno-cse` on the module** — the
  standard global-variable idiom, safe while only `intern` touches the table, so `intern` is the
  module's only export.
- **The switch is a cabal `manual` flag `intern`, default off**, selecting between two
  `hs-source-dirs` that implement the same one-function interface: hash-only (every node
  `notInterned`) and the weak table. CI builds and tests both (§2.8). They are `src-intern/hash`
  and `src-intern/weak`, and both hash with `Cassini.Core.Expr.Internal.hashShape`, so the hash
  does not depend on the flag.
- **`intern` forces the shape's hash before taking the `MVar`.** Hashing forces every child to
  WHNF. A child left as a thunk is a pending `intern`, and forcing it inside the critical section
  would deadlock on the table.
- **`Cassini.Core.Intern` imports the representation through `Internal.hs-boot`.**
  `Internal` must import `intern`, because §3.6's `embed` lives there, and `intern` builds
  `Internal`'s types. The boot file declares the two types in full, and must be kept in step with
  the module.
- **The gate is a number.** §8.2 runs the same workload with the flag on and off. At Stage 0 the
  workload is a constructor-built expression-swell proxy; the decision closes when §8.4's real
  `Expand` workload exists, with the elementary-functions track (§10). Interning ships if it wins
  there on both time and allocation; either way the result is recorded as D2.

### 3.5 Canonical order

**The kernel has exactly one ordering, and it is not `deriving Ord`.** Derived `Ord` compares by
constructor position — `NRat (1%2)` and `NInt 1` never compare numerically — and it would have to be
replaced later at the cost of every golden file.

`Cassini.Core.Order` implements Cohen's order relation ◁:

```haskell
-- | Cassini.Core.Order
--
-- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.1, Definition 3.26
-- (rules O-1 … O-13) and Figure 3.9.
compareCanonical :: Expr -> Expr -> Ordering
```

The rules, transcribed because they are the specification. "Kind" is Cohen's: constant, symbol,
product, sum, power, factorial, function.

| Rule | Case | Order |
| :--- | :--- | :--- |
| O-1 | both constants | numeric `<` |
| O-2 | both symbols | lexicographic — `compareSymbolName` (§3.2), never `Ord Symbol` |
| O-3 | both products, or both sums | compare last operands, then next-to-last, …; if one runs out first, it is smaller (O-3-3) |
| O-4 | both powers | bases; if equal, exponents |
| O-5 | both factorials | operands |
| O-6 | both functions | names; if equal, arguments left to right; if one argument list is a prefix of the other, the shorter first (O-6-2c) |
| O-7 | constant vs anything else | the constant first |
| O-8 | product vs power/sum/factorial/function/symbol | compare `u` with the one-operand product `·v` (recur into O-3) |
| O-9 | power vs sum/factorial/function/symbol | compare `u` with `v^1` (recur into O-4) |
| O-10 | sum vs factorial/function/symbol | compare `u` with the one-operand sum `+v` (recur into O-3) |
| O-11 | factorial vs function/symbol | if the operand is `v`, then `v` first; else compare `u` with `v!` |
| O-12 | function vs symbol | if the function's name is `v`, then `v` first; else compare the name with `v` |
| O-13 | otherwise | `not (v ◁ u)` — the swap |

**O-3's and O-6's length tiebreaks are load-bearing in Cohen's text.** Without O-6-2(c), `g[x]`
against `g[x, y]` satisfies no rule, falls to O-13, and swaps back and forth forever. The
implementation below cannot diverge that way, because O-13 is applied by kind rank, at most once.
A dropped tiebreak would then reach O-T, which orders by arity and gives the same answer. What
§7.3's laws catch is rules that disagree with one another. Making products compare left to right
among themselves, but right to left against other kinds, fails transitivity within a few hundred
generated triples and on `everyKind`'s exhaustive triples.

Cohen defines ◁ only for *distinct ASAEs* (Definition 3.26), but `compareCanonical` must be a total
order on every `Expr`: step 9 sorts the arguments of any `Orderless` head, held or not, and `Ord
Expr` keys maps. The extension takes four additions, placed so the transcribed rules are undisturbed:

| Rule | Case | Order |
| :--- | :--- | :--- |
| O-S1 | both strings | lexicographic on the `Text` |
| O-S2 | string vs any non-constant | the string first |
| O-K | kind classification | `Plus` and `Times` heads, `Power` with exactly two arguments and `Factorial` with exactly one have their Cohen kinds; any other application is a *function*, including one whose head is itself an application (`f[x][y]`) |
| O-T | the rules above say "equal" but the terms differ | a fixed structural order: kind rank, then arity, then arguments pairwise by `compareCanonical` |

- **Strings.** Cohen has none, and with O-13 as fallback an uncovered pair does not answer wrongly —
  it *diverges*: `compareCanonical (Str "a") (Str "b")` would swap forever. **Every pair of kinds
  must be covered by a rule other than O-13.** The order becomes numbers < strings < everything
  else, leaving O-7's slot for inexact numbers untouched.
- **Kinds.** A curried head has no name, so O-6/O-12 compare heads with `compareCanonical` —
  well-founded, since the head is a strict subterm. A `Power` without exactly two arguments has no
  base and exponent, so it is a function, and likewise a `Factorial` without exactly one operand
  for O-5.
- **The tiebreak.** On non-ASAEs O-8 and O-9 equate distinct terms (`Times[x]` vs `x` compares `·x`
  with `·x`; `Power[x, 1]` vs `x` compares `x^1` with `x^1`), which would make `Ord Expr` disagree
  with `Eq` and a `Map Expr` conflate keys. O-T fires only then, so on ASAEs Cohen's order is
  unchanged.
- **How the two compose.** `compareCanonical u v` is `cohen u v <> structural u v`. Here `cohen`
  is O-1…O-13 and O-S1–O-S2, and it recurs into itself, not into `compareCanonical`. On non-ASAEs
  it is therefore a *preorder*: `Times[x]` and `x` are equivalent, so `Plus[Times[x], y]` and
  `Plus[x, y]` are too. O-T, which is itself a total order, refines it lexicographically. That
  composition is transitive whenever `cohen` is a preorder, and recurring into `compareCanonical`
  instead would mix the two orders inside one comparison and lose the argument. O-T's
  "arguments pairwise" includes the head, and between atoms of one kind it compares their values.

O-3 compares from the right, so `a·x² ◁ x³` and polynomials come out in increasing degree. O-13
makes the table triangular; the implementation is one case per rule plus a `flip`-and-invert, not
every cell of the kind-by-kind table.

`Ord Expr` is `compare = compareCanonical`, or it is not defined at all. There is no third option
where both exist, because that is how the wrong one gets used.

**Stage 0 does not define it.** The instance must sit with the type in
`Cassini.Core.Expr.Internal`, since `-Wall`'s orphan warning is not relaxed per module (§2.4), and
`compareCanonical` lives above that, in `Cassini.Core.Order`. Nothing in Stage 0 keys a map on
`Expr`. The first `Map Expr` adds the instance to `Internal` through a `{-# SOURCE #-}` import of
`compareCanonical`, the mechanism §3.4 already uses for `intern`.

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

**The instances and `ExprF` live in `Cassini.Core.Expr.Internal`**, not `Cassini.Core.Traversal`.
Anywhere but the type's own module they are orphans (§2.4), and `embed` calls `intern` through the
boot-file cycle §3.4 describes. So `embed` cannot call `mkNumber` and the rest, which live above
`Internal`; it calls `Internal`'s `mkNode` (§3.3), as they do, which is the same thing.
`Cassini.Core.Traversal` re-exports `ExprF` and owns `rewriteM`.

**`recursion-schemes` over `uniplate`** (D3), for one reason: `embed` goes through the smart
constructors, so every `cata`/`ana`/`para` maintains the hash and the intern id. With `uniplate`'s
`transform`, rebuilding is the caller's business, and one caller that forgets leaves a stale hash
that still "works". For the same reason both instances are written out: the `Generic` defaults do
not fit a record carrying a hash and an id, and rebuilding the record by hand is the same bug.

For "rewrite everywhere until fixed", `Cassini.Core.Traversal` exports
`rewriteM :: (Monad m) => (Expr -> m (Maybe Expr)) -> Expr -> m Expr`, written as direct recursion
over `project`/`embed`. It cannot be built on `apo`, whose coalgebra is pure, and `recursion-schemes`
5.2.3 has no monadic apomorphism. The monadic shape is required, because the callers that want this
are the ones whose rewrite step evaluates (§4.3).

`Foldable`/`Traversable` on `ExprF` give `Cassini.Structure` most of its implementation for free.

### 3.7 Structure-based operators

`Cassini.Structure` implements Cohen's primitive expression operators — `Kind`, `Operand`,
`Number_of_operands`, `Construct`, `Free_of`, `Substitute`, `Sequential_substitute`,
`Concurrent_substitute` (`references/papers/textbooks/cohen2002_*.pdf` §3.3):

```haskell
-- | Cassini.Structure
exprKind      :: Expr -> Kind                           -- O-K (§3.5)
part          :: Expr -> Int -> Either PartError Expr   -- 0 is the head
numberOfParts :: Expr -> Int
construct     :: Expr -> Vector Expr -> Expr
freeOf        :: Expr -> Expr -> Bool
substitute    :: Expr -> Expr -> Expr -> Expr           -- in u, t -> r
substituteSeq :: Expr -> [(Expr, Expr)] -> Expr
substituteAll :: Expr -> [(Expr, Expr)] -> Expr         -- concurrent
```

These are the Haskell API and the backing for WL's structural builtins: `Head`, `Part`, `Length` and
`Apply` in `Cassini.Builtins.Structural` are thin bindings over them. `FreeQ` and `ReplaceAll` are
**not** thin bindings: in WL their second argument is a *pattern*, and L1 cannot reach the matcher.
`freeOf` and `substitute` are their fast path when the argument contains no pattern objects; the
general case goes through the matcher in L4 (`ReplaceAll` lives in `Cassini.Builtins.Pattern`).

`part` returns `Either` because `Part` out of range must produce a message, not a crash (§4.7).
Negative indices count from the end, as in WL. `substitute` compares complete subexpressions
structurally, which is where interning pays: equal interned nodes compare by id, and unequal ones
almost always by hash. Subtrees with no occurrence are returned as they are, not rebuilt.

**One departure from Cohen: an application's head is a subexpression.** Cohen's operators are not
operands, so `Free_of` and `Substitute` never look at them. WL's `FreeQ[f[x], f]` is `False` and
`ReplaceAll` rewrites heads, and these functions are those builtins' fast path. So `freeOf` and
`substitute` visit heads.

---

## 4. Stage 1 — the kernel

A Wolfram-Language-subset evaluator: attributes, four rule tables, the standard evaluation sequence,
a pattern matcher, automatic simplification, differentiation, and enough surface syntax to type at
it.

**Exit criterion:** `Plus[a, Plus[b, a]]` flattens, sorts and *collects* to `2a + b` (milestone 1a);
the full matcher reproduces Krebber's commutative examples (1b); `D` gets the product and chain
rules right (1c). See §10.

### 4.1 Attributes

```haskell
-- | Cassini.Attributes
newtype AttributeSet = AttributeSet Word32
  deriving newtype (Eq)
  deriving (Semigroup, Monoid) via (Ior Word32)   -- Data.Bits: union of attribute sets

data Attribute
  = Orderless | Flat | OneIdentity | Listable | NumericFunction
  | HoldFirst | HoldRest | HoldAll | HoldAllComplete
  | SequenceHold | Protected | Constant | ReadProtected
  | NHoldFirst | NHoldRest | NHoldAll | Locked | Stub | Temporary
```

A bitmask, because the evaluator asks several attribute questions per step and a `Set` allocation
per question is not acceptable in that loop. The monoid is bitwise-or via `Data.Bits.Ior`: `Word32`
has no `Semigroup` of its own, so `deriving newtype` would not compile, and naming `Ior` says which
bitwise monoid is meant. The evaluator calls named predicates
(`holdsArgument :: AttributeSet -> Int -> Int -> Bool` — attributes, index, arity), not raw bit
tests, so the `HoldFirst`/`HoldRest` index arithmetic lives in one place.

The constructor list is the language's whole attribute table, including those nothing reads yet:
`Attributes[Plus]` must report what the language reports, and an attribute without a bit is a
`SetAttributes` that silently drops its argument. Nineteen names leave thirteen spare bits.

`OneIdentity` is not an evaluator attribute: it affects matching only, and is consumed in
`Cassini.Pattern.Commutative` and `.Sequence`.

### 4.2 Rules and the four tables

```haskell
-- | Cassini.Rules
data Rule = Rule
  { ruleLhs         :: !Expr          -- ^ the pattern
  , ruleBody        :: !RuleBody
  , ruleSpecificity :: !Specificity
  , ruleOrigin      :: !Origin        -- ^ which rung of the ladder this rule is on
  }

data RuleBody
  = Immediate !Expr                -- ^ from '=' (Set): RHS evaluated once, at definition
  | Delayed   !Expr                -- ^ from ':=' (SetDelayed): RHS evaluated per application
  | Native    !BuiltinId           -- ^ a Haskell implementation; 'Builtin' origin only

newtype BuiltinId = BuiltinId Int
  deriving newtype (Eq, Ord)

-- | Steps 10-13 (§4.4), in order: the only order the tables are visited in.
ladder :: Expr -> [(ValueKind, Origin)]
ladder e = [(UpValue, User), (UpValue, Builtin), (down, User), (down, Builtin)]
  where
    down = case e of
      App (App _ _) _ -> SubValue   -- h[...][...]
      _               -> DownValue  -- h[e1, ...]

data ValueKind = OwnValue | DownValue | UpValue | SubValue
  deriving stock (Eq)

data Origin = User | Builtin
  deriving stock (Eq, Ord, Enum, Bounded)

newtype RuleSet = RuleSet (Seq Rule)     -- ^ ordered; first applicable wins

data Values = Values      -- ^ one field per ValueKind
  { ownValues, downValues, upValues, subValues :: !RuleSet }

data SymbolInfo = SymbolInfo
  { siAttributes :: !AttributeSet
  , siValues     :: !Values
  }
```

Four tables, one per `ValueKind`, keyed by symbol. `OwnValues` is included so that `x = 5` falls
out of the same machinery rather than being an evaluator special case.

**`Native` exists because builtins must be installable**: `Plus`, `Part`, `Map` and `Factor` are
not `Expr`-to-`Expr` rewrites. **It holds an id, not a function**, because a function field would
mention `Kernel`, and `Cassini.Eval.Kernel` already imports `Cassini.Rules`. `KernelState` holds the
implementations, assembled by `Cassini.Builtins` (L4); the interpreter resolves the id (§4.3). A
dangling id is a construction bug, not a user-reachable failure.

**The ladder is four rungs, not two axes.** Sorting a table by specificity alone would let a specific
*user* downvalue beat a general *built-in* upvalue, the inversion steps 11–12 forbid. So
`applicableRules` takes one `(ValueKind, Origin)` rung and scans only that origin's rules;
specificity orders rules *within* a rung, never across. `ladder` is the only list steps 10–13
may iterate (§7.3 checks it).

**The tables are a record, not a map keyed by `ValueKind`.** The first version was an
`EnumMap ValueKind RuleSet`. A map has a key order, and derived `Ord` put `DownValue` before
`UpValue`, so walking the map in key order *was* the inversion. That order could be warned
against, never removed. A record has no order, and `rulesOf`/`modifyRules` select a field by
`ValueKind`. Four keys never needed a map. The map also cost a dependency: `enummapset` 0.7.3
depends on `aeson`, which had become the largest dependency of the kernel.

**Which tables a rung reads.** The upvalue rungs consult, in argument order, the `UpValues` of each
argument's head symbol (or of the argument, if it is a symbol). The lower rungs read `DownValues[h]`
for `h[e₁, …]` and `SubValues[h]` for `h[…][…]` — never both, which is why `ladder` takes the
expression: a constant `DownValue` would send `f[x][y]` to a table where `f[x_][y_] := x + y` can
never match. `OwnValues` is not on the ladder; §4.4's bare-symbol guard applies it, heads included,
since step 2 evaluates `h` by a recursive `evaluate`.

`insertRule` orders each table by specificity at definition time, insertion order breaking ties.
Specificity is a coarse structural measure (fewer blanks, more literal structure) and does not claim
WL's exact behaviour: where it cannot decide, definition order does, and that is documented. A
blank's head constraint is literal structure, so `f[x_Integer]` is tried before `f[x_]` whichever
was defined first, as in WL.

### 4.3 The kernel effect

The kernel monad is `effectful`, as **a custom, dynamically dispatched effect**:

```haskell
-- | Cassini.Eval.Kernel
data Kernel :: Effect where
  LookupSymbol   :: Symbol -> Kernel m SymbolInfo
  ModifySymbol   :: Symbol -> (SymbolInfo -> SymbolInfo) -> Kernel m ()
  EmitMessage    :: Symbol -> MessageTag -> [Expr] -> Kernel m ()
  Evaluate       :: Expr -> Kernel m Expr     -- ^ the knot; counts depth (below)
  Iterations     :: Kernel m Int              -- ^ remaining fuel in this fixed point
  SpendIteration :: Kernel m ()
  WithFuel       :: Int -> m a -> Kernel m a  -- ^ run with a fresh budget, then restore
  LookupBuiltin  :: BuiltinId -> Kernel m (Maybe BuiltinFn)  -- ^ resolve a Native rule
  TraceStep      :: Text -> Expr -> Kernel m ()              -- ^ a golden-trace entry
  KernelConfig   :: Kernel m EvalConfig                      -- ^ the limits, for fixpoint

makeEffect ''Kernel   -- evaluate :: (HasCallStack, Kernel :> es) => Expr -> Eff es Expr, …
```

**The operations are generated by `effectful-th`'s `makeEffect`**, one function per constructor,
each taking its constructor's Haddock comment. The hand-written alternative is a `send . Op`
wrapper per operation, twelve at 1a. Generating them keeps an operation in one place, which is
what adding one touches (1a added three, below). The generated signatures add `HasCallStack`;
that was measured against the hand-written wrappers on every §8 benchmark and changed allocation
by less than 0.2%. Two consequences: every constructor needs a comment, or its function is
documented as "Perform the operation …", which the Haddock floor counts as covered; and the splice
goes below every type `Kernel` mentions, because a splice ends a declaration group.

Kernel code is constraint-polymorphic over what it needs, e.g.
`matchOne :: (Kernel :> es) => Expr -> Expr -> Eff es (Maybe Subst)`.

**Three operations were added when the code was written.** `LookupBuiltin` resolves a `Native`
rule's id. `KernelState` holds the implementations (§4.2), and the rung that finds the rule has
only the effect to reach them through. A dangling id answers `Nothing`, and no rule fires.
`TraceStep` is the recording point for §7.4's golden traces. It is a no-op unless
`EvalConfig.trace` is set. `KernelConfig` gives `fixpoint` the iteration limit to seed
`WithFuel` with. An implementation is a `newtype BuiltinFn = BuiltinFn (forall es.
(Kernel :> es) => Expr -> Eff es (Maybe Expr))`, which answers `Nothing` when it does not apply.
The interpreters also discharge the `Unwind`/`CatchUnwind` pair of §4.13 from the start, because a
user rule's rung catches `Return` (§4.4).

**`Evaluate` is what makes §1.2's layering hold.** The matcher (`/;`, `?f`) and `Cassini.Zero` must
evaluate but may not import the sequence (§2.6, rule 1), and a constraint grants the effect's
operations, not `Cassini.Eval`'s functions. So evaluation is an *operation* that the interpreter
implements with the real sequence.

**The interpreters take the sequence as an argument**, because they live in `Cassini.Eval.Kernel`
and the sequence lives above it in `Cassini.Eval`:

```haskell
-- | The evaluation sequence, supplied by Cassini.Eval.
newtype Sequence = Sequence (forall es. (Kernel :> es) => Expr -> Eff es Expr)

runKernelIO   :: (IOE :> es)
              => Sequence -> EvalConfig -> IORef KernelState
              -> Eff (Kernel : es) a -> Eff es (Either Unwind a)

runKernelPure :: Sequence -> EvalConfig -> KernelState
              -> Eff (Kernel : es) a -> Eff es (Either Unwind a, KernelState)
```

`Cassini.Eval` ties the knot (`runKernelPure (Sequence evalSequence)`) and exports the closed
versions; matcher tests can supply a stub. This works because an `effectful` handler receives
`Kernel :> localEs` for the call site, so `Evaluate`'s handler runs the sequence there via
`localSeqUnlift`. **All subterm evaluation goes through `evaluate`, never directly through
`evalSequence`**, so the depth count cannot be bypassed.

`runKernelPure` is `reinterpret (runReader cfg . runState s0 . runErrorNoCallStack) handler`,
introducing and discharging `Reader EvalConfig`, `State KernelState` and `Error Unwind` (§4.13).
`runKernelIO` uses the caller's `IORef` in place of `State`, so it returns no state.

**Two limits, per the language.** "`$RecursionLimit` limits the maximum depth of the evaluation
stack […] `$IterationLimit` limits the maximum length of any particular evaluation chain"
(`references/papers/wolfram-language/wolfram_ref_evaluation_of_expressions.html`).

- **Iterations are per fixed point.** Each `fixpoint` (§4.4) opens a `WithFuel` seeded from
  `EvalConfig` and restores the caller's budget on exit. One budget per REPL input would measure
  total work instead: every subterm's fixed point spends at least one iteration, so a terminating
  `Expand[(a+b+c+d)^10]` would exhaust the default 4096 on node count alone.
- **Depth is counted by `Evaluate`'s handler**, around the sequence. At `$RecursionLimit` it emits
  `$RecursionLimit::reclim` and returns `Hold[e]` unevaluated, and evaluation continues outward: `x =
  x + 1; x` yields a partial result with a `Hold` at the cut — the source's "computations limited by
  `$RecursionLimit` … build up large intermediate structures" — rather than aborting.
  **WL 14.1 does not do this.** Its documentation corpus shows `x = x + 1` evaluating to
  `Plus[1, TerminatedEvaluation["RecursionLimit"]]`: the runaway evaluation is replaced whole, and
  there is no `Hold` at the cut (`wolfram/$RecursionLimit/BasicExamples/1`). The quotation above is
  from the older tutorial. The `Hold` cut stays, as D30, because WL's unwinding rule cannot be
  read off three examples.
  **The cut is idempotent.** At the limit, an expression that evaluates to itself comes back as it
  is: a raw atom, a symbol with no own value, or a `Hold[…]` the cut already built. Only anything
  else is wrapped, with the message. Without this, every fixed point near the limit re-evaluates its
  own result, and that crosses the limit again. Heads, `1` and `Hold` itself get wrapped, the cuts
  compound, and `x = x + 1` ran out of memory before it returned (regression case 0010).
- **Where the two counters live.** Depth is in the handler's own `Reader`, changed with `local`,
  which restores it however the inner evaluation exits: §4.13's second option. Fuel is
  handler-local `State`, not `KernelState`, because it belongs to the fixed point being run, not to
  the session. `WithFuel` saves it, runs the inner computation under `tryError`, restores it and
  rethrows.

**`Abort` is for `Abort[]` and interrupts**, which happen in production, and the REPL reports one
as `$Aborted`. An interrupt is polled for, not thrown asynchronously (§4.13). `Throw`, `Break`, `Continue` and `Return` travel the same `Error` channel, as
constructors of `Unwind` beside `UAbort`, through two more operations (§4.13). So both interpreters
return `Either Unwind a`: an interpreter runs any `Eff (Kernel : es) a`, and with `a` polymorphic it
has no `Expr` to turn an uncaught `Throw` into, while the rule against partial functions rules out
pretending one cannot arrive. Matcher tests with a stub `Sequence`, and property tests that call an
interpreter directly, can see any constructor. `Cassini.Eval`'s top-level entry catches the
non-abort ones and converts them (§4.13), so from the REPL's side only `Left (UAbort _)` occurs.

**Why this and not `ReaderT Env IO` with `IORef`s.** The property tests run `runKernelPure` under
`runPureEff`, which cannot discharge `IOE`, so the type checker guarantees the evaluator under test
is a pure function from a state and an expression to a state and an expression — testable,
shrinkable and reproducible. `IOE` appears only in `runKernelIO` and the REPL.

`Reader EvalConfig` holds the knobs fixed during evaluation (the two limits, output form); `State
KernelState` holds the symbol table, builtin implementations and pending messages, in
`Effectful.State.Static.Local` because the kernel is single-threaded (D6).

### 4.4 The standard evaluation sequence

**Transcribed** from `references/papers/wolfram-language/wolfram_ref_evaluation.html`, "The
Standard Evaluation Sequence". The numbering is this repository's; see
`references/papers/wolfram-language/CLAUDE.md` for how it relates to the page's unnumbered bullets.

For `h[e₁, …, eₙ]`:

1. If the expression is a raw object (number, string), leave it unchanged.
2. Evaluate the head `h`.
3. Evaluate each element `eᵢ` in turn.
4. If `h` has `HoldFirst`/`HoldRest`/`HoldAll`/`HoldAllComplete`, skip evaluation of certain elements.
5. Unless `h` has `SequenceHold` or `HoldAllComplete`, flatten out all `Sequence` objects among the `eᵢ`.
6. Unless `h` has `HoldAllComplete`, strip the outermost of any `Unevaluated` wrappers among the `eᵢ`.
7. If `h` has `Flat`, flatten out all nested expressions with head `h`.
8. If `h` has `Listable`, thread through any `eᵢ` that are lists.
9. If `h` has `Orderless`, sort the `eᵢ` into order.
10. Unless `h` has `HoldAllComplete`, apply **user** upvalues for `h[f[…], …]`.
11. Apply **built-in** upvalues associated with `f`.
12. Apply **user** downvalues (and subvalues) for `h[e₁, …]` or `h[…][…]`.
13. Apply **built-in** downvalues (and subvalues) for the same.

Then the fixed point: every time the expression changes, start over.

```haskell
-- | Cassini.Eval
evalSequence :: (Kernel :> es) => Expr -> Eff es Expr
evalSequence = fixpoint step
  where
    -- Steps 0 and 1 are guards on the other twelve, not stages before them.
    step e
      | evalStep1Raw e = pure e
      | Sym s <- e     = evalStep0Own s          -- OwnValues
      | otherwise =
              evalStep2Head e
          >>= evalStep34ArgsHold
          >>= evalStep5Seq   >>= evalStep6Uneval  >>= evalStep7Flat
          >>= evalStep8List  >>= evalStep9Order   >>= evalStepIndet
          >>= evalStep10UserUp
          >>= evalStep11BuiltinUp >>= evalStep12UserDown >>= evalStep13BuiltinDown

    -- Step 4 is a gate on step 3, not a stage after it.
    evalStep34ArgsHold e = evalStep4Hold e >>= \held -> evalStep3Args held e
```

Each step is a named function with its own unit test and golden trace, and the easy mistakes below
become structurally impossible once the steps are separate values in a fixed order.

**Six places where the code is not the list read literally:**

- **Step 1 is a guard.** A raw object has no head and no argument list to compute a held-position
  mask from; as a link it would hit a partial function on every literal.
- **A bare symbol is a second guard, "step 0".** The source's sequence covers `h[e₁, …]`, but
  `evaluate` reaches every symbol too. `evalStep0Own` applies `OwnValues[x]`, which steps 10–13 (keyed
  on heads) never can, and the fixed point re-enters with the result, so `x = y; y = 5; x` reaches
  `5`. Without it, `x = 5; x` returns `x`.
- **Steps 3 and 4 are one pass.** The split of the source's third bullet describes two things to
  implement, not two passes: evaluating everything and then deciding what was held would give
  `Hold[2]` for `Hold[1+1]`. `evalStep4Hold` computes the mask and `evalStep3Args` consumes it; the
  golden traces still record two entries.
- **"The attributes of `h`" (steps 4–9) is a function of the head, not a symbol lookup.** A symbol
  head supplies its own attributes; a head `Function[_, _, attrs]` supplies `attrs`, one attribute
  or a list (§4.13); any other compound head supplies none. One function, `headAttributes`, answers
  for every step, so no step can forget the `Function` case.
- **`evalStepIndet` sits between steps 9 and 10**, and is not on the source's list: when `h` has
  `NumericFunction` and some `eᵢ` is `Indeterminate`, the result is `Indeterminate` (§4.15). It
  follows step 8, so `Sin[{Indeterminate, 0}]` threads first, and precedes all four rungs, so no rule,
  user or built-in, up or down, sees an `Indeterminate` argument of a numeric function. This is what
  keeps Cohen's `Plus` from collecting `Indeterminate - Indeterminate` to 0 (§4.15).
- **A user rule evaluates its own right-hand side** (steps 10 and 12). Read literally, a rung
  returns the instantiated right-hand side and the fixed point evaluates it next round, so no
  computation corresponds to "applying the rule" and there is nothing for `Return` to exit. Here,
  when a user rule fires, the rung calls `evaluate` on the right-hand side inside `CatchUnwind`,
  turns a caught `UReturn v` into `v`, rethrows every other unwind, and hands the result to the fixed
  point, whose next round finds it settled. This is the catch point of §4.13's `Return`. Built-in
  rungs (11, 13) are Haskell and return as the list says; a pure function applies at step 13 and
  so does not catch `Return` (§4.13).

**The traps the sequence exists to prevent:**

- **Attribute order is `Flat` → `Listable` → `Orderless`** (steps 7–9). The companion tutorial's
  coarser summary lists them in another order; it summarizes *what* happens, not the sequence.
- **`Sequence` splicing precedes `Unevaluated` stripping** (steps 5–6).
- **Rule application is a four-way ladder** (steps 10–13): user upvalues → built-in upvalues → user
  downvalues → built-in downvalues. So **built-in upvalues beat user downvalues** (§4.2).

**No step may branch on `Hold`, `HoldComplete`, `HoldForm` or `ReleaseHold`.** They are attributes
plus ordinary definitions, and a patch adding such a branch is a bug. Two things are not violations:

- **Step 6 is `Unevaluated`'s implementation**, the one step that names it. (Its argument arrives
  unevaluated because `Unevaluated` has `HoldAllComplete`, not because a step special-cases it.)
  Step 6 records what it stripped, and **if no rule in steps 10–13 fires, the wrappers are
  restored**, so `f[Unevaluated[1+1]]` evaluates to itself. It records each value with its
  position, and restores by position while every value is still where it was, so
  `f[a, Unevaluated[a]]` keeps its wrapper on the second argument. Once steps 7–9 have moved
  arguments, it restores by value, on the first equal argument.
- **The two limits *construct* `Hold`** (§4.3). Building the wrapper is not branching on it.

**Two more things the list leaves implicit:**

- **`Evaluate` overrides a hold.** Step 3 evaluates a held argument anyway when it is
  `Evaluate[…]`, unless `h` has `HoldAllComplete`. So `Hold[Evaluate[1+1]]` is `Hold[2]` and
  `HoldComplete[Evaluate[1+1]]` stays. This keys on the wrapper, as step 6 keys on `Unevaluated`.
  It is not a branch on `Hold`.
- **Steps 8 and `evalStepIndet` can finish early.** A threaded list, or `Indeterminate`, is a new
  expression. The step returns it, the rungs do not run, and the fixed point evaluates it next
  round.

**What the golden trace records** (§7.4). A step is recorded when it applies, with the expression
it leaves:

- step 2 when the head changed, step 3 when an argument changed, and step 4 when anything is held;
- steps 5 and 6 when they splice or strip;
- steps 7 and 9 whenever `h` has the attribute, even when nothing moves;
- step 8 when it threads, and `evalStepIndet` when it fires;
- a rung when a rule fires: a built-in's result, or a user rule's right-hand side before the rung
  evaluates it.

Recording 7 and 9 unconditionally is what lets a trace show the step order on `Plus[a, Plus[b, a]]`,
which flattens to an already sorted list. Each entry carries its evaluation depth, so subterm
evaluations nest.

**The fixed point is fuelled.** `fixpoint` opens its own `WithFuel` (§4.3), spends one iteration per
round, and on exhaustion emits `$IterationLimit::itlim` and returns the expression in `Hold` — the
language's behaviour. Non-termination is a user error, so it gets a message, not an exception.

**Re-evaluation cost.** Read literally, "start over" re-evaluates already-settled subterms on every
round, walking whole subtrees. WL avoids this by marking expressions evaluated against a global
definitions epoch. Stage 1 ships the literal version; the marker is D14.

**One round is skipped, because it cannot change anything.** A round reports whether its result is
already a fixed point. It is one in two cases. If no rule fired, steps 2–9 only evaluated the parts
and rearranged them, and another round would try the same rules on the same expression, unless
step 5 moved a held argument into an unheld position. A `Sequence` spliced under `HoldFirst` or
`HoldRest` shifts positions, and the next round evaluates what now sits unheld: WL answers
`f[1+1, 4, 6]` for `f[Sequence[1+1, 2+2], 3+3]` with `HoldFirst`
(`wolfram/HoldFirst/PropertiesAndRelations/5`, regression case 0036). If a user
rule fired, its rung evaluated the right-hand side to a fixed point itself. A built-in's result, an
own value, a threaded list and `Indeterminate` still go round again. This is not D14's marker. It
was forced by a visible bug, not by cost. An unevaluated subterm that emits a message, such as
`Part[{1, 2}, 3]`, emitted it again every time a sibling's evaluation changed the parent. The 1a
end-to-end workload showed `Part::partw` twice, and regression case 0013 pins it.
**The fix is partial.** A built-in's result still goes round again, and so does any subterm left
unevaluated beside it: `Plus[Part[{1, 2}, 3], x, x]` collects `x + x` into `2 x`, and the next
round emits `Part::partw` a second time, where WL emits it once. Closing that gap means knowing
which subterms are settled, which is a marker, so it waits on D14.

### 4.5 Pattern matching

The hard engineering, and the part with no off-the-shelf Haskell answer.

#### 4.5.1 The pattern language

Patterns are `Expr`s, as in WL — `Blank[]` is a symbol applied to nothing — with a view type for the
matcher:

```haskell
-- | Cassini.Pattern
data PatternView
  = PBlank      !(Maybe Expr)                 -- ^ _h
  | PBlankSeq   !(Maybe Expr)                 -- ^ __h  (one or more)
  | PBlankNull  !(Maybe Expr)                 -- ^ ___h (zero or more)
  | PNamed      !Symbol !PatternView          -- ^ x:patt, x_
  | PCondition  !PatternView !Expr            -- ^ patt /; test
  | PTest       !PatternView !Expr            -- ^ patt ? f
  | PAlternative ![PatternView]               -- ^ p | q
  | PRepeated   !PatternView !(Int, Maybe Int)
  | POptional   !PatternView !(Maybe Expr)
  | PLiteral    !Expr
  | PCompound   !PatternView !(Vector PatternView)
  | PExcept     !PatternView !(Maybe PatternView)  -- ^ Except[c], Except[c, p]
  | PHold       !PatternView                      -- ^ HoldPattern[p]
  | PVerbatim   !Expr                             -- ^ Verbatim[e]: e literally, blanks too

viewPattern :: Expr -> PatternView
```

`Subst` is a `Map Symbol Binding`, where a binding is one expression or a sequence, because
sequence variables bind runs of arguments.

A blank's head constraint is an `Expr`, not a `Symbol`. `_h` compares `h` with the subject's
`Head`, and a head can be compound (`_f[x]`).

`HoldPattern[p]` matches as `p` does; its point is evaluation, not matching — `HoldPattern` has
`HoldAll`, so a rule's left side keeps the structure the user wrote ("you need to wrap HoldPattern
around r[x_] to prevent it from being evaluated",
`references/papers/wolfram-language/wolfram_ref_evaluation_of_expressions.html`). Rule tables need
it as soon as a left-hand side would evaluate, so it is Stage 1. `Except[c, p]` "represents any
expression that matches p but not c", with `Except[c]` meaning `Except[c, _]`; `Verbatim[e]`
requires "that expr be matched exactly as it appears, with no substitutions for blanks", and
"does not maintain expr in an unevaluated form" — so, unlike `HoldPattern`, it has no hold
attribute (`wolfram_ref_except.html`, `wolfram_ref_verbatim.html`).

**The sequence objects, as built at 1b.** Each element of a compound pattern's argument list takes
a run of the subject's arguments, and `argRange` says how long: a blank one, `__` one or more,
`___` any, `Repeated[p, spec]` by its spec, and `Optional` none or what its pattern takes. The spec
forms are `n` (at most `n`), `{n}` (exactly) and `{m, n}`, with `n` possibly `Infinity`. Under a
`Flat` head a blank takes one or more too, and a run of more than one binds the head over the run:
with `f` `Flat`, `f[x_, c]` matches `f[a, b, c]` with `x = f[a, b]`. A run of exactly one is tried
as `f[a]` first and then `a`, or as `a` only if the head also has `OneIdentity`
(`wolfram/OneIdentity/PropertiesAndRelations/2`, `wolfram/Flat/PropertiesAndRelations/5`). That is
all `OneIdentity` does to a run. Its other use is the fallback for `Optional`: a compound pattern
whose head has `OneIdentity`, and all of whose arguments but one are `Optional`, matches a subject
that is not an application of that head, as its one required argument does
(`MatchQ[x, n_. x_]`; `wolfram/OneIdentity/BasicExamples/1`).

`Optional[p, d]` takes `d` when no argument is left for it; `Optional[p]` takes the head's built-in
default, which exists only for `Plus` (0), `Times` (1) and `Power`'s exponent (1). User defaults
(`Default[f] = v`) are not implemented. An absent `Optional` binds its name to the default without
matching the default against the pattern, so `t[x_, type:("I" | "II"):"none"]` matches `t[1]`
(`wolfram/Optional/Scope/3`). `Longest` and `Shortest` are not implemented.

#### 4.5.2 The matcher monad, and why nondeterminism cannot be an effect

**No `effectful` handler can enumerate matches.** `Eff es` is `Env es -> IO a`, so a handler cannot
suspend the rest of the computation and resume it more than once. `effectful`'s README says so
("Any downsides?"), names a branch-collecting `NonDet` as the casualty, and points to libraries such
as `conduit` and `list-t` used alongside `Eff`. `Effectful.NonDet` is accordingly `Maybe`-shaped
(left-catch: `a :<|>: b` runs `b` only if `a` calls `Empty`), but `ReplaceList`, `//.`, `Cases` and
Krebber's algorithm need *every* match.

So nondeterminism is a transformer over `Eff` — `Eff`, not `Identity`, because `/;` evaluates its
test under the current substitution (via `evaluate`, §4.3) and `?f` applies a function.

**`MatchT` is a newtype, not a synonym**, so that `logict` is not in scope in all four matchers; the
export list and §2.6's rule 6 make the containment a property of the module graph:

```haskell
-- | Cassini.Pattern.Match
newtype MatchT es a = MatchT (LogicT (Eff es) a)
  deriving newtype (Functor, Applicative, Monad, Alternative, MonadPlus)

-- The three functions the rest of the matcher may know about.
liftMatch    :: Eff es a -> MatchT es a          -- MatchT . lift; the kernel call
observeFirst :: MatchT es a -> Eff es (Maybe a)  -- observeManyT 1, lazily
observeAll   :: MatchT es a -> Eff es [a]        -- observeAllT

match    :: (Kernel :> es) => PatternView -> Expr -> Subst -> MatchT es Subst

matchOne :: (Kernel :> es) => Expr -> Expr -> Eff es (Maybe Subst)
matchOne p s = observeFirst (match (viewPattern p) s mempty)

matchAll :: (Kernel :> es) => Expr -> Expr -> Eff es [Subst]
matchAll p s = observeAll (match (viewPattern p) s mempty)
```

`deriving newtype` needs no pragma: `GeneralisedNewtypeDeriving` is in GHC2021 and
`DerivingStrategies` in GHC2024.

**The matchers are written by open recursion, so none of them imports `MatchT`.**
`Cassini.Pattern` defines a record of what a matcher needs from its monad:

```haskell
data MatchOps m = MatchOps
  { recur       :: PatternView -> Expr -> Subst -> m Subst  -- ^ hand a subpattern back
  , evalM       :: Expr -> m Expr                           -- ^ side conditions
  , matchesM    :: PatternView -> Expr -> Subst -> m Bool   -- ^ for Except; commits to nothing
  , attributesM :: Expr -> m AttributeSet                   -- ^ the subject head's (1b)
  }

matchSyntactic :: (MonadPlus m) => MatchOps m -> PatternView -> Expr -> Subst -> m Subst
```

`match` in `Cassini.Pattern.Match` ties the knot: `match = matchSyntactic ops`, with
`recur = match`. Two other designs were rejected. If the matchers imported `MatchT`, then `match`
dispatching to them would be an import cycle. A boot file for the cycle would need to name
`LogicT` outside the one module rule 6 allows. The open recursion also makes containment stronger
than the newtype alone: no matcher can name `logict`'s types, because no matcher sees the monad.
1b's `Sequence` and `Commutative` take the same record, and `match` dispatches among them: a
compound pattern's head is matched first, then its arguments go to `Commutative` if the subject's
head is `Orderless`, to `Sequence` if it is `Flat` or any argument pattern takes a run, and
position by position otherwise. **`attributesM` was added at 1b** because that dispatch, and
`Flat`'s runs, depend on the subject head's attributes, which only the kernel knows.

**Rule application is the matcher's too.** `matchRule lhs body e` is a rule's instantiated
right-hand side for each match under which it applies, `lhs :> rhs /; test` trying the next match
where the test fails. It moved from `Cassini.Eval` at 1b so that the `Replace` family uses the
same code as the rule tables. `matchRuleOrRun` adds `Flat`'s runs (§4.5.3). `matchWith` takes a
`MatchConfig`, whose one knob turns off §4.5.4's steps 1–2 for §8.3's measurement; evaluation never
sets it.

**A sequence binding splices where it is substituted.** `applySubst` puts a `__` variable's run
into the argument list it lands in, not `Sequence[…]` for evaluation to splice later, and keeps
`Sequence[…]` only where the variable is the whole replacement, as WL does
(`mathematica.stackexchange.com/q/1929` and its answer a/1933, with WL's outputs). Until 1b's
end-to-end workload found it, `ReplaceRepeated`, which does not evaluate between rounds, stopped
matching after one round (regression case 0049).

**Those three functions and five instances are the whole surface a replacement backend must
reproduce** (D11, §9.2). Laziness is part of it: `matchOne` stops at the first success rather than
computing every match, and matches are exponential in number in general.

**All matcher state lives in the `Subst` threaded through `match`, never in an effect.** A failed
branch is abandoned by dropping a value, so nothing is rolled back and `effectful`'s `OnEmptyPolicy`
question never arises. The guarantee covers the matcher, not side conditions:
`MatchQ[3, _?((z = 5; IntegerQ[#]) &)]` writes `z` on a branch that may fail, and the write stays, as
in WL. So §7.3's "matching leaves `KernelState` unchanged" law is stated for side-condition-free
patterns, which is all `genPattern` builds.

#### 4.5.3 Staging

Four matchers, one interface, added in order:

1. **`Cassini.Pattern.Syntactic`** — structural, no attributes: blanks, names, conditions,
   alternatives, literals. Every later matcher calls back into it.
2. **`Cassini.Pattern.Sequence`** — `BlankSequence`/`BlankNullSequence` over a flat argument list:
   distributing *n* arguments among *m* sequence variables, over `Vector` slices so a candidate
   distribution copies nothing.
3. **`Cassini.Pattern.Commutative`** — `Orderless` heads (§4.5.4).
4. **`Cassini.Pattern.Net`** — many-to-one discrimination net, built only if milestone 1b's
   measured crossover says so (§4.5.5, §10).

**Order, as built at 1b.** Matches are enumerated in WL's order, because `Replace` takes the first
and `ReplaceList` shows them all. In an argument list, earlier patterns take shorter runs first,
except `Optional`, which takes its argument when there is one. Under `Orderless`, a variable takes
subjects in subject order, and a run takes sub-multisets by size and then lexicographically by
position, each in subject order. Both orders are WL's: `wolfram/Orderless/PossibleIssues/1`,
`wolfram/Flat/PossibleIssues/1`, and `ReplaceList[Hold[b + a], Hold[x___ + y___] -> {{x}, {y}}]`
quoted with WL's output in `mathematica.stackexchange.com/q/187537`.

**`Flat` heads' rules apply to runs.** With `f` `Flat`, `f[a, b, c, d, e] /. f[b, c, d] -> x` is
`f[a, x, e]`, and with `Orderless` too the run may be any sub-multiset (`wolfram/Flat/Scope/2`,
`/3`). This is rule application, not matching: `MatchQ` and `Replace` see the whole expression
(`wolfram/Flat/PossibleIssues/4`). `matchRuleOrRun` matches `f[ps] -> r` as
`f[pre___, ps, post___] -> f[pre, r, post]` after the whole has failed (`f[ps, rest___]` under
`Orderless`), with variables in a private context. `ReplaceAll`, `ReplaceRepeated` and the
evaluator's rule tables use it. For definitions the corpus is silent, and Mathics3 applies them to
a leading run only. Runs at any position were chosen to agree with `ReplaceAll`.

#### 4.5.4 Commutative matching: the five phases

Trying all *n!* permutations is correct and unusable. **Transcribed** from the ordering in
`references/papers/pattern-matching/krebber2017_ac_matching_thesis.pdf` §3.3.1, which does cheap
submatches first so expensive ones face a smaller search space. Given multisets `P` of pattern
arguments and `S` of subject arguments:

1. **Constant patterns** (ground terms). If `P ∩ G` is not a sub-multiset of `S`, fail; otherwise
   remove the matched pairs from both. Cheap, and prunes hard.
2. **Already-bound variables.** For each `x` in the substitution, its binding repeated once per
   occurrence in `P` must be contained in `S`; remove it or fail.
3. **Non-variable patterns.** Group patterns and subjects by head — only equal heads can match —
   and chain the submatches in `MatchT`, since patterns sharing a variable are not independent.
   Then **repeat phase 2**, because new bindings exist.
4. **Regular variables.**
5. **Sequence variables** — the most expensive, facing the smallest remaining problem.

Phases 1–2 are what make this tractable in practice, and the ones most tempting to skip in a first
version. They are not optional.

**Every phase stays in `MatchT`; none may call `matchOne`**, which commits to a first submatch and
leaves later phases nothing to backtrack into. With `P = {g[x_], x_, y_}` against
`S = {g[1], g[2], 2}`, phase 3 via `matchOne` binds `x = 1` (the first `g` in canonical order), the
repeated phase 2 finds no `1` among `{g[2], 2}`, and the match fails — although `x = 2, y = g[1]`
matches.

**Equal subjects are one mapping.** Of several equal subjects only the first is tried for a
pattern, and a run is chosen by how many of each value it takes, so `h[a, a]` against `h[x_, y_]`
is one match, not two. This is Krebber's algorithm (§3.3: brute force "will result in enumerating
equivalent matches multiple times"; §3.3.2 enumerates distributions "without duplicate results"),
and his examples are 1b's criterion. WL's answer for equal subjects is documented neither in the
corpus nor on Stack Exchange, and Mathics3 repeats them, so the oracle lists it.

Complexity: general AC matching is NP-complete, and linear AC matching (no repeated variable) is
polynomial (`references/papers/pattern-matching/benanav1987_complexity_of_matching_problems.pdf`).
The practical general algorithm, a hierarchy of bipartite matching problems, is
`references/papers/pattern-matching/eker1995_associative_commutative_matching.pdf`; phase 3's
head-grouping is its cheap approximation, and the full construction is where phase 3 goes when it
becomes the bottleneck.

#### 4.5.5 The discrimination net, and when to build it

Not now. `Cassini.Pattern.Net` exists from the start as an interface — a `RuleIndex` that
`Cassini.Rules` consults for *candidate* rules, whose first implementation returns all of them — so
that a net later is a new module rather than a refactor. It only retrieves candidates; the matcher
confirms them in `Cassini.Eval`. It must not import `Cassini.Pattern.Match`, or
`Rules → Net → Match → Eval.Kernel → Rules` is a cycle.

The trigger is measured (§8.3), and the measurement answers the question
`references/papers/pattern-matching/krebber2017_ac_matching_thesis.pdf` ch. 4–5 poses: **the
break-even is in the number of subjects matched, not the size of the pattern set**, because the net's
construction cost must be amortized. A large rule table alone is not the signal.

**Measured at 1b (2026-10-10; GHC 9.12.4, hash interning, one developer machine), and built.** The
prototype was the cheapest index that discriminates at all: each rule keyed on the head of its
left-hand side's first argument, with rules whose first argument is a blank, a sequence, an
alternative or a condition kept as wildcards, and candidates merged back into table order. Against
fifty rules `f[gi[x_], y_]` for one head, it took 2.0 µs and 8.6 KB per subject, where trying the
rules in order took 38 µs and 122 KB. The ratio held from 1 subject to 10000. Building it costs less
than one failed match, so **there is no break-even to wait for: it crosses over below one
subject**, which is below any volume the evaluator generates. So it is built, as the `RuleIndex`.
`Cassini.Rules` keeps one, lazily, on every table, and consults it for down-values only, and not
when the symbol is `Orderless` or `Flat`, where any argument may come first. Up-values are keyed
by some argument, not the head, so they need a different key. A property checks that the
candidates are a superset of the matching rules, in table order (§7.3).

This is not Krebber's many-to-one net, which also shares the work of matching among the
candidates. That remains the next step if a profile shows matching against large rule tables
dominating. Tables are per symbol, so it needs one symbol with many rules, such as §6.2's tier-1
integration rules.

### 4.6 Automatic simplification

The "boring" part that is the hard part — failure mode (b) in `notes/cas-haskell.md`.
`Cassini.Simplify.Automatic` implements Cohen's algorithm
(`references/papers/textbooks/cohen2003_*.pdf` §3.2), a procedure tree rather than one function:

```haskell
-- | Cassini.Simplify.Automatic
simplify :: Expr -> Either Undefined Expr   -- ^ Cohen's Automatic_simplify (recursive)

-- the subordinate operators, each separately tested
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

-- | Why the answer is undefined, so the builtin can choose the result and message.
data Undefined
  = DivisionByZero     -- ^ 0^w, w < 0
  | ZeroToZero
  | Pole               -- ^ Tan[π/2], Csc[0], … (§4.11)
  | LogOfZero          -- ^ Log[0] (§4.11)
  | ZeroDenominator    -- ^ a denominator contracted to 0, numerator not (§4.12)
  | ZeroOverZero       -- ^ numerator and denominator both contracted to 0 (§4.12)
```

Signature notes:

- `simplifyPower` is binary, as `Power` is; only `simplifyFunction` is variadic.
- The `*Rec` operators are the merge steps, where like terms are collected by calling
  `simplifyPower` and `simplifySum` — which can answer `Undefined`, so they return `Either`.
- `simplifyRNE` has one failure, division by zero, so it uses `Maybe`; callers map `Nothing` to
  `Left DivisionByZero`.
- `Undefined` carries its cause because the builtin maps it to different results: `1/0` is
  `ComplexInfinity` with `Power::infy`, `0^0` is `Indeterminate` with `Power::indet` (§4.7). The
  constructor list grows with the operators; the last four belong to §4.11–§4.12.

**The normal form is a specification.** Cohen calls it an ASAE, and `isASAE :: Expr -> Bool`
implements the definition directly. It is exported, not test-only: it is the postcondition the
property tests assert. **Transcribed** from `references/papers/textbooks/cohen2003_*.pdf` §3.1,
Definition 3.21:

| Rule | An ASAE is |
| :--- | :--- |
| ASAE-1 | an integer |
| ASAE-2 | a fraction in standard form |
| ASAE-3 | a symbol other than `Undefined` |
| ASAE-4 | a product of **two or more** operands such that: (1) each is an ASAE and is an integer other than 0 or 1, a fraction, a symbol, sum, power, factorial or function — **not a product**; (2) at most one is a constant; (3) no two have the same base; (4) they are in ◁ order |
| ASAE-5 | a sum of **two or more** operands such that: (1) each is an ASAE and is an integer other than 0, a fraction, a symbol, product, power, factorial or function — **not a sum**; (2) at most one is a constant; (3) no two have the same term; (4) they are in ◁ order |
| ASAE-6 | a power `v^w` such that: (1) `v` and `w` are ASAEs; (2) `w` is not 0 or 1; (3) if `w` is an integer, `v` is a symbol, sum, factorial or function; (4) if `w` is not an integer, `v` is not 0 or 1 |
| ASAE-7 | a factorial whose operand is any ASAE **except a non-negative integer** — so `(−3)!` is one and `3!` is not |
| ASAE-8 | a function with **one or more** operands, each an ASAE |

Here *base*/*exponent* read a non-power `u` as `u^1`, and *term* reads a product's non-constant part
(Cohen's `base`, `exponent`, `term` operators, same section). So `x^1`, `2^3`, `(x^2)^3`, `(x·y)^2`
and `1·x` are **not** ASAEs, while `(x·y)^(1/2)` and `(x^(1/2))^(1/2)` are.

**Two contracts the source states, which become two property tests:**

- For a basic algebraic expression `u`, `simplify u` is an ASAE or `Undefined`.
- **For an ASAE `u`, `simplify u` returns `u`.** Stronger than `simplify . simplify ≡ simplify`,
  because it also asserts that `isASAE` and `simplify` agree about what "simplified" means.

**Two departures from the source, both found when the code was written:**

- **SPOW-2 is restricted to numeric exponents.** Cohen makes `0^w` `Undefined` for every `w` that
  is not a positive number, so `0^x` would be `Undefined`. WL leaves `0^x` alone, and a symbolic
  exponent is not known to be non-positive. So `simplifyPower` decides `0^w` only for a numeric `w`.
  `isASAE` admits `0^w` for a non-numeric `w`, against ASAE-6-4, so that both contracts still hold
  of the pair. A property test found the disagreement.
- **MPRD-3-2 can leave two constants.** It adjoins a merged factor where the merge happened. Two
  radicals of one base can merge to a number behind an existing coefficient, as in
  `3·2^(1/2)·2^(1/2)`, whose merge gives `[3, 2]` against ASAE-4-2. `simplifyProduct` multiplies
  the constants of a merged list into one leading constant. Before §4.15's radicals this is rare,
  because only a product of radicals with one base reaches it.

**And one divergence from WL, kept because it is Cohen's:** a number does not distribute over a
sum (`2·(a + b)` stays). WL's normal form distributes, and the corpus shows it. D29.

`base` and `exponent` are exported as `powerBase` and `powerExponent`, and `const` as
`constPart`, because the prelude has an `exponent` and `const`.

**Where this attaches to the evaluator.** The built-in downvalues for `Plus`, `Times` and `Power`
(step 13) call `simplifySum`, `simplifyProduct` and `simplifyPower` on their arguments — **not** the
recursive `simplify`. By step 13 the arguments have already been evaluated, and so simplified, by
step 3; calling `simplify` would re-traverse every subtree on every round. The recursive `simplify`
is for the Haskell API and the property tests. From the evaluator's side this is a rule like any
other; from its own side, a total function with a normal form — §1.3 made concrete. `Power`'s
downvalue also tries `simplifyExpPower` on the result, and the elementary heads attach the same way
(§4.11); `Simplify.Automatic` itself stays exactly Cohen's.

### 4.7 Failure, messages, and `Undefined`

**The evaluator never throws on user error.** A malformed expression evaluates to itself and emits
a message: `Part[{1,2},5]` returns `Part[{1,2},5]` and emits `Part::partw`. In a rewriting system
"no rule applied" and "the input was wrong" are the same situation, and there is no stack to unwind
to.

```haskell
-- | Cassini.Eval.Message
data Message = Message { msgSymbol :: !Symbol, msgTag :: !MessageTag, msgArgs :: ![Expr] }
```

Messages accumulate in `KernelState` and are drained and formatted by the REPL (L5; formatting needs
the pretty-printer). The two limits are not errors either: both return `Hold` with a message (§4.3).
`Error Unwind` (§4.13) is reserved for control transfer — `Throw`, `Break`, `Continue`, `Return` — and for
what genuinely stops evaluation: `Abort[]` and interrupts.

Cohen's `Undefined` and the language's result-plus-message meet at one point: `simplify` returns
`Either Undefined Expr`, and `Cassini.Builtins.Arithmetic` turns a `Left` into `ComplexInfinity` or
`Indeterminate` plus the matching message, according to its cause (§4.6).
`Cassini.Builtins.Elementary` and `.Simplify` do the same for the causes they add: `Pole` is
`ComplexInfinity` and `LogOfZero` is `DirectedInfinity[-1]`, both silent as in WL, and
`ZeroDenominator` and `ZeroOverZero` are mapped as `1/0` and `0/0` are: `ComplexInfinity` with
`Power::infy`, and `Indeterminate` with `Power::indet`. That is what WL gives for the same inputs,
because its own evaluation meets the `1/0` or `0/0`, and it needs no new message name. Keeping `simplify` in
`Either` rather than in the effect is what lets it be tested as a pure function.

### 4.8 Zero testing is not available here

Stated in Stage 1 because it bounds Stage 1: **there is no general algorithm for deciding whether a
symbolic expression is zero** (`references/papers/foundations/richardson1968_*.pdf`). Automatic
simplification must never *need* a zero test it cannot perform. Cohen's algorithm is written to that
constraint — it decides zero only for rational numbers and structurally identical operands — and the
design's job is not to add a rule that quietly requires more. Until milestone 2a (§5.6, §10),
`Cassini.Zero` exports only the rational case.

### 4.9 Differentiation

`D` is easy; the design point is how it is built. **`D` is a rule table, not a Haskell `case` on
`Expr` shape**: the sum, product and chain rules are built-in downvalues on `D`, derivatives of
known functions are subvalues on `Derivative` (`Derivative[1][Sin]` is `Cos[#]&`; §4.11 has the
table), and a user's own
function extends it by definition. That exercises the whole engine — patterns, attributes, the
subvalue rung, upvalues — while the engine is still small enough to debug. A Haskell `case` would
work sooner and test nothing.

Scope: chain and product rules, `Derivative[n]` for repeated differentiation, and user-extensible
derivatives. The acceptance test is in §10.

### 4.10 Surface syntax and the REPL

Needed beyond ergonomics for the regression corpus (§7.4) and for golden files a person can read.

`Cassini.Syntax.Lexer` and `.Parser` use `megaparsec`: a hand-rolled parser is not where this
project's difficulty should go, and its error messages are worth the dependency. The precedence
table is data, in one place, driving both the parser and `Cassini.Syntax.Pretty`, so the two cannot
disagree about how `a /. b -> c` parses; a round-trip property (§7.3) enforces it.

Stage 1 subset: numbers, strings, symbols with contexts, `f[...]`, `{...}`, `a[[i]]`, arithmetic and
comparison operators, `=`/`:=`/`^=`/`^:=`, `->`/`:>`, `/.`/`//.`, `/;`, `?`, `|`,
`_`/`__`/`___` with names and head constraints, `&`/`#`, `@`/`//`/`~f~`, and `;`. Deferred: `Span`,
string patterns, boxes, anything notebook-shaped.

`Cassini.Syntax.FullForm` is the canonical machine-readable form, separate from `.Pretty`. **All
golden files are FullForm**, because pretty output changes whenever precedence handling improves,
and that must not invalidate hundreds of regression cases.

`Cassini.REPL` fills the `cassini` executable: `In[n]`/`Out[n]`, `%`, message display, `Trace`,
timing, and a `--script` mode that reads FullForm and writes FullForm. The script mode is a library
function in `cassini-core`, `Cassini.Script.runScript :: Text -> IO Text`, which the golden tests
call directly; the interactive loop is `cassini-repl`'s (§2.1).

### 4.11 Elementary functions

| Group | Heads | Automatic rules (this section) | Transformations (§4.12) |
| :--- | :--- | :--- | :--- |
| Circular | `Sin`, `Cos`, `Tan`, `Cot`, `Sec`, `Csc` | special values, parity, periodicity | expansion, contraction, `Simplify` |
| Hyperbolic | `Sinh`, `Cosh`, `Tanh`, `Coth`, `Sech`, `Csch` | values at 0, parity | expansion, contraction, `Simplify` |
| Inverse circular | `ArcSin`, `ArcCos`, `ArcTan`, `ArcCot`, `ArcSec`, `ArcCsc` | special values, parity, `Sin[ArcSin[x]] → x` | none |
| Exponential | `Exp`, `Log` | `Exp[u] → E^u`; values of `Log`; `E^(c·Log[z]) → z^c` | none: contraction is automatic |

Each head is `Listable`, `NumericFunction` and `Protected`. `Pi` and `E` are `Constant` symbols
with no value; nothing here computes a digit of either (§0.2).

**The exponential is a power.** `Exp[u]` evaluates to `Power[E, u]`, as in WL, and two consequences
follow, both wanted. Cohen's product merge already collects `E^x·E^y` to `E^(x+y)` (same base,
SPRDREC), and SINTPOW folds `(E^x)^n` to `E^(n·x)` for integer `n` only — so the two
contraction rules (`references/papers/textbooks/cohen2002_*.pdf` §7.2, (7.27)–(7.28)) are applied
during automatic simplification, and only where they are valid over ℂ. That gives properties 1 and
2 of Definition 7.8, not property 3: automatic simplification does not expand, so `E^x·(E^x + E^y)`
stays, and reaching `E^(2x) + E^(x+y)` takes an explicit `Expand`. An exponential-expanded form
(Definition 7.1) cannot survive evaluation, because `E^x·E^y` re-merges; so `Expand_exp` and
`Contract_exp` (Figs. 7.2, 7.4, 7.5) are not implemented, and there is no `ExpExpand` — which is
also WL's position. What `Contract_exp` would add beyond `Expand`, rationalizing and contracting
numerator and denominator, is Cohen's `Simplify_exp`, which D17 names as a second strategy.

**The automatic rules are not in `Cassini.Simplify.Automatic`.** Cohen's `Simplify_function` is
the identity apart from propagating `Undefined` — "there are no function transformations in our
algorithm" (`references/papers/textbooks/cohen2003_*.pdf` §3.2) — and §4.6's contract depends on
that: `Sin[0]` is an ASAE, so `simplify` must return it unchanged. The elementary rules are a second
pure layer above Cohen's:

```haskell
-- | Cassini.Simplify.Elementary
--
-- Source: @references/papers/textbooks/cohen2002_*.pdf@ §7.2 ("Automatic
-- Simplification of Trigonometric Functions", transformations 1–5 and Fig. 7.9).

-- | One elementary-function node whose arguments are already simplified.
-- 'Nothing': no rule applies, and the node is in normal form.
simplifyElementary :: Symbol -> Vector Expr -> Maybe (Either Undefined Expr)

-- | @E^(c·Log[z]) → z^c@, tried on the result of 'simplifyPower' (base, exponent).
simplifyExpPower   :: Expr -> Expr -> Maybe (Either Undefined Expr)

-- | 'simplify' with the two above, §4.15's 'Cassini.Simplify.Numeric' passes
-- (radicals, coefficient merge, infinities and their guards) and §4.4's
-- 'Indeterminate' rule, applied at every node, bottom-up.
simplifyE          :: Expr -> Either Undefined Expr

-- | An ASAE on which no elementary or §4.15 rule fires; or such a product with
-- two unmerged factors on one infinity-bearing base (§4.15's one undecided case).
isElementaryNormal :: Expr -> Bool
```

It attaches to the evaluator as §4.6 does: each head's built-in downvalue (step 13) calls
`simplifyElementary`, and `Power`'s calls `simplifyExpPower` after `simplifyPower`. `Plus`,
`Times` and `Power` also run §4.15's passes, and `simplifyE` runs the same ones at the same nodes.
Without them, Cohen's sum merge inside a §4.12 algorithm would build `2·2^(-1/2)`, which the
evaluator rewrites to `2^(1/2)`, and like terms spelled the two ways would not cancel. The evaluator
and `simplifyE` therefore agree on every built-in, and §4.12's algorithms use `simplifyE` wherever
Cohen's procedures assume an expression is automatically simplified on construction. User rules on
`Sin` are not consulted inside those algorithms; they see the result, which the builtin returns to
the fixed point (§4.4).

**The rules** follow Cohen's list of automatic trigonometric transformations
(`references/papers/textbooks/cohen2002_*.pdf` §7.2). Its Fig. 7.9 shows Maple, Mathematica and
MuPAD disagreeing, so each rule names the column it reproduces, and those rows are unit tests
(§7.2):

- **Special values.** An argument `r·π`, `r` rational, is reduced by the head's period and
  symmetries to `[0, π/2]` — Cohen's item 3, the MPL column: `Sin[15π/16] → Sin[π/16]`. For
  denominators 1, 2, 3, 4 and 6 a table then gives the value. Outputs are ASAEs, one spelling per
  value: `Sin[π/3] → (1/2)·3^(1/2)`, `Sin[π/4] → 2^(-1/2)`, `Tan[π/6] → 3^(-1/2)`. Poles
  (`Tan[π/2]`, `Cot[0]`, `Sec[π/2]`, `Csc[0]`) are `Left Pole`. The hyperbolic heads have only
  their values at 0, with `Coth[0]` and `Csch[0]` poles. WL also evaluates denominators 5, 8, 10
  and 12 (`Sin[π/12]`, `Cos[π/5]`). They are not in the table, and §7.5 lists this as a
  divergence, for two reasons. Some values are nested radicals (`Sin[π/8] = (2-2^(1/2))^(1/2)/2`,
  `Sin[π/5]`), which §4.15 does not normalize at all. Others are flat but outside §4.15's
  canonical class: `Sin[π/12] = (6^(1/2) - 2^(1/2))/4` has a radicand with two prime factors
  (D24), so the inverse tables could not rely on its spelling. `Cos[π/5] = (1 + 5^(1/2))/4` is
  flat and canonical, and could join the table; it is left out so that a denominator is in or
  out as a whole, not value by value.
- **Parity.** When the argument's **first operand in ◁ order has a negative coefficient**, odd
  heads (`Sin`, `Tan`, `Cot`, `Csc`, their hyperbolic counterparts, `ArcSin`, `ArcTan`, `ArcCot`,
  `ArcCsc`) pull the sign out and even ones (`Cos`, `Sec`, `Cosh`, `Sech`) drop it. This reproduces
  the Mathematica column: `Sin[-x] → -Sin[x]`, `Sin[x-1] → -Sin[1-x]`, and `Sin[1-x]` is left
  alone, since ◁ puts the constant first. `ArcCos` and `ArcSec` have no parity and are left alone.
- **Periodicity with a symbolic remainder.** In an argument `x + r·π`, the `r·π` term is removed
  only when `r` is a multiple of 1/2 (Cohen's item 4): `Sin[x + π/2] → Cos[x]`,
  `Cos[x + 2π] → Cos[x]`, `Tan[x + π] → Tan[x]`. Any other `r` is reduced modulo the head's
  period into a symmetric range: `(−1, 1)` for period 2π and `(−1/2, 1/2)` for period π
  (`Sin[x + 7π/3] → Sin[x + π/3]`). Each reduction is an identity, and the range is closed under
  negation, so parity cannot push `r` back out. `Sin[x + 2π/3]` is left alone, as in the
  Mathematica column; the MPL column's `Cos[x + π/6]` would be item 3 applied to sums, not adopted.
- **No function transformations** (Cohen's item 5). `Sin[x]/Cos[x]` stays; it does not become
  `Tan[x]` as in WL. That transformation is the inverse of `Trig_substitute`, so with it in
  automatic simplification `Simplify` could never see a `Tan` as a quotient. Cohen's footnote 9,
  on his description of Fig. 7.10, says his Mathematica implementation omits `Trig_substitute` for
  this reason, and his appraisal of `Simplify_trig` reports that it then fails Example 7.18's
  difference. A known divergence from WL, recorded as D16.
- **Inverses.** `Sin[ArcSin[x]] → x`, and likewise for the other five. The inverse tables are the
  forward tables read backwards onto the principal ranges, and they recognize an argument only in
  the spelling the forward table emits: `ArcSin[2^(-1/2)] → π/4`. Automatic simplification alone
  leaves `(1/2)·2^(1/2)` a different expression from `2^(-1/2)`; §4.15's radical normalization
  makes the two one spelling for prime radicands, and the tables rely on that and on nothing
  stronger, since pretending to a canonical form that does not exist is how a table becomes
  wrong. `ArcSin[Sin[x]] → x` is not a rule: it is false off the principal branch.
- **Exponential and logarithm.** `E^(c·Log[z]) → z^c` for numeric `c`: the principal `z^c` is
  *defined* as `E^(c·Log[z])`, so this is an identity. `Log[1] → 0`; `Log[E^r] → r` for rational
  `r`, with `Log[E] → 1` the case `r = 1`; `Log[0]` is `Left LogOfZero`. `Log[E^x]` for symbolic
  `x` is left alone.

**Every rule is an identity over ℂ.** The kernel works in ℂ, as WL does, so a transformation that
holds only for real arguments is applied neither automatically nor by any builtin in §4.12.
Excluded by this, each right for reals and wrong for some complex input: `Log[E^x] → x`; the log
expansions and contractions of Cohen's §7.1 and §7.2 exercises (`Log[a·b] → Log[a] + Log[b]` and
kin); `(E^x)^w → E^(w·x)` for non-integer `w`, where Cohen's footnote to (7.4) gives the
counterexample; and anything `PowerExpand`-shaped. Admitting them needs a way to say "`x` is real"
(D18). Everything in §4.12 — addition, multiple-angle and power-reduction formulas — is a
polynomial identity in `E^(iθ)` and qualifies.

**Termination.** Each rule produces a value, strictly removes the π term from an argument, moves
the π coefficient `r` into its reduced range (`[0, 1/2]` for a constant argument, the symmetric
range above otherwise), or makes the argument's leading coefficient non-negative. Periodicity can
hand parity a negative argument (`Sin[π - x] → -Sin[-x]`, then `Sin[x]`), so the measure is
lexicographic. First comes the number of π terms, which periodicity decreases and no rule
increases. Second is whether `r` is out of range, which the reductions clear and parity leaves
clear. Last is whether the leading coefficient is negative, which parity clears without touching
the first two. So `simplifyE` is total, and "no elementary rule fires on its own
output" is a property test (§7.3).

**Poles and `Log[0]`** are two more causes in §4.6's `Undefined`, `Pole` and `LogOfZero`; §4.7
says what each becomes.

**Derivatives** are `Derivative[1]` subvalues (§4.9), installed by `Cassini.Builtins.Elementary`
alongside each head's downvalues, so one module holds everything the system knows about a function:

| f | f′ | f | f′ | f | f′ |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Sin` | `Cos[#]&` | `Sinh` | `Cosh[#]&` | `ArcSin` | `1/Sqrt[1-#^2]&` |
| `Cos` | `-Sin[#]&` | `Cosh` | `Sinh[#]&` | `ArcCos` | `-1/Sqrt[1-#^2]&` |
| `Tan` | `Sec[#]^2&` | `Tanh` | `Sech[#]^2&` | `ArcTan` | `1/(1+#^2)&` |
| `Cot` | `-Csc[#]^2&` | `Coth` | `-Csch[#]^2&` | `ArcCot` | `-1/(1+#^2)&` |
| `Sec` | `Sec[#] Tan[#]&` | `Sech` | `-Sech[#] Tanh[#]&` | `ArcSec` | `1/(#^2 Sqrt[1-#^-2])&` |
| `Csc` | `-Cot[#] Csc[#]&` | `Csch` | `-Coth[#] Csch[#]&` | `ArcCsc` | `-1/(#^2 Sqrt[1-#^-2])&` |
| `Log` | `1/#&` | | | | |

`Exp` has no row. `D` of `E^u` is `Power`'s rule, `E^u·Log[E]·D[u]`, and is `E^u·D[u]` only because
`Log[E] → 1` fires — a dependency between two sections, stated so that a change to one does not
quietly break the other.

### 4.12 Trigonometric transformations and `Simplify`

Three builtins in `Cassini.Builtins.Simplify`, each a thin wrapper over one pure module:

| Builtin | Algorithm (`cohen2002_*.pdf`) | Output satisfies |
| :--- | :--- | :--- |
| `TrigExpand[e]` | `Expand_trig` (Fig. 7.3), then algebraic expansion | trig-expanded, below |
| `TrigReduce[e]` | `Contract_trig` (Figs. 7.6–7.8) | trig-contracted, below |
| `Simplify[e]` | `Simplify_trig` (Fig. 7.10) | numerator and denominator each trig-contracted |

```haskell
-- | Cassini.Simplify.Trig
--
-- Source: @references/papers/textbooks/cohen2002_*.pdf@ §7.1 (Expand_trig),
-- §7.2 (Contract_trig, Simplify_trig), §5.2 (Trig_substitute).
expandTrig       :: Expr -> Either Undefined Expr
contractTrig     :: Expr -> Either Undefined Expr
expandTrigRules  :: Expr -> Either Undefined (Expr, Expr)  -- (sin A, cos A), Fig. 7.3; exported for §8.4
trigSubstitute   :: Expr -> Expr     -- TRIGSUB-1..4 and their hyperbolic counterparts
simplifyTrig     :: Expr -> Either Undefined Expr
isTrigExpanded   :: Expr -> Bool
isTrigContracted :: Expr -> Bool
```

`Either`, because expansion or contraction can turn a denominator into 0
(`1/(Sin[2x] - 2 Sin[x] Cos[x])`), and Cohen's §7.1 Exercise 7 and §7.2 Exercise 8 have the
procedures return `Undefined` when it does; the builtins map it as §4.7 does. Every intermediate expression is built with
`simplifyE` (§4.11), which is how Example 7.17's `Cos[x + π/6]` expands into terms whose `Cos[π/6]`
becomes a number mid-algorithm.

**The normal forms, transcribed** from Definitions 7.4 and 7.11, each extended to the hyperbolic
pair as Cohen's §7.1 Exercise 9 and §7.2 Exercise 9 do:

| Form | Every … |
| :--- | :--- |
| trig-expanded (Def. 7.4, strengthened per §7.1 Exercise 8) | argument of a `Sin`, `Cos`, `Sinh` or `Cosh` is neither a sum nor a product with an integer operand; **and** every complete subexpression is in algebraic-expanded form |
| trig-contracted (Def. 7.11) | product has at most one circular operand (`Sin`, `Cos`) and at most one hyperbolic operand (`Sinh`, `Cosh`); power with a positive integer exponent has none of the four as its base; complete subexpression is in algebraic-expanded form |

Neither mentions `Tan` and the other seven: `TrigExpand` and `TrigReduce` apply `trigSubstitute`
first, so `TrigReduce[Tan[x]]` is `Sin[x]/Cos[x]`, and with no function transformations (§4.11) it
stays that way.

**The formulas Cohen leaves to exercises**, for `n` a positive integer. Negative `n` goes through
parity first (§7.1 Exercise 5). Each identity was checked numerically when this section was written,
and each is a unit test.

Addition, Cohen's (7.11)–(7.12), and the hyperbolic pair of §7.1 Exercise 9:

```
sin(θ+φ)  = sin θ cos φ + cos θ sin φ        sinh(θ+φ) = sinh θ cosh φ + cosh θ sinh φ
cos(θ+φ)  = cos θ cos φ − sin θ sin φ        cosh(θ+φ) = cosh θ cosh φ + sinh θ sinh φ
```

Multiple angle, Cohen's (7.20)–(7.21), and the hyperbolic pair from §7.1 Exercise 9's
`cosh(nθ) ± sinh(nθ) = (cosh θ ± sinh θ)ⁿ`:

```
cos(nθ)  = Σ_{j even} (−1)^(j/2)     C(n,j) cosⁿ⁻ʲθ sinʲθ
sin(nθ)  = Σ_{j odd}  (−1)^((j−1)/2) C(n,j) cosⁿ⁻ʲθ sinʲθ
cosh(nθ) = Σ_{j even}                C(n,j) coshⁿ⁻ʲθ sinhʲθ
sinh(nθ) = Σ_{j odd}                 C(n,j) coshⁿ⁻ʲθ sinhʲθ
```

Product to sum, Cohen's (7.30)–(7.32), and their hyperbolic counterparts:

```
sin θ sin φ = (cos(θ−φ) − cos(θ+φ))/2        sinh θ sinh φ = (cosh(θ+φ) − cosh(θ−φ))/2
cos θ cos φ = (cos(θ+φ) + cos(θ−φ))/2        cosh θ cosh φ = (cosh(θ+φ) + cosh(θ−φ))/2
sin θ cos φ = (sin(θ+φ) + sin(θ−φ))/2        sinh θ cosh φ = (sinh(θ+φ) + sinh(θ−φ))/2
```

Power reduction, sums over `j = 0 … n`. Cohen's (7.35)–(7.36) fold each sum at `n/2`, which gives
two cases per function; the unfolded form is one formula per parity, and §4.11's parity rule does
the folding on construction (`cos(−2θ) → cos(2θ)`, and the middle term's `cos(0) → 1`):

```
cosⁿθ  = 2⁻ⁿ Σ C(n,j) cos((n−2j)θ)
sinⁿθ  = (−1)^⌊n/2⌋ 2⁻ⁿ Σ (−1)ʲ C(n,j) cos((n−2j)θ)     n even
       = (−1)^⌊n/2⌋ 2⁻ⁿ Σ (−1)ʲ C(n,j) sin((n−2j)θ)     n odd
coshⁿθ = 2⁻ⁿ Σ C(n,j) cosh((n−2j)θ)
sinhⁿθ = 2⁻ⁿ Σ (−1)ʲ C(n,j) cosh((n−2j)θ)              n even
       = 2⁻ⁿ Σ (−1)ʲ C(n,j) sinh((n−2j)θ)              n odd
```

**Cohen's structure, kept:** `Expand_trig_rules` returns the pair `(sin A, cos A)`, as in
Fig. 7.3, and its hyperbolic twin returns `(sinh A, cosh A)`. Expanding a function of a sum of `n`
symbols then costs 2(n−1) rule applications instead of 2ⁿ⁻¹−1 (§7.1 Exercise 6); §8.4 gates it.
The contraction procedures use `Expand_main_op`, not a full `Algebraic_expand`, as Fig. 7.7 does,
to avoid the redundant recursion Cohen describes.

**The choice the hyperbolic extension forces, fixed here:** `Separate_sin_cos` (§4.2 Exercise 12)
splits a product's operands three ways, not two: circular factors, hyperbolic factors, the rest.
`Contract_trig_product` runs on each group separately, so nothing contracts `Sin[x] Sinh[y]`.

**`Simplify` is `Simplify_trig`, and it is not WL's `Simplify`.** Fig. 7.10: `trigSubstitute`,
`Rationalize_expression`, then expand and contract the numerator and denominator separately. A
denominator that contracts to 0 is `Left ZeroDenominator`, or `Left ZeroOverZero` if the
numerator contracted to 0 as well. Cohen's line 7 returns `Undefined` without looking at the
numerator, and the split is ours, so that §4.7 can map each as `1/0` and `0/0` are mapped. Cohen's appraisal is the specification of its limits, stated here
so that they are read as the contract and not reported as bugs. It proves identities well when asked
about a difference — Example 7.18's left side minus `Tan[4x]` gives 0 — but leaves a larger form
than necessary otherwise: the same left side alone is unchanged. And it cannot see that two
differently spelled arguments are equal, so `Sin[(x+1)/(x+2)]^2 + Cos[(1+1/x)/(1+2/x)]^2` is not 1.
WL's `Simplify` searches over transformations scored by a complexity measure; with one strategy
there is nothing to search. The name is bound anyway, because it is the one users type; D17 records
when that changes.

**The support it needs, and where it lives.** `Contract_trig` and `Simplify_trig` call
`Algebraic_expand`, `Expand_main_op`, `Rationalize_expression`, `Numerator` and `Denominator`
(`references/papers/textbooks/cohen2002_*.pdf` §6.4–6.5). They are pure procedures on ASAEs that
need no polynomial substrate, so they are Stage 1, in `Cassini.Simplify.Rational`; the `Expand`
builtin (§2.2) is `algebraicExpand`. They build every intermediate with `simplifyE`, not `simplify`,
which is why `.Rational` imports `.Elementary` (§2.6). `Contract_trig` expands through them
(`Expand_main_op`, Fig. 7.7 lines 1, 13 and 15), so with plain `simplify` an expansion of
`2·(2^(-1/2)·Cos[x] + …)` would build `2·2^(-1/2)·Cos[x]`, which never meets the evaluator's
`2^(1/2)·Cos[x]`, and a difference that is zero would not contract to 0. `Together` is not among them: it cancels common factors, which
needs §5.4's GCD.

**Exponential–trigonometric conversion is not here.** `TrigToExp` and `ExpToTrig` need `I` with
`I^2 → -1` and exact complex arithmetic, which `Number` does not have (§3.1); D19.

### 4.13 Pure functions, control flow and scoping

The language is more than algebra, and a missing control structure blocks the algebra: every
`Derivative` subvalue in §4.11 is a pure function, so `D`'s chain rule cannot produce an answer
until `Function` applies. `Cassini.Builtins.Control` owns this section.

**Sources.** `references/papers/wolfram-language/wolfram_ref_evaluation_of_expressions.html`
specifies `Function` with attributes (section "Attributes"), `If`/`Which`/`Switch`, `TrueQ` and
`&&` (section "Conditionals"), `Do`/`While`/`For`/`Nest`/`FixedPoint` and `Catch`/`Throw` ("Loops
and Control Structures"), and iterator evaluation ("Evaluation in Iteration Functions"). Scoping is
in `wolfram_ref_modularity_and_naming.html` — the chapter now holding "How Modules Work", "Blocks
and Local Values" and "Variables in Pure Functions and Rules" — and the exact rules are in the
reference pages' "Details": `wolfram_ref_module.html`, `_block.html`, `_with.html`,
`_function.html`, `_return.html`, `_throw.html`, `_catch.html` and `_break.html`, all in the same
directory. **The captured examples show inputs, not outputs** (the outputs are images), so a rule
below that rests only on what an example returns is marked as such.

**Pure functions.** `Function` has `HoldAll`. `Function[params, body][args]` and
`Function[body][args]` apply as a **built-in subvalue** on `Function` (step 13's `h[…][…]`), by
substituting into the held body: named parameters for `Function[{x, …}, …]` and for the
single-parameter `Function[x, …]`, and `#n`, `##n` and `#0` for slot form, which is also what
`Function[Null, body, attrs]` uses ("represents a function in which the parameters in body are given
using # etc.", `wolfram_ref_function.html`). In slot form, arguments beyond the highest slot are
ignored, per the same page. Two
points the evaluator must get right:

- **Attributes of a compound head.** The source sets up "pure functions which behave as if they
  carry attributes" with `Function[vars, body, {attr₁, …}]`, e.g. `Listable`. So wherever §4.4
  consults "the attributes of `h`" (steps 4–9), a head of the form `Function[_, _, attrs]` supplies
  `attrs`, which may be one attribute or a list (`wolfram_ref_function.html`). Every other
  compound head supplies none. §4.4's `headAttributes` is where this lives.
- **Substitution respects scoping.** Substituting into a body passes through nested `Function`,
  `Module`, `With` and rule-delayed right-hand sides, and a bound variable of the inner construct
  that would capture a free symbol of the substituted value is renamed (`y` → `y$`). This is
  `Cassini.Structure.substitute` extended by one scoping-aware case, not a second substitution
  function.

**Sequencing and conditionals.** `CompoundExpression` (`;`, `HoldAll`) evaluates its arguments in
order and returns the last. `If` (`HoldRest`) follows the source exactly: when the test is neither
`True` nor `False`, `If[test, t, f]` stays unevaluated and the four-argument `If[test, t, f, u]`
takes `u`. `Which` evaluates tests in turn; `Switch` matches its first argument against each form
with `matchOne` (§4.5.2). `If`, `Which` and `Switch` never treat an undecided test as `False`:
they stay unevaluated, or take `If`'s fourth argument. Constructs that must decide in order to
proceed treat anything but `True` as failure: `TrueQ` by definition (§4.14); `While` and `For`,
per the source ("As soon as the loop test fails to be True, While and For terminate",
`wolfram_ref_evaluation_of_expressions.html`, "Loops and Control Structures"); and the matcher's
`Condition` and `PatternTest` (§4.5), where only `True` admits a match.

**Scoping.**

- **`Module[{x, …}, body]`** renames each local to a fresh `x$n` and evaluates the renamed body —
  "Module creates a symbol with name xxx$nnn … The number nnn is the current value of
  $ModuleNumber", incremented "every time any module is used". Renaming skips occurrences that are
  "local variables in scoping constructs", and the new symbols carry `Temporary`.
  `n` is `$ModuleNumber`, a counter in `KernelState`, **not** the intern table's allocation
  counter (§3.2): under `runKernelPure` the names must be a function of the initial state, or the
  §7.3 determinism law fails and golden files record session history.
- **`With[{x = v, …}, body]`** substitutes the evaluated `v` into the held body before evaluating
  it — the same scoping-aware substitution as `Function`. `With[{x := v}, …]` "inserts the
  unevaluated form" of `v`, and `With[def₁, def₂, expr]` is `With[def₁, With[def₂, expr]]`
  (`wolfram_ref_with.html`).
- **`Block[{x, …}, body]`** is dynamic ("values assigned to x, y, … are cleared. When the execution
  of the block is finished, the original values of these symbols are restored"; initial values are
  evaluated before the clear): it saves each symbol's whole value record — its own, down, up and
  sub values (§4.2's four kinds) — clears it or sets the own-value, evaluates the body, and **restores on every exit**, including `Throw`, `Break` and `Abort[]`.
  Restoration uses the unwinding operations below; it is the one place state changes are undone.
  Clearing only own-values would be wrong: `Block[{f}, f[x_] := …; …]` must leave `f`'s old
  down-values in place afterwards, and the idiom `Block[{Print}, …]` works because the builtin's
  definitions are cleared too. The page says "Block affects only the values of symbols, not their
  names"; whether attributes are localized is not stated, and a regression case pins it.
- **Iterators** (`Table`, `Do`, `Sum`, `Product`) localize the iteration variable as `Block` does —
  the source: "the first step … is to make the value of i local. Next, the limit imax … is
  evaluated. The expression f is maintained in an unevaluated form, but is repeatedly evaluated".
  One parser for the iterator forms `{n}`, `{i, imax}`, `{i, imin, imax}`, `{i, imin, imax, di}` and
  `{i, list}`, shared by all four; `Sum` and `Product` fall back to §6.3 only when a bound is
  symbolic.
- **`Nest`, `NestList`, `Fold`, `FoldList`, `FixedPoint`** are ordinary downvalues over
  `evaluate`. `FixedPoint` compares with `SameQ` and is bounded by `$IterationLimit` (§4.3), so it
  cannot loop forever.

**Non-local exits need two operations on the `Kernel` effect** (§4.3). `Throw`, `Break`, `Continue`,
`Return` and `Abort[]` unwind to the nearest handler, and a handler must be able to observe an
unwind in order to restore state and rethrow:

```haskell
-- | Cassini.Eval.Kernel — added to 'Kernel'
  Unwind      :: Unwind -> Kernel m a                 -- ^ Throw, Break, Continue, Return, Abort[]
  CatchUnwind :: m a -> Kernel m (Either Unwind a)    -- ^ Catch, loops, Block's restore

data Unwind = UThrow !Expr !(Maybe Expr) !(Maybe Expr)  -- ^ value, tag, Throw's third argument
            | UBreak | UContinue
            | UReturn !Expr                                 -- ^ D23, answered below
            | UAbort !Abort
```

The interpreters discharge `Error Unwind` and return `Either Unwind a` (§4.3). `Catch` catches `UThrow`
(matching the tag against its form, re-evaluating the tag each time it is compared, per
`wolfram_ref_catch.html`; `Catch[expr, form, f]` returns `f[value, tag]`) and rethrows anything
else. The one-argument `Catch[expr]` catches only an untagged `Throw[value]`: "Throw[value, tag] is
caught only by Catch[expr, form], where tag matches form" (`wolfram_ref_throw.html`), so a tagged
throw passes it by; `Do`, `While`, `For` and `Until` catch `UBreak` and `UContinue` — the loops
`wolfram_ref_break.html` names ("Break[] exits the nearest enclosing Do, For, Until or While");
`Block` catches everything, restores, and rethrows. **Nothing handles `UAbort`.** Three things
observe it, each only to restore and rethrow: `Block`, the kernel's own depth and fuel bookkeeping
(below), and the top-level entry, which hands it on as `Left (UAbort _)`. So `Abort[]` still stops
evaluation (§4.7). `Break[]` makes its loop return `Null`. An uncaught `UThrow` reaching the top of
a REPL input becomes an unevaluated `Throw` with a message ("An error is generated and an
unevaluated Throw is returned"), or, for `Throw[value, tag, f]`, `f[value, tag]`; a stray `Break[]`
or `Continue[]` likewise. **"Unevaluated" is wrapped in `Hold`**: the result is
`Hold[Throw[value]]`, `Hold[Break[]]`, `Hold[Continue[]]`. A bare `Throw[value]` would be a trap
here, because evaluating it again — `%`, or `r = …; r` — raises `UThrow` again, far from where it
was thrown. `Hold` is what WL itself prints, from memory rather than the captures; a regression
case pins it against an oracle. The conversion is in `Cassini.Eval`'s top-level entry, which wraps
the input's evaluation in `CatchUnwind` and so has an `Expr` to build; the interpreter only
reports what escaped. The message tags are not in the captures; `Throw::nocatch` is from memory.
`KernelState` changes made before an unwind persist: "no matter the order of effects, state updates
made within the `catchError` block before the error happens always persist" (effectful-core
2.6.1.0, `Effectful.Error.Static`; `Effectful.State.Static.Local` says the same of exceptions).
`Block` is the explicit exception. Both facts get regression cases.

**The kernel's own bookkeeping must survive a caught unwind.** Before §4.13, an unwind ended the
evaluation, so nothing after it read the recursion depth or the fuel budget. Now `Catch`, the loops
and rule application catch unwinds and carry on. So `Evaluate`'s depth count and `WithFuel`'s
budget restore (§4.3) are bracketed: each catches, restores and rethrows, as `Block` does, or else
the depth is held in `Reader` and changed with `local`. A decrement written after the inner call
would be skipped by every caught `Throw`, and a loop of them would push the depth up until
`$RecursionLimit` fired on a shallow computation. The brackets catch `UAbort` too: under
`runKernelIO` the state is the REPL session's `IORef`, so an `Abort[]` deep in a recursion would
otherwise leave the depth raised for the next input. §7.3 states it as a law.

**An interrupt becomes `UAbort` at a safe point, not by an asynchronous throw.** Under
`runKernelIO`, Ctrl-C arrives as an asynchronous exception, which `Error Unwind` never sees. If it
propagated as one, `Block` could not restore, and the REPL session's `IORef` would keep `Block`'s
cleared values. So the REPL's interrupt handler only sets a flag. `Evaluate`'s handler polls the
flag on entry and, if it is set, clears it and raises `UAbort` through the ordinary channel. An
interrupt is then an `Abort[]` at the next evaluation step, and every guarantee above covers it.
A long pure computation below the kernel, such as `factorInteger` or a Gröbner basis, never reaches
a poll. So a **second** Ctrl-C while the flag is still set is thrown asynchronously. The REPL
reports that it skipped `Block` restoration, and the session state is not guaranteed.
`runKernelPure` has no interrupts. **The polling arrives with the REPL (milestone 1c).** Script mode,
1a's only front end, installs no interrupt handler, and `Interrupt` exists as an `Abort` constructor
only.

**`Return` is a fourth unwind, `UReturn Expr`** (D23, answered). `wolfram_ref_return.html`:
"Return[expr] exits control structures within the definition of a function, and gives the value
expr for the whole function", and "Return exits only the innermost construct in which it is
invoked" — its example returns from a `Do` loop inside `g` "but not the function g". So `UReturn`
is caught by whichever is innermost of a loop (`Do`, `While`, `For`, `Until`, `Scan`, which then
yields the value) and a **user-rule application**, which then yields the value as the rule's
result. A user rule's application is a delimited computation only because §4.4 makes its rung
evaluate the right-hand side itself (steps 10 and 12); that is where the catch sits. A pure
function is applied by a built-in rung and does not catch `Return`, so `f[x_] := (Return[1]&[];
2)` gives `f[0]` as `1`, not `2`. Whether WL's `Function` catches `Return` is not on
the page; a regression case pins it. What an uncaught `Return`
becomes at the top is not on the page. Here it is `Hold[Return[expr]]`, held for the same reason
as an uncaught `Throw`: in this design evaluating `Return[expr]` unwinds, so a bare one would fire
again when the result is reused. WL, from memory, prints `Return[expr]` unheld, because its
`Return` is a value that constructs strip rather than an unwind; if the oracle confirms that, this
is a divergence, recorded in §7.5 when the regression case runs. The top-level entry converts it
like the other non-abort unwinds. The page's first "Possible Issues" example has no captured
output, so what `If` alone does with a `Return` inside a compound body is taken from the prose,
not checked; a regression case pins it once the evaluator exists.

### 4.14 Logic and comparison

`Cassini.Builtins.Logic`. The language's comparisons are three-valued, and a symbolic system must
leave undecided comparisons alone: "the condition x==y does not yield True or False unless x and y
have specific values" (`wolfram_ref_evaluation_of_expressions.html`, "Conditionals").

- **`Equal`** (`==`) is `True` when the arguments are identical. Arguments that are not
  numeric expressions are compared structurally first: two distinct strings, or two lists of
  different lengths, are `False`, and two lists of equal length are `Equal` elementwise, `True`
  only if every pair is and `False` if any pair is. Otherwise it asks `isZero` (§5.6)
  about their difference `d`: `Just True` gives `True`, and **`Nothing` leaves `lhs == rhs`
  unevaluated**. `Just False` gives `False` **only when `d` contains no free symbol**. Otherwise
  it too leaves the comparison unevaluated. The reason is that §5.6's `Just False` means "not
  identically zero", which layer 3 proves for `x - y` because `x` and `y` are free. That is not
  "unequal at the current values", and reading it as such would make `x == y` evaluate to `False`,
  against the source just quoted. This is where §5.6's refusal to collapse `Nothing` into
  `Just False` becomes visible: `Sqrt[2] == 1` stays unevaluated, because no exact layer can prove
  a difference involving `2^(1/2)` nonzero (§5.6 layer 3); WL answers `False` numerically, and here
  that waits on D15. `Unequal` is its negation under the same three values.
- **`Less`, `Greater`, `LessEqual`, `GreaterEqual`** decide exactly on rationals and stay
  unevaluated on anything else, including real constants such as `Pi` — deciding `Pi > 3` needs
  certified numerics (D9).
- **`SameQ`** (`===`) and `UnsameQ` are structural `==` on `Expr`: always `True` or `False`.
  **`TrueQ`** is `True` only for `True` — "unless expr is manifestly True, TrueQ[expr] effectively
  assumes that expr is False".
- **`And`, `Or`** have `HoldAll` and evaluate left to right, stopping at the first `False` (for
  `And`; the source: "evaluate until one of the exprᵢ is found to be False") or `True` (for `Or`).
  Arguments that evaluate to the identity element are dropped; if non-Boolean arguments remain, the
  result is `And`/`Or` of those. **`Not`** evaluates `True` and `False` and leaves anything else.
  No further Boolean simplification: normal forms for Boolean expressions are not in scope.

### 4.15 Numbers beyond arithmetic

Three gaps that a user meets in the first minute: radicals, infinities, and the integer functions.
The integer algorithms are L0 — `Cassini.Number.Integer`, no `Expr` — and their `Expr`-level rules
are a pure L4 module, `Cassini.Simplify.Numeric`, attached to the builtins as §4.6 and §4.11 are.

**Radicals of rationals.** Cohen's SPOW-5 returns `v^w` unchanged when no earlier rule applies
(`references/papers/textbooks/cohen2003_*.pdf` §3.2), so `4^(1/2)` stays `4^(1/2)`. `Power`'s
downvalue therefore tries a radical rule after `simplifyPower`, as it tries `simplifyExpPower`
(§4.11). For a rational base and a non-integer rational exponent `a/b`:

1. **Sign:** a negative base `−n`, `n > 0` and `n ≠ 1`, becomes `(−1)^(a/b)·n^(a/b)` — an identity for the
   principal power, since `log(−n) = log n + iπ` for `n > 0`. The base `−1` is excluded. Only step
   3 applies to it, and step 1 would otherwise rewrite `(−1)^(a/b)` to itself times `1^(a/b)`
   without end. Bases between −1 and 0 are included: `(−1/2)^(1/2)` becomes `(−1)^(1/2)·(1/2)^(1/2)`,
   and step 2 then gives `(−1)^(1/2)·2^(−1/2)`, one spelling with its positive counterpart.
2. **Fraction:** `(p/q)^(a/b)` becomes `p^(a/b)·q^(−a/b)`, valid for positive rationals.
3. **Integer part of the exponent:** `n^(a/b)` with `|a| > b` becomes `n^k·n^(r/b)`, `k` and `r`
   from `a = k·b + r` with `k` truncated toward zero, so `r` keeps the sign of `a` and
   `0 < |r| < b`: `2^(3/2) → 2·2^(1/2)`, `2^(-3/2) → (1/2)·2^(-1/2)`. Truncation, not floor, is
   what keeps §4.11's `2^(-1/2)` a fixed point of step 6.
4. **Perfect powers:** a radicand `n = m^j`, `j > 1`, becomes `m^(j·a/b)`, which Cohen's SPOW and
   step 3 then settle: `4^(1/2) → 2`, `4^(1/3) → 2^(2/3)`. The integer root algorithm of
   `references/papers/textbooks/vonzurgathen_gerhard2013_*.pdf` §9.5 is tried for each prime
   `j ≤ log₂ n`, and the first hit is taken. The maximal `j` is not searched for: the result is a
   new power, which evaluation re-enters: `64^(1/3)` takes `j = 2` to `8^(2/3)`, and step 4 again
   gives `2^2 = 4`, the fixed point a maximal `j = 6` would have reached in one step.
5. **Perfect-power factors:** `b`-th powers of primes below a bound `B` are pulled out by trial
   division (§19.2 of the same): `8^(1/2) → 2·2^(1/2)`.
6. **Coefficient merge** — in `Times`, not `Power`: Cohen's product merge never combines a rational
   coefficient with a power, because `1/2` is a number and not `2^(-1)`, so without this step
   `(1/2)·2^(1/2)` (what `Sqrt[2]/2` evaluates to) and `2^(-1/2)` (§4.11's `Sin[π/4]`) are both
   normal forms of one number. For each factor `p^e` with `p` a prime below `B` and `e` a
   non-integer rational, the coefficient's `p`-adic multiplicity `v` moves into the exponent and
   the total `v + e` is split again as in step 3: `(1/2)·2^(1/2) → 2^(-1/2)`,
   `(1/3)·3^(1/2) → 3^(-1/2)`, while `(1/2)·3^(1/2)` and `2·2^(1/2)` are already fixed points.
   This is WL's own convention, from memory rather than the corpus (`Sqrt[2]/2` evaluates to
   `1/Sqrt[2]`); an oracle case pins it.

Each step is valid over ℂ for the principal branch, which §4.11 requires. The result is canonical
for radicals whose radicand is a prime below `B`, or a power of one: the total exponent of each
such prime is determined by the number, and steps 3, 4 and 6 spell it one way. It is **canonical
only relative to `B`** beyond that: a square factor of a prime above `B` stays inside the radical,
and a radicand with two or more distinct prime factors is neither split into primes nor merged with
the coefficient (`(1/2)·6^(1/2)` stays). Nor is `(−1)^(−1/2)` equated with `−(−1)^(1/2)`. So
two spellings of one number can survive and `isZero` layer 2 will not equate them. Full
factorization would close that at unbounded cost; the bound is a decision (D24). Cohen's product
merge does the rest — `2^(1/2)·2^(1/2)` has one base and merges to 2 — and nothing here combines
unlike bases (`2^(1/2)·3^(1/2)` stays). This is what gives §4.11's inverse tables their "one
spelling per value" for prime radicands: `ArcSin[Sqrt[2]/2]` evaluates its argument to
`2^(-1/2)` and reaches the table.

**Infinities and `Indeterminate`.** Sources: `wolfram_ref_numbers.html`, section "Indeterminate and
Infinite Results", and `wolfram_ref_directedinfinity.html`/`wolfram_ref_indeterminate.html`, all in
`references/papers/wolfram-language/`. §4.7 produces `ComplexInfinity`, `DirectedInfinity[-1]` and
`Indeterminate`, and to Cohen they are symbols — so without a rule `1 + ComplexInfinity` is a
well-formed ASAE sum. `Infinity` is `DirectedInfinity[1]` and `ComplexInfinity` is
`DirectedInfinity[]`; directions are `±1` until there are complex numbers (D20). `Plus`, `Times` and
`Power` run an infinity pass **before** Cohen's operators, implementing the extended-real and
Riemann-sphere tables. In the table `d` and `e` are directions, `±1`; `ComplexInfinity` is named
wherever a row covers it:

| Expression | Result |
| :--- | :--- |
| finite number `+` `DirectedInfinity[d]`; finite number `+` `ComplexInfinity` | `DirectedInfinity[d]`; `ComplexInfinity` |
| `DirectedInfinity[d] + DirectedInfinity[d]` | `DirectedInfinity[d]` |
| `DirectedInfinity[d] + DirectedInfinity[−d]`, `ComplexInfinity + ComplexInfinity`, `ComplexInfinity + DirectedInfinity[d]` | `Indeterminate`, `Infinity::indet` |
| nonzero number `c` `·` `DirectedInfinity[d]` | `DirectedInfinity[sign(c)·d]`; `ComplexInfinity` unchanged |
| `DirectedInfinity[d] · DirectedInfinity[e]` | `DirectedInfinity[d·e]`; `ComplexInfinity` if either is |
| `0 · DirectedInfinity[…]` | `Indeterminate`, `Infinity::indet` |
| `DirectedInfinity[…]^n`, integer `n > 0` | the product row, `n` times |
| `DirectedInfinity[1]^r`, `ComplexInfinity^r`, non-integer rational `r > 0` | `Infinity`; `ComplexInfinity`. `DirectedInfinity[-1]^r` is left unevaluated: its direction `(−1)^r` is not `±1` (D20) |
| `DirectedInfinity[…]^r`, rational `r < 0`; in particular `1/DirectedInfinity[…]` | `0` |
| `DirectedInfinity[…]^0` | `Indeterminate`, `Power::indet`. Without this row, Cohen's SINTPOW-2 would give `1` |
| `c^Infinity`, rational `c`: `c > 1`; `c < −1`; `|c| < 1`; `c = ±1` | `Infinity`; `ComplexInfinity`; `0`; `Indeterminate` |
| `c^(−Infinity)` | as `(1/c)^Infinity`; `0^(−Infinity)` is `ComplexInfinity` |
| `c^ComplexInfinity`, any rational `c`, `0` included | `Indeterminate`. Without the `0` case, `0^ComplexInfinity` would reach Cohen's SPOW-2, whose `Undefined` has no cause in §4.6 to map |
| `Infinity^Infinity`; `Infinity^(−Infinity)` | `ComplexInfinity`; `0`. Other infinite bases with infinite exponents are left unevaluated |
| `Indeterminate` as an argument of any `NumericFunction` head | `Indeterminate` |

In a product with non-numeric factors, the rows apply to the numbers and the infinities, and the
other factors stay (D25): `2·x·Infinity → x·Infinity`, while `0·x·Infinity` is `Indeterminate`.
Sums work the same way: the rows apply to the numeric and infinite terms, and every other term
stays. `2 + x + Infinity → x + Infinity`, and `x + Infinity - Infinity` is `Indeterminate`, since
the pass sees `Infinity` and `DirectedInfinity[-1]` whatever else is in the sum.

The table's rows follow the sources' prose ("If you try to find the difference between two infinite
quantities, you get an indeterminate result"; "A message is produced whenever an operation first
yields Indeterminate"). The product, power and exponent rows are the extended-real limits, from
memory of WL rather than from the captures, whose outputs are images; so are the tags
`Infinity::indet` and `Power::indet` on the `^0` row. Each such row is a regression case once there is an oracle (§7.5).

The last row is not the infinity pass's: it holds for every `NumericFunction` head
(`wolfram_ref_indeterminate.html`: "If Indeterminate appears in the argument of any function with
attribute NumericFunction, the result will be Indeterminate"), so it is one evaluator rule, keyed on
the attribute, not a case in each builtin: §4.4's `evalStepIndet`, after step 9 and before every
rule rung. `Sin[Indeterminate]` reaches it, not `Cassini.Simplify.Elementary`. **`Plus`, `Times`
and `Power` carry `NumericFunction`**, as in WL, and they must: without it `Indeterminate -
Indeterminate` reaches Cohen's sum merge and collects to 0, the very example
`wolfram_ref_numbers.html` gives of arithmetic laws that are "suspended in the case of
Indeterminate". `simplifyE` applies the same rule at every node, so it and the evaluator still
agree (§4.11).

**Only numbers are absorbed — a deliberate divergence from WL.** `x + Infinity` stays as it is. WL
absorbs symbols too (`wolfram_ref_directedinfinity.html`: "Finite or symbolic quantities are
absorbed", with `DirectedInfinity[z] + x` as the example). Here `x` may itself be infinite, and
absorbing it would be the kind of rule §4.8 forbids — one that quietly assumes something about
`x`. D25 records this. `compareCanonical` needs no change: the heads are symbols and `DirectedInfinity[…]` is a
function, both already ordered.

**What is not absorbed must be guarded.** Keeping `x + Infinity` as an ordinary term exposes it to
Cohen's identity transformations, which assume every term is finite: like-term collection sends
`y·(x + Infinity) - y·(x + Infinity)` to 0, the same-base merge sends `(x + Infinity)/(x + Infinity)`
to `(x + Infinity)^0`, and SINTPOW-2 sends that, and `(x·Infinity)^0`, to 1. Each is a finite
answer to an indeterminate form — the same quiet assumption D25 exists to refuse, made in the other
direction. So the pass also recognizes **infinity-bearing** expressions: `DirectedInfinity[…]`
itself, a sum with an infinity-bearing term, a product with an infinity-bearing factor, and a power
whose base is infinity-bearing and whose exponent is a positive rational. (An infinity inside a
function argument or an exponent does not count: `Sin[x + Infinity]` is not infinite.) Before
Cohen's operators run, it applies three more rows, each giving `Indeterminate`:

| Node | Guarded case | Result |
| :--- | :--- | :--- |
| `Plus` | two infinity-bearing terms with the same term part (Cohen's `Term`, what his sum merge compares) whose coefficients have opposite signs, a `DirectedInfinity[-1]` factor counting as a sign, as in `u - u` and `2u - u` | `Indeterminate`, `Infinity::indet` |
| `Times` | two factors with the same infinity-bearing base (Cohen's `Base`) whose exponents are rationals of opposite sign, as in `u·u^(-1)` | `Indeterminate`, `Infinity::indet` |
| `Power` | an infinity-bearing base with exponent 0 | `Indeterminate`, `Power::indet` |

Like terms and like bases with coefficients or exponents of one sign merge as Cohen merges them:
`u + u → 2u` and `u·u → u^2` hold for an infinite `u`. One case is left alone rather than decided: an
infinity-bearing base under two exponents that are not both rationals (`u^x·u^(-x)`), whose merge
is sound or not according to the signs of values the kernel does not have. The pass hands Cohen's
operator the other factors and appends those two unmerged, in ◁ order, so the product is not an
ASAE; `isElementaryNormal` admits exactly this exception. The sources give the principle, not the
rows: "The usual laws of arithmetic simplification are suspended in the case of Indeterminate"
(`wolfram_ref_numbers.html`), and an infinite quantity is where they would fail first. §7.3 states
it as a property.

**Integer and rational functions** — `Cassini.Builtins.Integer`, evaluating on exact numbers and
leaving symbolic arguments alone:

| Builtin | Rule | Note |
| :--- | :--- | :--- |
| `Abs`, `Sign` | exact on rationals | symbolic arguments need assumptions (D18) |
| `Floor`, `Ceiling`, `Round` | exact on rationals | `Round` breaks ties to even |
| `Quotient`, `Mod` | `Quotient[m, n] = Floor[m/n]`; `Mod` has the sign of `n` | so `m = n·Quotient[m, n] + Mod[m, n]` always |
| `GCD`, `LCM` | integers | `PolynomialGCD` is §5.4's |
| `Binomial`, `Factorial` | non-negative integer arguments | `Factorial` is Cohen's `simplifyFactorial` (§4.6) |
| `Numerator`, `Denominator` | Cohen's `numerator`/`denominator` (§4.12) | on rationals and general expressions |
| `Max`, `Min` | `Flat`, `Orderless`; numeric arguments collapse to the extreme | symbolic arguments remain |
| `PrimeQ` | strong pseudoprimality test, fixed witnesses (vzGG §18.3) | deterministic, so `runKernelPure` stays a function. With the first 13 primes as witnesses it is a proof below 3.3·10²⁴ (bound from memory; the corpus does not hold it); above that a fixed witness set has constructible strong pseudoprimes, so `PrimeQ` there is "probable prime" |
| `FactorInteger` | trial division, then Pollard's rho with a fixed sequence of seeds (vzGG §19.2, §19.4) | `{{p, e}, …}` with every `p` prime (probable prime above `PrimeQ`'s bound). It factors completely, as WL's does, so its time is unbounded on hard inputs. A partial answer would break the contract. Interrupting it needs §4.13's second Ctrl-C |

`Cassini.Number.Integer` exports the algorithms (`integerRoot`, `trialFactor`, `isProbablePrime`,
`factorInteger`), each citing its section in the module header (§2.7). Randomized algorithms run
with fixed seeds throughout: the evaluator under test is a pure function (§4.3), and a
nondeterministic `FactorInteger` would make that false.

---

## 5. Stage 2 — the polynomial substrate

Everything hard in a CAS runs on polynomial arithmetic and GCD. Building integration or
factorization before this is solid is failure mode (c), the ordering error that kills projects.

**Exit criterion:** correct multivariate GCD and content/primitive part on non-trivial inputs, and a
zero test that never answers `Just` wrongly (milestone 2a); factorization over ℤ (2b). See §10.

### 5.1 The bridge

`Cassini.Poly.Convert` is the only module in `Cassini.Poly.*` that sees an `Expr` (§1.2), and it is
deliberately asymmetric:

```haskell
-- | Cassini.Poly.Convert
--
-- Source: @references/papers/textbooks/cohen2002_*.pdf@ §6.2 (general polynomial
-- expressions), §6.5 (general rational expressions).

-- Generalized variables are /expressions/, not symbols — @Sin[x]@ and @x@ both
-- qualify — so the bridge instantiates 'Multi''s variable type at 'Expr', whose
-- 'Ord' is 'compareCanonical' (§3.5).

toPolynomial   :: (MonomialOrder ord) => Vars Expr -> Expr -> Maybe (Multi Expr ord Rational)
fromPolynomial :: (MonomialOrder ord) => Multi Expr ord Rational -> Expr

isPolynomialGPE :: Vars Expr -> Expr -> Bool
degreeGPE       :: Vars Expr -> Expr -> Maybe Integer
coefficientGPE  :: Expr -> Integer -> Expr -> Maybe Expr   -- variable, degree, subject
variables       :: Expr -> Vars Expr                        -- in compareCanonical order
```

**Recognition can fail; construction cannot.** Whether a subexpression is a variable or a
coefficient depends on the variable list: `Sin[x]` is a variable in `Sin[x]^2 + 1`. The library does
not guess; `Cassini.Builtins.Polynomial` guesses once, so `Factor[x^2-1]` needs no variable list.

**The variables are `Expr`s**, because a `Symbol` cannot name `Sin[x]`. `variables` returns them in
`compareCanonical` order, never the session-dependent `Ord Symbol` (§3.2), so the default layout is
deterministic across sessions. `fromPolynomial` needs no variable argument: the polynomial carries
its variables (§5.2), which is what makes a mismatch between a polynomial and "its" variable list
unrepresentable rather than a check each caller must remember.

### 5.2 Representations

Two, both parameterized by coefficient type:

```haskell
-- | Cassini.Poly.Uni — dense, coefficients ascending, no trailing zeros.
-- A newtype over @poly@'s 'VPoly' (§5.3).
newtype Uni a = Uni (VPoly a)

-- | Cassini.Poly.Multi — sparse distributed, carrying its variables
newtype Vars v = Vars (Vector v)                -- ordered, no duplicates: the exponent layout

newtype Monomial ord = Monomial (Vector Word)   -- exponents, positionally per 'Vars'
  deriving newtype (Eq)

class MonomialOrder ord where
  compareMonomial :: Monomial ord -> Monomial ord -> Ordering

instance (MonomialOrder ord) => Ord (Monomial ord) where
  compare = compareMonomial

data Multi v ord a = Multi { mVars :: !(Vars v), mTerms :: !(Map (Monomial ord) a) }
```

**Dense univariate** because fast univariate arithmetic and the modular and Hensel algorithms want
it. **Sparse distributed multivariate** because a CAS's multivariate polynomials are overwhelmingly
sparse, and Gröbner bases (§6.1) need a distributed representation with an explicit order anyway.

**Every polynomial carries its variables, and every binary operation aligns them** (D13). The
variable type `v` is a parameter with `Ord v`, so the algebra tower never names `Expr`; the bridge
instantiates it (§5.1). The rules:

- **Equal `Vars`: the fast path.** No reindexing; comparing a handful of variables is O(k).
- **Otherwise the result's variables are the left operand's, followed by the right operand's extras
  in the right operand's order**, and both are reindexed to that layout — a runtime
  `canonicalMap` (`references/papers/haskell/ishii2018_*.pdf` §2.3). So `+`, `*`, `divide` and `gcd`
  are total, with no `Either` and no partial function (§2.3), and ℚ[x,y] and ℚ[y,z] combine in
  ℚ[x,y,z] instead of by position. The left operand is never reordered, so a variable order a caller
  chose survives.
- **`Eq` aligns before comparing**, so `p + q == q + p` although the two layouts may differ. Layout
  never reaches output: `fromPolynomial` goes back through evaluation.
- **`zero` and constants have empty `Vars`** and align with anything, which gives the `semirings`
  instances clean identities.
- **Hot loops are positional.** `Cassini.Poly.Multi.Internal` holds the aligned-input core that
  Gröbner reduction and the GCD rungs run on; algorithm modules align once at entry, then stay
  positional.

**No stored recursive representation**, but a recursive **view**:
`asRecursive :: (Ord v) => v -> Multi v ord a -> Uni (Multi v ord a)` — univariate in the *named*
main variable, over the remaining ones — and its inverse, computed on demand. The PRS rungs of §5.4
are univariate algorithms, and this view is how they apply to multivariate inputs without
maintaining two representations. `Uni` itself stays variable-free; the caller of the view knows the
main variable.

The monomial order is a type parameter (`references/papers/haskell/ishii2018_*.pdf`), because mixing
lex and grevlex polynomials is a real bug that types prevent. **The parameter sits on `Monomial`**, so
that `Ord` — hence the `Map`'s order, hence the leading term — is determined by it; on `Multi` alone
it would not reach the key type, where it does its work. Orders compare exponent vectors
positionally, which is sound because alignment makes each position mean the same variable in both
operands.

### 5.3 Build or buy

| Option | For | Against |
| :--- | :--- | :--- |
| **`poly` + `semirings`**<br>`references/papers/haskell/poly_hackage.html` | `Vector`-backed, Karatsuba multiplication, `GcdDomain`/`Euclidean`/`Field` already defined, actively maintained | Its classes are not the full tower; multivariate support is a flag; the representation is its choice |
| **Kmett's `algebra`**<br>`references/papers/haskell/algebra_hackage.html` | The finest-grained hierarchy available, with the `Numeric.Domain.*` chain `Domain → IntegralDomain → GCDDomain → UFD → PID → Euclidean` a coefficient tower wants | Large, slow maintenance cadence |
| **`numeric-prelude` / `numhask`**<br>`references/papers/haskell/numhask_hackage.html` | Principled `Num` replacements, axioms as QuickCheck properties | Whole-prelude commitments, and the prelude budget is spent on relude (§2.3) |
| **Local `Cassini.Algebra.Class`** | Exactly the classes used; no dependency risk | Reinvention; the laws must be written anyway |

**Recommendation: `poly` + `semirings`, with a thin local `Cassini.Algebra.Class`** for what
`semirings` does not supply (D5). `poly` is the only option that is fast, maintained and already
integrated with a class hierarchy.

`Num` is not used for coefficients, for the reasons
`references/papers/haskell/numeric_prelude_hackage.html` gives that still hold: it defines no
semantics for its operations, mixes representation-specific operations (`toInteger`, `decodeFloat`)
into a semantic interface, and is too coarse — defining `+` forces `*`. (Its other complaint,
`Eq`/`Show` superclasses, has not applied since base 4.5.)

**The switching cost:** `Cassini.Poly.Uni` is a newtype over `VPoly`, not a re-export, so replacing
`poly` means rewriting that module, not the GCD and factorization code above it.

**`poly` is built with its `sparse` flag off.** Only its dense univariate `VPoly` is used —
multivariate polynomials are `Cassini.Poly.Multi` (§5.2) — and the flag, on by default, enables
"sparse and multivariate polynomials, incurring a larger dependency footprint"
(`references/papers/haskell/poly_hackage.html`).

### 5.4 GCD

A ladder, cheapest first, each rung a separate function with the same signature so a dispatcher can
choose:

1. **Euclidean** over a field. Correct; catastrophic coefficient growth over ℚ.
2. **Primitive PRS** — content and primitive part at every step. Correct, still slow.
3. **Subresultant PRS** — the standard remedy for coefficient explosion, and the default for small
   problems. Shares `Cassini.Poly.Resultant` with §6, whose resultants name the variable they
   eliminate rather than taking "the first".
4. **Brown's modular algorithm** — dense multivariate, via evaluation/interpolation and CRT.
5. **Zippel's sparse interpolation** — sparse multivariate; the right answer for the inputs a CAS
   actually sees.

Rungs 1–3 are univariate; for multivariate inputs they run over the recursive view (§5.2), with
coefficient GCDs computed recursively. That is enough for Stage 2's correctness criterion
(milestone 2a). Rungs 4–5 are milestone 2b (§10), where §8.5's benchmark starts to matter: they are
the first place an asymptotically better algorithm is slower on small inputs and the dispatcher has
to choose.

Sources: `references/papers/textbooks/geddes_czapor_labahn1992_*.pdf` ch. 7 for the pipeline,
`references/papers/textbooks/vonzurgathen_gerhard2013_*.pdf` for modular and fast-arithmetic depth,
`references/papers/textbooks/zippel1993_*.pdf` for rung 5.

`content` and `primitivePart` are exported: factorization and `Together`/`Apart` need them
independently.

### 5.5 Factorization

The pipeline for ℤ[x], each stage a module-level function:

1. **Squarefree decomposition** (Yun's algorithm, characteristic 0). Cheap, and required by
   everything downstream including integration (§6.2), which is why it lands here.
2. **Factorization over 𝔽ₚ** for a prime `p` that keeps the input squarefree and its degree — distinct-
   and equal-degree splitting (Cantor–Zassenhaus), with Berlekamp for small `p`.
3. **Hensel lifting** from mod `p` to mod `pᵏ`. The subtle part; ship the linear lift first.
4. **Recombination** (Zassenhaus). Exponential in the number of modular factors in the worst case —
   a known, accepted Stage 2 limitation.
5. **van Hoeij / LLL** — the fix for step 4's worst case. Out of scope for Stage 2, with the
   interface shaped so it drops in.

Multivariate factorization reduces to univariate by evaluation plus multivariate Hensel lifting
(`geddes_czapor_labahn1992_*.pdf` ch. 8).

**What each prefix delivers.** Steps 1–2 give `FactorSquareFree` and `Factor[…, Modulus -> p]`
(with the characteristic-*p* variant of step 1), testable alone by reconstruction (§7.3). They do
**not** factor over ℤ: modular factors mean nothing over the integers until lifted and recombined,
so integer `Factor` needs steps 3–4, with a rational-root test for linear factors as the cheap
interim. Steps 3–4 are where the schedule slips; knowing what the prefix buys makes stopping there a
decision.

### 5.6 Zero testing

The module whose type signature is the design:

```haskell
-- | Cassini.Zero
--
-- Source: @references/papers/foundations/richardson1968_*.pdf@ — for the class of
-- expressions over the rationals, π, ln 2, a variable, @+ - *@, composition, and
-- @sin@/@exp@/@abs@, the predicate @E = 0@ is undecidable.
isZero :: (Kernel :> es) => Expr -> Eff es (Maybe Bool)
```

The `Kernel` constraint is required: layer 2 needs automatic simplification, which it reaches by
evaluating (`evaluate`, §4.3). `Cassini.Zero` may not import `Cassini.Simplify.Automatic` or
`Cassini.Eval` (§2.6, rules 1 and 5).

**`Maybe Bool` has three inhabitants, and all three are used.** `Just True` and `Just False` are
proofs. `Nothing` is "I do not know", returned honestly rather than collapsed into `Just False` —
the collapse that turns an incomplete simplifier into a wrong one.

The layers, tried in order:

1. **Exact numbers.** Decidable, immediate.
2. **Structural identity** after automatic simplification. Proves `Just True` only; sound, not
   complete.
3. **Polynomial normal form.** For expressions recognizable as polynomials or rational functions in
   their generalized variables (§5.1), normalize. A zero normal form proves `Just True`. **A nonzero
   normal form proves `Just False` only when every generalized variable is a free symbol** — no
   value, not a built-in constant. Other generalized variables can be algebraically dependent:
   `Sin[x]^2 + Cos[x]^2 - 1` has a nonzero normal form in `{Sin[x], Cos[x]}` and is zero, as does
   `I^2 + 1` in `{I}`, and whether π and e are algebraically independent is an open problem.
   Otherwise, fall through. A `Just False` from this layer means **not identically zero**. For
   an expression with a free symbol it does not mean "nonzero at the symbol's eventual value", so
   §4.14's `Equal` does not read it that way.

   3′. **Trigonometric.** If some generalized variable has a circular or hyperbolic head (§4.11),
   evaluate `` Cassini`TrigZero[e] `` (§4.12). That is a protected, internal head whose built-in
   downvalue runs `simplifyTrig`, the same function the `Simplify` builtin wraps. It goes through
   its own head so that a user's definition on `Simplify`, or a `Block[{Simplify}, …]`, cannot
   change what `isZero` proves. A result of 0 proves `Just True`: every step of
   `Simplify_trig` is an identity over ℂ, so `e` is zero wherever it is defined — the same
   standard layer 3 applies to `x/x - 1`. Anything else, `Indeterminate` included, falls through;
   this layer never proves `Just False`. It is what decides `Sin[x]^2 + Cos[x]^2 - 1`. It needs no
   new import: `Cassini.Zero` reaches it by evaluating, exactly as layer 2 reaches automatic
   simplification.
4. **`Nothing`.**

**There is no random-evaluation layer yet.** It would help only where layer 3 cannot decide — the
transcendental cases — and those do not evaluate to exact numbers at rational points. In exact
arithmetic it would be redundant with layer 3; in floating point, unsound. A sound `Just False` from
numerical evaluation needs certified interval bounds, out of scope per §0.2: D15, waiting on D9.
(Returning `Just True` from agreement at sample points is the classic soundness bug, at any
precision.)

Every caller must handle `Nothing`, in practice by leaving the expression alone: a simplifier that
cannot prove a denominator non-zero does not cancel it. An SMT backend (`sbv`/Z3) for polynomial side
conditions is D10 — not adopted; heavy dependency, narrow payoff.

---

## 6. Stage 3 — the hard algorithms

Where hobby projects stall. The response is to sequence these last, accept partial coverage
explicitly, and — for integration — ship a useful thing before the complete thing.

### 6.1 Gröbner bases

```haskell
-- | Cassini.Groebner
-- | The 'Vars' argument is the variable order, which lex and elimination orders
-- depend on; inputs are aligned to it once, at entry (§5.2).
groebnerBasis :: (Field a, MonomialOrder ord, Ord v)
              => Vars v -> [Multi v ord a] -> [Multi v ord a]
reduce        :: (Field a, MonomialOrder ord, Ord v)
              => Vars v -> Multi v ord a -> [Multi v ord a] -> Multi v ord a
```

**Buchberger first**, with both Buchberger criteria for discarding S-pairs and the selection
strategy (normal strategy: smallest lcm first) as a parameter. Sources:
`references/papers/term-rewriting/baader_nipkow1998_*.pdf` ch. 8 for the rewriting view — Gröbner
bases *are* completion, which is what connects them to §4 — and
`references/papers/textbooks/geddes_czapor_labahn1992_*.pdf` ch. 10 for the algorithm as an
implementer wants it.

**F4 second**, replacing the S-pair reduction loop with sparse linear algebra over a Macaulay matrix:
a larger implementation behind the same interface, with
`references/papers/haskell/ishii2018_*.pdf` as the reference for doing it in Haskell. F5 is not
planned.

The payoff is not `GroebnerBasis[...]` as a feature but **simplification with side relations**
(`references/papers/textbooks/cohen2003_*.pdf` ch. 8): reducing an expression modulo algebraic
relations, which is how `Simplify` handles `x^2 + y^2 == 1`. That is this section's acceptance test.

Double-exponential worst-case complexity is not a bug to fix. It is why the property tests use
small, hand-chosen ideals and the benchmarks carry a timeout
(`references/papers/haskell/ishii2018_*.pdf` §3.2 makes the same point).

### 6.2 Integration — three tiers, deliberately

**Tier 1: a rule-based integrator**, the most opinionated Stage 3 choice. A Rubi-style ordered
decision tree of integration rules (`references/papers/cas-architecture/rich_rubi_vision.html`) —
thousands of ordered rules with side conditions, applied by a rewriting engine with a fixed point —
is exactly what this architecture runs, and Symbolica and Symja took this route
(`references/papers/cas-architecture/symbolica_2_2_symbolic_integration.html`,
`references/papers/cas-architecture/symja_readme.html`). `Cassini.Integrate.Rules` is a rule set
loaded into the ordinary tables; the work is the loader, the rule syntax and the side-condition
vocabulary. A few hundred hand-written rules — polynomials, rational functions with one linear
denominator, exponentials, logarithms, basic trigonometric forms — cover most of what a person
types. Porting the full Rubi corpus is a separate project, its scale recorded in
`notes/cas-haskell.md`.

**Tier 2: rational functions, done properly** — a complete algorithm for a decidable subproblem,
finite work with a definite end. `references/papers/textbooks/bronstein2005_*.pdf` ch. 2: Hermite
reduction for the rational part, then Rothstein–Trager or Lazard–Rioboo–Trager for the logarithmic
part. It depends on §5.4's subresultant PRS and §5.5's squarefree decomposition, the concrete reason
Stage 2 comes first.

```haskell
-- | Cassini.Integrate.Rational

-- | Numerator, denominator (non-zero). Total: see below. The variable is not an
-- argument — 'Uni' is variable-free, and the builtin supplies it when converting back.
integrateRational :: Uni Rational -> Uni Rational -> Result

data Result = Result
  { rationalPart :: (Uni Rational, Uni Rational)             -- ^ numerator, denominator
  , logPart      :: [(Uni Rational, Uni (Uni Rational))]     -- ^ (R(t), S(t, x)): Σ over
  }                                                          --   roots α of R of α·log S(α, x)
```

**It is total; a `NotElementary` case would be a lie in the type.** By partial fractions every
rational function has an elementary antiderivative — a rational part plus logarithms — and Hermite
plus Rothstein–Trager always find it. The log part's constants may be algebraic, hence the RootSum
form `(R(t), S(t, x))` rather than (constant, argument) pairs: no algebraic-number type is needed.
`NotElementary` becomes real in tier 3, where it is an outcome.

**Tier 3: the transcendental Risch algorithm.** `bronstein2005_*.pdf` ch. 5–6: differential fields,
monomial extensions, the Risch differential equation, and the primitive, hyperexponential,
hypertangent and nonlinear cases. Large and structured; this is where the schedule ends.

**The algebraic case is out of scope, not a backlog item.** There is no textbook treatment of it
(`notes/cas-haskell.md` §"Caveats"), so it is research rather than implementation, and must not
appear on a roadmap as a matter of effort.

### 6.3 Summation

`Cassini.Summation.Gosper` (indefinite hypergeometric summation) and `.Zeilberger` (creative
telescoping for definite sums), from `references/papers/textbooks/petkovsek_wilf_zeilberger1996_*.pdf`.
Both are compact, resting on polynomial GCD, resultants and linear algebra over ℚ, so they are
available as soon as §5.4 lands — the cheapest real Stage 3 capability, and a good first target.

Difference-field summation (Karr, and Schneider's Sigma extending it) is a separate track of
comparable size to Risch, reaching nested sums and products Gosper–Zeilberger cannot. Sources:
`references/papers/textbooks/karr1981_*.pdf` and `references/papers/textbooks/schneider2007_*.pdf`
(the readable entry point). Not scheduled; the module boundary exists so it has somewhere to go.

### 6.4 The rest of Stage 3, briefly

`Solve` (linear systems by fraction-free Gaussian elimination, polynomial systems by Gröbner),
`Series` (truncated power series as a coefficient ring, reusing §5.2), and `Limit` (series-based,
with documented incompleteness). Each is a module with a stated dependency on the substrate; none is
on the critical path. §10 gives each a track with its own criterion.

### 6.5 Surface forms

Every algorithm in §5–§6 needs a builtin, and a builtin needs a result form a user can read and the
kernel can evaluate. The algorithm modules in `A` never see an `Expr` (§1.2), so each builtin below
converts at the boundary, in L4.

| Builtin | Algorithm | Result form, and what the form must settle |
| :--- | :--- | :--- |
| `GroebnerBasis[polys, vars]` | §6.1 | a list of polynomials; the monomial order is an option naming §5.2's order type |
| `PolynomialReduce[p, basis, vars]` | §6.1 | `{quotients, remainder}`; the surface form of "simplification with side relations" (§10) |
| `Resultant[p, q, x]`, `Discriminant[p, x]` | §5.4's `Cassini.Poly.Resultant` | a polynomial in the remaining variables |
| `Collect`, `Cancel`, `ExpandAll` | §4.12's `Cassini.Simplify.Rational`; `Cancel` needs §5.4 | expressions; `Cancel` removes only the common factors the GCD finds |
| `Solve[eqns, vars]` | §6.4, in `Cassini.Solve` | `{{x -> a, …}, …}`, one rule list per solution. Degenerate and parametric systems (a coefficient that may be zero) are not split into cases: that needs conditional results (D22) |
| `Sum`, `Product` | §4.13's iterators; §6.3 when a bound is symbolic | a closed form, or the input unevaluated; Gosper's closed forms are hypergeometric terms, which need `Pochhammer`/`Gamma` (D21) |
| `Series[f, {x, x0, n}]` | §6.4 | `SeriesData[x, x0, coeffs, nmin, nmax, den]`, printed with `O[x]^n`; `Normal` drops the order term. Arithmetic on two `SeriesData` truncates to the smaller order |
| `Limit[f, x -> a]` | §6.4 | a value, a `DirectedInfinity` (§4.15), or the input unevaluated — never a guess |
| `Integrate` (tier 2) | §6.2's `integrateRational` | its log part is `RootSum[Function[t, R(t)], Function[t, t·Log[S(t, x)]]]`, which evaluates to explicit logarithms when `R` factors into linear factors over ℚ and stays symbolic otherwise; `D` of a `RootSum` distributes over its second argument |

`RootSum` is the one new head here with evaluation rules of its own: the form above is what makes
`integrateRational`'s totality (§6.2) printable without an algebraic-number type.

**The table is here, but not all of it is Stage 3.** Builtins whose algorithms are Stage 2's —
`Resultant`, `Discriminant`, `Cancel`, and with them `PolynomialGCD`, `Together`, `Factor` and
`Apart` — land with milestones 2a and 2b (§10), so the polynomial substrate reaches a user when it is
built, not a stage later. The result forms are fixed together, in one place, either way.

---

## 7. Testing

In a CAS, "it ran without crashing" says almost nothing. The tests are the specification, in six
kinds that catch different failures.

### 7.1 Layout and harness

`tasty` throughout, the suite tree mirroring `src/`, all in `cassini-core/` (§2.1):

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
  Test/Numeric.hs             -- test-only Double evaluator (§7.3)
  regress/                    -- the regression corpus (§7.4)
oracle/
  Main.hs                     -- the differential suite (§7.5)
slow/
  Main.hs                     -- Gröbner, factorization, integration at size
  Test/Slow/...
corpus/
  Main.hs                     -- the imported corpora (§7.8–§7.9)
```

Each suite is its own cabal stanza with its own `hs-source-dirs`, because they have different run
times and different reasons to fail:

| Suite | Contents | Runs |
| :--- | :--- | :--- |
| `cassini-test` | unit, property, golden | every commit, both interning settings; must take seconds |
| doctests (not a suite; §7.6) | Haddock examples | every commit |
| `cassini-oracle` | differential against external systems | nightly, and wherever the externals are present |
| `cassini-corpus` | other systems' test cases and Wolfram's documentation examples, under a ratchet (§7.8) | nightly, over whichever corpora are present |
| `cassini-slow` | Gröbner, factorization, integration at size | nightly |

A suite that takes minutes stops being run; the fast suite's job is to be run compulsively.

### 7.2 Unit tests

`tasty-hunit`. **Unit tests are worked examples lifted from the sources, and each cites where it came
from**, so the expected values were computed by someone else before the implementation existed:

```haskell
-- Source: cohen2003 §3.1, Example 3.23 (an ASAE and four non-ASAEs)
asaeExamples :: TestTree
asaeExamples = testGroup "ASAE-5 (sums)"
  [ testCase "2x + 3y + 4z is an ASAE"           $ isASAE [expr| 2*x + 3*y + 4*z |] @?= True
  , testCase "1 + (x + y) + z violates ASAE-5-1" $ isASAE ... @?= False
  ...
  ]
```

Harvests worth doing:

- **Cohen** §3.1: the ASAE examples and non-examples (Examples 3.22–3.25) and the order examples
  (`a·x² ◁ x³`, `(1+x)³ ◁ (1+y)`, `m! ◁ n`); §3.2's worked simplifications.
- **Wolfram's** evaluation traces from *Evaluation of Expressions* — each also a golden trace
  (§7.4) — and its worked examples under "Conditionals" and "Loops and Control Structures"
  (`If[x == y, a, b]` staying unevaluated, the `Switch` and `Do` examples) for §4.13–§4.14.
- **Krebber** §3.3's commutative-matching examples, including the one with six candidate mappings
  and exactly one match, a precise test of whether the phases prune correctly.
- **Bronstein** ch. 2's worked Hermite reductions and Rothstein–Trager examples.
- **Cohen** `cohen2002_*.pdf` ch. 7: Examples 7.5–7.7 (expansion), 7.12–7.14 (contraction), 7.15–7.18
  (`Simplify`, each to 0), and (7.18)/(7.19); Fig. 7.9's rows for §4.11's automatic rules, each
  tagged with the column it reproduces.

Plus the ordinary kind: every edge case gets a test, and every bug gets one (§7.4).

### 7.3 Property tests

`tasty-quickcheck`, not `hedgehog`: QuickCheck's `Arbitrary` is what the ecosystem's generators
(including `poly`'s) are written against, and hand-written shrinkers for the few types that matter
are the smaller cost (D4).

**The generators decide whether any of this pays.** `Test/Gen.hs`:

- `genExpr :: Int -> Gen Expr` — size-bounded valid expressions over a **small fixed symbol pool**,
  the budget split among arguments. With fresh symbols everywhere no two subterms are equal, and
  every test that depends on collecting like terms passes vacuously.
- `genASAE :: Int -> Gen Expr` — already-simplified expressions, for the idempotence law.
- `genPattern :: Expr -> Gen Expr` — a pattern *derived from* a subject by replacing subterms with
  blanks, so it matches by construction; random patterns almost never match anything. It builds no
  side conditions (§4.5.2).
- `shrinkExpr` — replace a node by a child, shrink numbers toward zero, drop arguments. Without it
  counterexamples are unreadable and get ignored.

**Numeric checks use a test-only evaluator.** Several laws compare values at random points, and most
expressions do not evaluate to exact rationals there (`2^(1/2)`, `Sin[1/3]`). `Test/Numeric.hs`
evaluates an `Expr` to `Double` at a point and compares with a relative tolerance, skipping points
near singularities. It lives in the test tree because it is a heuristic oracle, not a decision
procedure — which is exactly why the library's zero test has no such layer (§5.6).

**The law table.** Each row is a property; the last column is what justifies its cost.

| Layer | Property | Catches |
| :--- | :--- | :--- |
| `Number` | `+`/`*`/`^` agree with `Rational`; `compareNumber` agrees with `compare` on `toRational` across both constructors | normalization and sign errors; a constructor-order `Ord` (§3.1) |
| `Core.Order` | `compareCanonical` is reflexive, antisymmetric, transitive and terminates — over generated expressions *and* pairwise over one hand-written value of every kind (constant, string, symbol, product, power, sum, factorial, function, curried-head function, malformed `Power`) | an O-13 case wrong; a kind pair no rule covers, which diverges (§3.5) |
| `Core.Order` | `compareCanonical x y == EQ ⟺ x == y` | O-8/O-9 equating distinct non-ASAEs without the O-T tiebreak |
| `Core.Order` | `sortBy compareCanonical` is a permutation of its input | dropped or duplicated `Orderless` operands |
| `Core.Intern` | `==` agrees with a reference structural equality; `hash` agrees with `==` — under both flag settings | interning divergence (§3.4) |
| `Core.Traversal` | `cata embed ≡ id` | a traversal that does not rebuild through the smart constructors |
| `Structure` | `substitute u t t ≡ u`; `freeOf u t` implies `substitute u t r ≡ u` | subexpression comparison errors |
| `Attributes` | `AttributeSet` is a commutative idempotent monoid; `holdsArgument` agrees with a naive reference on every (attributes, index, arity) | `HoldFirst`/`HoldRest` off-by-one |
| `Rules` | `insertRule` keeps the set sorted by specificity with insertion order breaking ties; `applicableRules` visits rungs in `ladder` order | rule shadowing ("my definition is ignored"); a rung visited out of ladder order, the inversion of §4.2 |
| `Simplify` | `simplifyRNE` agrees with `Rational`, and is `Nothing` exactly on division by zero | normalization and sign errors |
| `Simplify` | `simplify u` satisfies `isASAE` or is `Left` | the postcondition, directly |
| `Simplify` | **for an ASAE `u`, `simplify u ≡ u`** | the source's own contract; stronger than idempotence |
| `Simplify` | `simplify` preserves numeric value (test evaluator) | a canonical form that is canonical but wrong |
| `Simplify.Elementary` | `simplifyE u` satisfies `isElementaryNormal` or is `Left`; for elementary-normal `u`, `simplifyE u ≡ u`; `simplifyE` preserves numeric value | a parity or periodicity rule that fires on its own output; a special-value table entry that is wrong (§4.11) |
| `Simplify.Trig` | `expandTrig` output satisfies `isTrigExpanded` and `contractTrig`'s satisfies `isTrigContracted`; each is idempotent and preserves numeric value | a transcribed formula with a wrong sign; a procedure that stops before its normal form (§4.12) |
| `Simplify.Trig` | `simplifyTrig` preserves numeric value wherever the input is defined | a cancellation that is not an identity |
| `Simplify.Numeric` | radical normalization preserves numeric value and is idempotent; two products of rationals and radicals whose radicands are primes below `B` or their powers with equal numeric value normalize identically; `integerRoot n b` is exact exactly on perfect powers; the infinity pass agrees with the extended-real table on every pair from a fixed set of finite and infinite values; for generated infinity-bearing `u`, `u - u`, `2u - u`, `u/u` and `u^0` evaluate to `Indeterminate`, and no evaluation turns an infinity-bearing input finite by cancellation | a sign or branch error in steps 1–3 of §4.15; a table cell wrong; Cohen's identity transformations cancelling an infinity D25 left unabsorbed |
| `Number.Integer` | `m ≡ n·Quotient m n + Mod m n` with `Mod` taking the sign of `n`; `factorInteger` multiplies back and every factor passes `isProbablePrime`; `isProbablePrime` agrees with trial division below 10⁶ | floor-versus-truncate division; a composite witness set |
| `Control` | `Function[x, b][a]` evaluates as `b` with `a` substituted, capture-free on generated nested scopes; `Block` leaves every localized symbol's own, down, up and sub values as it found them on normal exit, `Throw`, `Break` and `Abort[]`; `Module`'s fresh names depend only on the initial `KernelState`; after any caught `Throw`, `Break`, `Continue` or `Return`, the recursion depth and fuel budget equal their values before the catching construct, and after an `Abort[]` they equal their values before the top-level input; an uncaught `Throw`, `Break`, `Continue` or `Return` comes back `Hold`-wrapped, and evaluating that result raises nothing | variable capture; a `Block` that leaks on unwind; session-dependent names; depth or fuel leaking through an unwind or an abort; an uncaught `Throw` that fires again when its result is reused (§4.13) |
| `Logic` | `Equal a b` is `True` only when `isZero (a − b)` is `Just True`, and `False` only when it is `Just False` and `a − b` has no free symbol; `x == y` for distinct free `x`, `y` stays unevaluated; `And`/`Or` never evaluate an argument after the deciding one | a comparison that turns "don't know", or "not identically zero", into `False` (§4.14) |
| `Pattern` | soundness: every `σ` from `matchAll p s` satisfies `applySubst σ p ≡ s` modulo attributes | the whole matcher, in one line |
| `Pattern` | completeness: `genPattern` output always matches its subject | phases 1–2 over-pruning |
| `Pattern` | for side-condition-free patterns, matching leaves `KernelState` unchanged except for messages | the backtracking rule (§4.5.2) |
| `Pattern` | `matchOne ≡ listToMaybe <$> matchAll` | the observation functions diverging |
| `Pattern` | the `RuleIndex`'s candidates for an expression include every rule that matches it, in table order (§4.5.5) | an index that drops a rule, or reorders specificity |
| `Eval` | `evaluate . evaluate ≡ evaluate` | a non-converging fixed point |
| `Eval` | evaluation under `runKernelPure` is deterministic given the same initial state | hidden `IO` dependence |
| `Syntax` | `parse (pretty e) ≡ Right e`; `parseFullForm (fullForm e) ≡ Right e` | the precedence table and printer disagreeing (§4.10) |
| `Algebra` | ring/field axioms on every coefficient type | the axioms types do not check |
| `Poly` | for `q ≠ 0`, `p * q / q ≡ p`; `gcd p q` divides both, and `gcd * lcm` associates with `p * q` | every GCD rung, uniformly |
| `Poly` | all implemented GCD rungs return associates of one another | rung 4/5 bugs, with rung 3 as reference |
| `Poly.Multi` | operations on operands with different `Vars` agree with the same operations after explicit alignment; `p + q == q + p` across layouts; `fromPolynomial (toPolynomial vs e)` round-trips for any `vs` containing `e`'s variables | reindexing errors, and a fast path that skips alignment it needed (§5.2) |
| `Poly.Factor` | factors multiply back to the input; factoring any factor returns it unchanged | recombination errors |
| `Zero` | `Just True` ⇒ the test evaluator gives 0 at random points; `Just False` ⇒ it gives nonzero somewhere | the soundness bugs §5.6 exists to prevent |
| `Calculus` | `D` agrees with finite differences of the test evaluator | sign and chain-rule errors |
| `Groebner` | every input reduces to 0 modulo the basis; all S-polynomials of basis pairs reduce to 0 | Buchberger's criterion, as a property |
| `Summation` | Gosper's antidifference `T` satisfies `T(n+1) − T(n) ≡ t(n)` | the self-verifying trick, one section early |
| `Integrate` | `D (integrate f) ≡ f` | everything |

Where a row says `≡` between results of different algorithms, it means `isZero (a − b) == Just True`;
`Nothing` is reported as inconclusive, not as a pass.

**Stage 3 is testable because it is self-verifying.** Differentiating an antiderivative, differencing
an antidifference, and the S-test for a Gröbner basis each check an expensive algorithm with a cheap
one, so those tests can be generated rather than hand-written.

**Determinism.** CI passes a fixed `--quickcheck-replay` seed and prints it on failure. A nightly job
runs a random seed at a much larger count; a failure there becomes a regression case (§7.4) with the
seed recorded.

### 7.4 Regression tests

`tasty-golden`, over a text corpus:

```
test/regress/
  0001-orderless-flatten-collect.in
  0001-orderless-flatten-collect.expected
  0002-builtin-upvalue-beats-user-downvalue.in
  0002-builtin-upvalue-beats-user-downvalue.expected
  ...
```

Each `.in` is a script of FullForm expressions, one per line. A whole-line WL comment `(* … *)` is
not an input, so a case can cite its source. Each `.expected` is **§7.9's format**, which
`runScript` adopted when it landed: `Out[k]: <FullForm>`, or `Out[k]: -` for `Null`, then one
`Message[k]: symbol::tag` line per message. The corpus adapter therefore needs no translation.
Trace cases add `Trace[k]: <step>: <FullForm>` lines before each output, indented by depth (§4.4). `Test/Golden.hs` discovers cases with `findByExtension` and runs them through
`Cassini.Script.runScript` (§4.10), so a case exercises the FullForm reader, the evaluator and the
printer together, and adding one is adding two files. FullForm, not pretty output, so that printer
improvements invalidate nothing.

**The protocol** (also CLAUDE.md rule 5):

1. **Every fixed bug adds a numbered case, in the same commit as the fix.** The four-way ladder, the
   `Flat`/`Listable`/`Orderless` order and the matcher's phase order are all things a
   plausible-looking refactor breaks silently.
2. **Goldens are read before they are accepted.** `--accept` makes it trivial to enshrine a bug; a
   person reads the diff, and the commit message says why the new output is right.
3. **Cases are named for the behaviour, not the bug** — `0002-builtin-upvalue-beats-user-downvalue`,
   not `0002-issue-17`.

**One test-only builtin.** Every golden case runs against the standard builtins plus a built-in
upvalue on ``Test`up``, which answers `"builtin upvalue"` for any expression with a ``Test`up[…]``
argument. 1a's builtins have no upvalue of their own, and
`0002-builtin-upvalue-beats-user-downvalue` needs one. `Test/Golden.hs` installs it through
`runScriptWith`. The unit test of the rung order installs one built-in rule on each rung the same
way.

**Golden evaluation traces.** A second set, `test/trace/`, records the *step sequence* for chosen
expressions:
which of the thirteen steps fired, in order, and the expression after each. A refactor that reorders
`Flat` and `Orderless` gives correct-looking answers for most inputs and a visibly wrong trace for
all of them.

**Seeded corpus.** Every §7.2 worked example that spans more than one module goes in as a golden case
from the start, so the suite has something to regress against before the first bug. The trace set
seeds with the `Trace` inputs of *Evaluation of Expressions* that 1a's builtins cover. Its outputs
are images, so those traces were read by hand against the page's prose.

### 7.5 Differential testing against external systems

`cassini-oracle` runs Cassini and an external CAS on the same inputs and compares. It **skips** when
the external is absent, so it never breaks a clean checkout. The pattern is Ishii's — shell out to a
trusted implementation from inside a property, where the property cannot be stated internally
(`references/papers/haskell/ishii2018_*.pdf` §3.2, with Singular for Gröbner bases).

| External | Compares | Notes |
| :--- | :--- | :--- |
| Mathics3 | evaluator semantics, attributes, rule precedence | the closest thing to a reference implementation of the language |
| SymPy | simplification, factorization, integration | different normal forms, so compared semantically |
| Singular | Gröbner bases | Ishii's choice, and the fastest correct reference |

**Comparison is semantic.** Two CASs rarely agree on printed form, so the oracle checks
`isZero (ours - theirs)` and reports `Nothing` as inconclusive, for human review, not as failure. A
suite that cries wolf gets turned off.

Three structural divergences from WL are deliberate, and a reader of a Mathics3 transcript will meet
them first: `Sin[x]/Cos[x]` is not rewritten to `Tan[x]` (D16); a constant trigonometric argument
is reduced to `[0, π/2]` (§4.11); and `x + Infinity` stays a sum instead of absorbing `x` (§4.15,
D25). The second is a divergence per Cohen's Fig. 7.9, whose Mathematica column is circa 2002;
what current WL and Mathics3 do is not in the corpus, and the first oracle run settles it. The
third is not absorbed by semantic comparison, since `isZero` cannot prove `x + Infinity` equal to
`Infinity`; the oracle harness whitelists it. None of the three is a bug. The third would be one
without §4.15's guards, which stop Cohen's cancellations from turning the unabsorbed term into a
finite answer; an oracle case where WL says `Indeterminate` and this system says a number is a
bug, not a whitelisted divergence.

Smaller divergences follow from the same sections. `Sin[π/12]` and the other special values at
denominators 5, 8, 10 and 12 stay unevaluated (§4.11). `2^(1/2)·3^(1/2)` does not become
`6^(1/2)`, and `(1/2)·6^(1/2)` stays as it is (§4.15, D24). And comparisons that WL decides
numerically, such as `Sqrt[2] == 1` and `Pi > 3`, stay unevaluated (§4.14, D9, D15). `isZero`
cannot equate either side of any of these, so semantic comparison does not absorb them, and the
harness whitelists all three kinds.

**The externals arrive with the milestones they check** (§10): Mathics3 with 1a, SymPy with 2a,
Singular with 3d.

**The Mathics3 harness, as built at 1a.** `cassini-oracle` runs every script in `oracle/cases/` and
every regression case in `test/regress/` twice. Cassini runs it through `runScript`.
`oracle/mathics_eval.py` runs it in one Mathics3 session, under the interpreter
`CASSINI_MATHICS_PYTHON` names, and writes the same script format (§7.4). Cases that need a
test-only builtin are skipped. Each input gets one verdict:

- **agree:** structurally equal up to `Orderless` order, or a difference that Cassini evaluates
  to 0;
- **disagree:** the difference is a nonzero number, or the message names differ;
- **inconclusive:** anything else. Until 2a's zero test that includes every symbolic difference,
  and also an input on which Mathics3 raises a Python exception. Mathics3 10.0.1 raises on an
  endless own-value chain (`RecursionError`), and its `Part` assignment fails on a list of indices.

`oracle/divergences.txt` lists known disagreements by case and input. Its reason is a D-number, or
`Mathics3` where Mathics3 departs from WL. Such an entry cites the corpus case documenting WL's
answer, or says the answer is from memory. Only an unlisted disagreement fails the suite. At 1a,
over 127 inputs, 107 agree, 15 are listed and 5 are inconclusive, all from Mathics3's own failures.
Eleven of the 15 are Mathics3 departing from WL's documented behaviour (`Protect`'s result,
`Evaluate` inside `Hold`, `Power[x, y, z]`, `argx`). That is why the corpus is the higher authority
for 1a's builtins.

The Rubi problem corpus is the aspirational end state for `Integrate`; its size and timings are
vendor-reported figures recorded in `notes/cas-haskell.md`, not measurements of this system. §7.8
imports its test suite, which is a static corpus and not an oracle: the answers are already written
down.

### 7.6 Doctests

Every exported function with non-obvious behaviour carries a runnable Haddock example, and those
examples are tests — cheap, and the fix for expression examples that go stale when the normal form
changes. They run on every commit (§2.8, step 4).

**They are not a test-suite stanza: the risk this section carried was real.** `doctest`
interprets sources through the GHC API, and nothing hands an executable cabal's `mixins`
renaming, without which `Prelude` does not resolve to `Cassini.Prelude`. Of the two ways of
borrowing cabal's own flags, `cabal repl --with-compiler=doctest` fails: cabal then builds the
`cassini-prelude` dependency with doctest as its compiler (*unrecognized option
`--make'*). `cabal repl --with-repl=doctest lib:cassini-core`, which cabal 3.14 added for this purpose,
swaps the program only for the repl session and works. Answered on the first build, with doctest
0.25.0.

`--repl-options=-Wno-missing-export-lists` is needed because each example's `import` line is
compiled as an interactive module, which has no export list. The flag is the session's, not a
module's, so §2.4's rule that the warning set is not relaxed per module still holds. Imports an
example needs beyond its module's own go in a `-- $setup` block.

### 7.7 Coverage

HPC via `cabal test --enable-coverage`, reported but **not gated on a percentage**: the matcher's
branch count is dominated by combinatorial cases that a handful of tests reach and a hundred more
would not improve. The checked signals are *uncovered top-level functions*, and *uncovered branches
in `Cassini.Eval` and `Cassini.Simplify.Automatic`*, where an unexercised branch is alarming.

### 7.8 Imported corpora

Other systems have already written down thousands of expected results for the language and the
algorithms this design implements. They were computed before this implementation existed, which is
§7.2's reason for trusting worked examples, at a scale no hand harvest reaches. They are also other
systems' opinions, so they arrive with a scope rule, a divergence manifest and a ratchet; without
those they are a wall of red, and a suite that is mostly red gets turned off.

| Corpus | Holds | Disposition | Joins at (§10) |
| :--- | :--- | :--- | :--- |
| Expreduce, `expreduce/resources/*.m` | `ESameTest[expected, expr]` cases, grouped by builtin, inline with its definitions | vendored | 1c |
| The Rubi test suite, `RuleBasedIntegration/MathematicaSyntaxTestSuite` | `{integrand, x, steps, answer}` | `0 Independent test suites/` vendored; the rest fetched, for size | 3b, 3c |
| Mathics3, `test/` | `check_evaluation(input, expected)` pytest calls | fetched | 1c |
| SymPy's test suite | Python asserts | generated: a script run under SymPy writes chosen cases out as WL, and its output is vendored | 2a, 2b |
| Wolfram's documentation examples | the reference pages' input and output cells | extracted from the documentation notebooks that come with a licence, never committed (§7.9) | W; runs from 1a |

**Disposition follows licence** (D26); the licences are recorded per system in
`notes/cas-haskell-bibliography.md` §5. A permissively licensed corpus is *vendored*: copied into
`corpus/vendor/<source>/` at a pinned upstream commit, with the upstream `LICENSE` beside it and a
`SOURCE` file naming the commit and the command that fetched it. Any other corpus is *fetched*:
`corpus/fetch.sh` clones it at its pinned commit into gitignored `corpus/fetched/`, and the suite
skips a source that is absent, as `cassini-oracle` does. A corpus too large to vendor is fetched
whatever its licence. Of a fetched corpus, the repository holds only case IDs.

Not taken: Symja's and Maxima's test files, which cover the ground of Mathics3's and SymPy's; and
FriCAS's `.input` files, which are sessions without asserted results.

```
corpus/
  Main.hs                     -- the cassini-corpus driver
  Test/Corpus/<Source>.hs     -- one adapter per corpus: its format to sessions
  fetch.sh                    -- pinned clones of the fetched corpora
  tools/                      -- extractors that run outside cabal (§7.9, SymPy's generator)
  vendor/<source>/            -- committed, each with LICENSE and SOURCE
  fetched/                    -- gitignored
  wolfram-docs/               -- gitignored (§7.9)
  passing/<source>.txt        -- the ratchet: IDs of the cases known to pass
  divergences.txt             -- case ID, and the D-number (or "pending §N") that explains it
```

The tools are Python scripts: the Wolfram documentation extractor (§7.9), Mathics3's pytest reader
and SymPy's generator. None is a cabal dependency (§11.1): they produce data, and the suite reads
data.

**Expected values given as printed text are normalized by their own system.** Mathics3's are
strings such as `"34 / 15"`, which parse to `Times[34, Power[15, -1]]`, not `Rational[34, 15]`. Its
extractor therefore runs under Mathics3, reading the test files with Python's `ast` rather than
importing them, and has Mathics3 parse and evaluate each expected string once and write FullForm.
§7.9 applies the same kind of normalization to Wolfram's outputs, restricted there to arithmetic. Normalizing with Cassini's own
evaluator would let a bug reproduce on both sides and pass. Some Mathics3 cases carry a note that
Mathics3 departs from WMA; those are dropped, since they document Mathics3 rather than the language.

**An adapter turns a corpus into sessions.** A session is a sequence of inputs, each with an
optional expected output and expected messages, evaluated in one fresh kernel; that is §7.4's golden
format, so the same `runScript` runs it. A case ID is stable and carries no content: source, file,
position, as in `expreduce/pattern/MatchQ/7` or `wolfram/With/BasicExamples/2`.

**The scope rule** keeps a young system from drowning. A case is *in scope* when every `System``
symbol it mentions is defined in the `Cassini.Builtins` registry and, while D9 stands, it holds no
inexact number; the rest are counted and not run.
Scope grows by itself as builtins land, and in-scope over total, per source, is the report's
headline: it is how much of the language the system claims.

**The ratchet** replaces pass/fail. `cassini-corpus` fails when an in-scope case listed in
`passing/` fails. A case that newly passes is reported, and a person adds it to the list after
reading it, with the same discipline as goldens (§7.4). A case that fails for a deliberate reason
goes in `divergences.txt` with its D-number and is reported as a divergence, not a failure; this is
§7.5's whitelist, kept per case. When a D-number is answered, its divergence entries are
re-examined in the same change.

**A failure can also be scheduled.** Triage meets cases whose behaviour a later milestone or track
implements: radicals and infinities are §4.15's, but their pages mention only 1a's builtins, so
they are in scope at 1a. They are not divergences, and leaving them unlisted would hide them among
failures nobody has looked at. So `divergences.txt` also takes the reason `pending §N`, naming the
section whose work implements the behaviour. The report counts these entries with the
divergences. When that work lands, its pending entries are re-examined in the same change, and
each is either removed or turned into a D-number.

**Comparison, per corpus:**

- **Expreduce, Mathics3, Wolfram documentation: structural.** Actual and expected FullForm must be
  identical up to the order of arguments under `Orderless` heads. Both sides are put in canonical
  order without evaluating either: the order is D8's known divergence, and not worth an entry per
  case. Messages compare by `symbol::tag`, never by text.
- **Rubi: semantic.** `D` of Cassini's answer, minus the integrand, must be `isZero`-`Just True`, as
  in §7.5. The corpus's own answer is not compared; two correct antiderivatives can differ by a
  constant and routinely differ in form. The step count is ignored. A case whose answer needs a D21
  function is out of scope by the scope rule, not a failure, when its integrand mentions one; when
  only the answer does, it is reported as unsolved, not failed.
- **SymPy: structural, or semantic where the generator marks the case**, for results whose normal
  form SymPy does not share with WL (partial-fraction order, factor order, sign normalization).

**Imported cases do not replace regression cases.** When one catches a bug, the fix still adds a
numbered `test/regress/` case (§7.4): a corpus can be re-pinned, and the regression corpus must not
lose a case when it is.

Each milestone records its in-scope pass count per source on completion (§10), as it records its
benchmark baselines, in `corpus/passing/`'s commit history.

### 7.9 The Wolfram documentation corpus

The reference pages' examples are the largest body of expected WL behaviour there is, written by the
language's owner. They are not open. Wolfram's Terms of Use forbid scraping and bulk downloading its
websites (`references/papers/wolfram-language/wolfram_terms_of_use.html`), and the web pages carry
each output only as an image. **So the corpus is extracted from the documentation notebooks that come
with a Mathematica licence, and is never committed or distributed**
(`references/papers/wolfram-language/wolfram_mathematica_license.html`; D27). A developer who wants
it regenerates it from their own copy, as the `references/` corpus is re-fetched.

**No Wolfram kernel is involved.** `corpus/tools/extract_wolfram_docs.py NOTEBOOK_DIR
corpus/wolfram-docs` is Python, and uses Mathics3 where a kernel would parse and normalize. It:

1. **Finds the reference pages by content.** A page is a notebook whose header cell reads
   `BUILT-IN SYMBOL`, and its symbol is the first word of its window title (`Plus (+)`). Recognizing
   pages by content rather than path lets the extractor read an installation's `Documentation/`
   tree or the unpacked offline documentation installer, whose file names are opaque keys.
2. **Reads each notebook** with a tolerant parser of its `Notebook[…]` expression, after removing
   the file format's backslash-newline line continuations.
3. **Splits the examples into sessions.** After the `PrimaryExamplesSection` cell, a session starts
   at each `ExampleSection` or `ExampleSubsection` heading and at each `ExampleDelimiter`, whose
   content is `$Line = 0`: the documentation's own fresh session. Outputs pair with inputs by
   `CellLabel` (`In[k]:=`, `Out[k]=`), and messages by `During evaluation of In[k]:=`.
4. **Flattens boxes to input text.** `RowBox` joins its tokens with spaces. `SuperscriptBox`,
   `FractionBox`, `SqrtBox` and `RadicalBox` become `^`, `/`, `Sqrt` and a fractional power.
   `StyleBox` and `AdjustmentBox` are transparent. `InterpretationBox` yields its second argument,
   which is the expression itself rather than a display of it. A few long names (`\[ImaginaryI]`,
   `\[ExponentialE]`, `\[LeftDoubleBracket]`) are spelled out. A multi-line input cell is one
   `In[k]` with one `Out[k]`; when every line but the last ends in `;`, it becomes one
   `CompoundExpression`, which has the same value. Every other box is unusable, and the box names
   the reason. That covers graphics, `SubscriptBox`, `TraditionalForm`, grids, summary boxes, and
   `TemplateBox` displays such as `Quantity`, `DateObject` and `Entity`.
5. **Parses the text with Mathics3's parser and writes the input's FullForm.** Inputs are never
   evaluated.
6. **Normalizes each output.** Flattened boxes lose the canonical spelling: the output `1/2` parses
   to `Times[1, Power[2, -1]]`, not `Rational[1, 2]`. So each output is evaluated once in Mathics3,
   with every head except arithmetic (`Plus`, `Times`, `Power`, `Sqrt`, `Rational`, `Complex`,
   `DirectedInfinity`, `List` and a few spellings of them) renamed to an inert copy that keeps only
   the original's `Hold*` attributes. A symbol the example's own inputs give a hold attribute
   (`SetAttributes[h, HoldFirst]`, or `Attributes[h] = {…}`) is `HoldAll` there: Mathics3 does not
   know the page's attributes, and WL's output already evaluated what it did not hold. Only
   arithmetic re-canonicalizes, a held argument stays as displayed, and Mathics3 cannot evaluate
   further an output that WL left unevaluated. An output is unusable in any of these cases:
   - a second evaluation changes it;
   - normalization takes more than five seconds, or Mathics3 raises an error on it;
   - its label names a display form other than `InputForm` or `FullForm` (`Out[k]//MatrixForm=`);
   - it contains a `Module` local such as `x$123`, whose number depends on the history of the kernel
     that built the page (§4.13).
7. **Reads messages as `symbol::tag`** from their `MessageTemplate`. `Print` cells are counted, not
   compared. A page still unfinished after five minutes, which only a hang inside compiled code
   causes, is killed and counted as an extractor failure; `run.txt` lists each one.
8. **Writes** `corpus/wolfram-docs/<Page>/<Section>[/<Subsection>]/<n>.in` and `.expected` for every
   case whose inputs are all usable, plus `index.tsv` for every case and `run.txt` (the counts and
   the reasons, tallied, and the documentation's version). `index.tsv` gives each case's ID,
   status and counts, whether it holds an inexact number, the reasons, and the `System`` symbols
   its inputs and outputs mention, which is what the scope rule (§7.8) reads. Mathics3 files a
   System symbol it does not implement under `Global``, so "System" here means Mathics3's or any
   symbol with a reference page. A System symbol with neither, such as `ChartElementData`, passes
   for a user symbol; triage catches the rare case this lets into scope.

   `<Page>` is the page's own documentation URL, not its title, because a few functions have
   variant pages under one title (`blockchain/BlockchainData-Bitcoin` beside `BlockchainData`).
   Three pages ship twice under one URL; the copy tagged with the `Mathematica` paclet is kept.

**What the adapter translates** (§7.4 fixed the golden format to be this one):

- An expected file numbers its inputs as the documentation page did, so a one-input case can
  hold `Out[67]`. Every input has exactly one `Out` line, so the adapter pairs the *k*-th label
  in order with input *k*.
- Message symbols are written as the notebook displays them, so `Infinity::indet` arrives as
  `\[Infinity]::indet`. That is a normalizer defect, and D27's row records it. The adapter
  rewrites it until the next extractor run fixes it.

A `.in` file holds one FullForm input per line. A `.expected` file holds, for each input, a line
`Out[k]: <FullForm>`, or `Out[k]: -` for an input with no output, or `Out[k]: ?<reason>` for an
unusable output, followed by one `Message[k]: symbol::tag` line per message. §7.4 fixes the golden
format when `runScript` lands; if the two differ, the adapter translates this one.

**The expected outputs are the published outputs, not re-evaluations.** Nothing runs an example's
inputs; the only evaluation is the arithmetic normalization of step 6.

**The normalization is Mathics3's arithmetic, not Wolfram's**; that is the cost of having no kernel
(D27). It is confined to arithmetic applied to what was already a WL fixed point, but it is not the
same system. A normalizer defect surfaces as a case that fails in Cassini and whose expected value,
read against the page, is not what the page shows. Triage then fixes the extractor; it does not add
a divergence entry.

Because the output is FullForm, this corpus runs from 1a, before the infix parser exists. It also
reaches what the web captures could not: a behaviour §4.13–§4.15 takes from prose alone can be
checked against a documented output, wherever the pages carry an example of it. The tutorial
notebooks (*Evaluation of Expressions* and its neighbours) are a second pass, which needs a page
recognizer for tutorials; their examples overlap the §7.2 harvest, which keeps its hand-cited cases.

---

## 8. Benchmarking

### 8.1 Harness

`tasty-bench`: it shares `tasty`'s command line and tree vocabulary, adds nearly no dependencies, and
has baseline comparison, which turns benchmarking from an activity into a gate.

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

Compiled with `-O2` and `-with-rtsopts=-T`, so allocation and residency are reported beside time.
For a term rewriter **allocation is the story**: regressions show up as bytes long before seconds,
and allocation is deterministic for a given compiler and flags, where time is not.

The flags are `--baseline`, `--fail-if-slower`, `--fail-if-faster` and `--csv` (confirmed against
`tasty-bench` 0.5.1). **`--fail-if-slower` thresholds time only**, though the CSV has an allocation
column, so the allocation gate is ours: `bench/check-allocation.py BASELINE CURRENT`, which fails
when a benchmark's `Allocated` exceeds its baseline by more than 10% and by more than 1 KiB (§8.6).
The absolute slack is for the near-zero baselines: several benchmarks allocate nothing per
iteration, or a few bytes of stack growth, and against 0 any allocation is an infinite percentage.
Baselines are named
`ghc-<version>-<hash|intern>.csv`, because the interning flag changes every allocation figure.

**Baselines come from plain `cabal bench`.** The stanza's `-O2` covers the benchmark code only;
the library is built at cabal's default optimization, as in every other build. A library built at
`-O2` (`cabal bench -O2`) can move allocation figures by large factors: on one Stage 0 build,
equality of equal terms built apart allocated 43 bytes per iteration at `-O2` and 512 KiB at the
default, so a baseline from one setting fails the gate under the other. Under the `intern` flag
allocation also varies by a few percent from run to run, with garbage-collection timing, which the
10% threshold absorbs.

### 8.2 Core (Stage 0)

The suite that decides interning (§3.4), and so the first written:

- Construct a large expression tree bottom-up.
- Structural equality on two large equal expressions, and on two differing at the last leaf (the
  case the hash cache should make fast).
- `compareCanonical` on pairs of increasing depth.
- `sortBy compareCanonical` on 10, 100, 1000 arguments.
- `substitute` over a deep tree.
- **An expression-swell proxy**: the expanded form of `(a+b+c+d)^n` built directly with the smart
  constructors, since `Expand` does not exist yet.
- **The A/B**: all of the above with the `intern` flag on and off, on the same inputs — time,
  allocation and residency. Residency is what shows whether the table reclaims.

**The gate** (D2): interning ships if it wins on expression swell on both time and allocation. The
Stage 0 run uses the proxy and is provisional; the decision closes against §8.4's real `Expand`
workload, which arrives with the elementary-functions track (§10), and the numbers are recorded in
§11.2 either way.

### 8.3 Matcher

Designed to answer specific questions rather than produce a number:

- Syntactic matching, pattern and subject of increasing size.
- Sequence variables: *k* variables against *n* arguments, over a grid, recording **allocation per
  match** as well as time — `MatchT`'s continuation-passing interior degrades by allocating, and time
  alone cannot separate the monad from the search space. This is the measurement D11 turns on.
- Commutative matching at arity 3, 5, 8, 12, with and without phases 1–2, which measures their
  pruning directly.
- An adversarial pair: a linear AC pattern (polynomial) against a non-linear one (NP-complete) at the
  same size.

**The net question** (§4.5.5): sweep the **number of subjects** matched against a fixed pattern set
— 1, 10, 100, 1000, 10000 — for the one-to-one matcher and a prototype net. Run once, record the
crossover, and build the net if and only if the crossover is below the volume the evaluator actually
generates.

**Results at 1b** (2026-10-10; GHC 9.12.4, hash interning, one developer machine; the baselines in
`bench/baseline/` carry every row):

- Syntactic: 3.1 µs at 4 arguments, 41 µs at 64, linear in the pattern.
- Sequence grid: allocation per match is flat, 5.0–5.5 KB and 1.2–1.7 µs once there are more than a
  handful of matches, from 31 matches (`k = 2`, `n = 32`) to 4495 (`k = 4`, `n = 32`). Small cells
  cost more per match (9–20 KB) only because setup is shared by fewer matches. The grid does not
  show `MatchT` degrading with depth or count; see D11.
- Commutative, steps 1–2 on: flat at 17–22 KB from arity 3 to 12. Off: 23 KB to 151 KB, and 6.2 µs to
  41 µs, so at arity 12 the two steps prune by a factor of 7 in both.
- Adversarial, 8 arguments: the linear pattern has 204 matches (1.0 ms) and the non-linear one 12
  (81 µs), at the same 5–7 µs and 16–20 KB per match. At this size the difference is the number of
  matches, not the search for them.
- The net question: §4.5.5.

### 8.4 Evaluator and simplifier

- **Fixed-point convergence**: expressions needing 1, 5, 20 rounds — also the D14 trigger, since
  re-evaluating settled subterms shows up here first.
- **Expression swell**: `Expand` of `(a+b+c+d)^n` for growing `n` — the canonical stress case, and
  where structure sharing pays or does not.
- **Deep `D`**: repeated differentiation of a nested product, which exercises the rule engine
  rather than the arithmetic.
- **`//.` against 10, 100, 1000 rules**.
- **Automatic simplification**: sums and products of 10, 100, 1000 terms, with and without like
  terms, separating sort cost from merge cost. The terms arrive in scrambled order. On that input
  `simplifySum` and `simplifyProduct` are quadratic in the number of distinct operands: SPRDREC-3
  merges one operand at a time into the simplified rest. At 1000 terms that is about 50 ms and
  120 MB, against 1 ms and 3 MB when the terms are alike. The evaluator always reaches them after
  step 9 has sorted the arguments, where each merge stops at the first comparison, so the
  quadratic case is the Haskell API's, not the evaluator's.
- **Trigonometric expansion**, in two parts, because the obvious one cannot see what it is meant
  to guard. `TrigExpand[Sin[a₁ + … + aₙ]]` for growing `n` is the end-to-end cost, baselined; but
  its output has 2ⁿ⁻¹ terms, so its allocation is exponential under either recursion, and the naive
  recursion's re-expansion adds only about a factor of `n` on top, which a baseline at fixed `n`
  catches as a jump and a curve does not show. The pair recursion is gated separately:
  `expandTrigRules (a₁ + … + aₙ)` alone, before algebraic expansion. With the pair returned, each
  level builds a constant number of new nodes over shared subterms, so allocation is linear in `n`;
  the naive recursion's 2ⁿ⁻¹−1 rule applications make it exponential, and that curve is what the
  gate catches.

### 8.5 Polynomial

GCD and multiplication across the ladder (§5.4), measured against `poly`'s own operations as a
reference, so "our GCD is slow" can be told apart from "polynomial GCD is slow". Sized to cross the
point where the modular algorithm overtakes subresultant PRS, because that crossover is the
dispatcher's input.

Gröbner bases live in `cassini-slow`, benchmarked on a small fixed set of ideals **with a timeout** —
a double-exponential benchmark without one eventually becomes a hang. The number to watch is the
Buchberger/F4 ratio on the same inputs, not absolute time.

### 8.6 End-to-end, and the regression gate

One fixed workload — parse, evaluate and print a script exercising simplification,
differentiation, pattern replacement and polynomial arithmetic — measured as a single number.

**The workload grows by milestone, and the gate is on from 1a** (§10). At 1a it is a FullForm script
of automatic simplification and user rules through `runScript`; 1b adds the pattern builtins over
sequence variables, `Orderless` sums and definitions that need them (43 MB allocated, from 1a's
22 MB); 1c adds infix parsing, printing and differentiation, and 2a polynomial arithmetic. A gate that waited for the full workload would be off
through Stage 1, the most refactor-heavy stretch of the project. Each extension is a deliberate
baseline regeneration, with the commit message saying what the workload gained.

**This is the number CI gates on.** Microbenchmarks are advisory: noisy, sensitive to compiler and
machine, and gating on them produces flaky builds that get disabled.

- **Allocation is the hard gate**: fail above the committed baseline by more than 10%. Allocation
  does not depend on the machine, so any machine's baseline is valid for the same GHC and flags.
  `check-allocation.py --only All.EndToEnd` restricts the check to this workload. The
  microbenchmarks stay in the same CSV, and in the same baselines, as advice.
- **Time is gated (`--fail-if-slower 10`) only against a baseline produced on the same runner
  class** — generated by a CI job and committed deliberately. A developer-machine baseline would
  make it flaky or meaningless, so until one exists, time is reported, not gated.

Baselines live in `bench/baseline/`, one per GHC version (cross-version comparison is meaningless),
and are regenerated deliberately, with the commit message saying why.

### 8.7 What is not measured

No headline comparison against Mathematica, SymPy or Symbolica. Cross-system performance needs
equivalent workloads and tuning, and a number produced without both is marketing. The oracle suite
(§7.5) uses those systems for *correctness*, which they can answer.

---

## 9. Risks

### 9.1 The five documented ways this fails

`notes/cas-haskell.md` names five failure modes for exactly this project. Each maps to the decision
that addresses it:

| Failure mode | Addressed by |
| :--- | :--- |
| (a) Making the core type-safe and drowning in type-level machinery | §1.1 — untyped kernel, typed algebra, one explicit bridge; §2.6's lint keeps them apart |
| (b) Underestimating automatic simplification | §4.6 — Cohen's full procedure tree, `isASAE` as an executable postcondition, the ASAE-idempotence law (§7.3) |
| (c) Building integration/factorization before the substrate | §5 before §6; §6.2's rational tier depends on §5.4 and §5.5 |
| (d) Ignoring matcher performance until the rule set is large | §4.5.5 — the `RuleIndex` interface from day one; the net built on a measured crossover (§8.3) |
| (e) No memoization or structure sharing | §3.3–§3.4 — cached hashes from day one, interning behind smart constructors with a measured gate; D14 for evaluation memoization |

### 9.2 Risks this design introduces

- **The `unsafePerformIO` intern table**, and the symbol table beside it (§3.2), which has the same
  idiom but no weak references. Mitigations: `Cassini.Core.Intern` exports one function;
  the module is compiled with `-fno-full-laziness -fno-cse`; `Eq` never trusts the table (§3.4), so
  a premature reap or lost race costs sharing, not correctness; both flag settings are tested on
  every commit. Residual risk: a GHC change to weak-pointer behaviour degrading sharing silently —
  which §8.2's residency line is there to notice.
- **`logict` inside `MatchT` under deep backtracking.** `LogicT`'s continuation-passing structure
  over a non-trivial base monad can allocate heavily, and its `forall r` quantification blocks the
  specialization that makes `Eff`'s bind cheap. Mitigation: §8.3's allocation-per-match grid. The
  fallback (D11) has two rungs, cheapest first:

  1. Swap the newtype's interior to `logict-sequence`, whose `Seq`-based representation has
     different asymptotics under left-nested `>>=`. One module, no new correctness burden.
  2. Hand-roll the continuation type, specialized to `Eff es` and `INLINE`d:

     ```haskell
     newtype MatchT es a = MatchT
       { runMatchT :: forall r. (a -> Eff es r -> Eff es r) -> Eff es r -> Eff es r }
     ```

     It must reproduce `liftMatch`, `observeFirst`, `observeAll` and the five instances, and nothing
     else — in particular not `msplit` or fair disjunction, which the §4.5.4 phases never call for.
     A bounded amount of backtracking-monad correctness to own, which is why it is second.

  Both are one-module changes because `MatchT` is a newtype and §2.6's rule 6 confines `logict` to
  its module.
- **Pattern-synonym indirection.** `COMPLETE`-annotated view patterns cost nothing at `-O2` and
  something at `-O0`, slowing the test suite. Accepted: §3.4's reversibility is worth more.
- **The dependency posture.** `relude` + `effectful` + `mixins` is less familiar to Haskell
  contributors than `base` + `mtl`, and lengthens the first build. Accepted for §4.3's payoff: a
  kernel that runs without `IOE`.
- **Cohen's order is not WL's.** `compareCanonical` is Cohen's O-1…O-13, well specified but not what
  Mathematica's `Sort` produces, so the oracle suite will see ordering differences. Mitigation:
  semantic comparison (§7.5); ordering fidelity is a documented non-goal (D8).

### 9.3 The undecidability ceiling, as a design constraint

There is no general algorithm for deciding whether a symbolic expression is zero
(`references/papers/foundations/richardson1968_*.pdf`), so every real simplifier is heuristics with a
best-effort contract. This is not a risk to mitigate but a constraint that shapes three decisions:
`Cassini.Zero` returns `Maybe Bool` and callers must handle `Nothing` (§5.6); canonical forms are
promised only where they exist — rational numbers, polynomials and rational functions in independent
variables (§4.6, §5.2); and `Simplify` is documented as best-effort. The failure prevented is an
incomplete simplifier quietly becoming a *wrong* one by treating "could not prove it non-zero" as
"it is zero".

---

## 10. Milestones

Each milestone has an acceptance criterion that is a *behaviour*, the tests that encode it, and,
where it has them, the numbers it records on completion — benchmark baselines in `bench/baseline/`,
decisions in §11.2.

**Stages are split where one criterion would hide most of the work.** Stage 1 carried one criterion
that exercised a small part of its gating set, and Stage 2 one that said nothing about factorization
or about what a user can type. The milestones within a stage gate in order. **Tracks** are the work
that gates nothing, each stating what it waits for and when it is done. **Milestone W** stands
outside the stages: it builds test data, not code, and gates only in that 1a and later milestones
triage against what it produces.

### Stage 0

**Done when** large expressions can be constructed, compared and traversed at measured cost,
`compareCanonical` passes its order laws, **and the tooling that enforces the rules exists**. The
tooling is here because every later stage is written under it; added afterwards, it is a cleanup of
everything already written.

- Tooling: `cassini.cabal` per §2.4 — the `common` stanzas, the `cassini-prelude` sublibrary and its
  `mixins` (§2.3; a package of its own since the split of §2.1), and the `intern` manual flag selecting §3.4's two source directories;
  `.hlint.yaml` per §2.6, with its fixtures; CI (§2.8) green on steps 1–7 with `-Werror`. Step 8
  arrives with 1a.
- §7.6's doctest risk answered on this first build, and §2.8 step 4 and §7.6 edited to say which
  form survived.
- Tests: the `Number`, `Core.Order`, `Core.Intern`, `Core.Traversal` and `Structure` rows of §7.3,
  under both interning settings, over `Test/Gen.hs`'s `genExpr` and `shrinkExpr`; Cohen's order
  examples as unit tests.
- Benchmark: §8.1's harness and §8.2 in full, with the provisional interning A/B recorded against D2.

**Done 2026-10-04** (PR #10), with CI green on steps 1–7 under `-Werror` in both `intern`
settings. The departures it found are recorded in their sections:
- the warning set (§2.4);
- hlint's extensions (§2.5);
- the unsafety audit (§2.3, §3.2);
- the boot-file cycle and where the traversal instances live (§3.4, §3.6);
- `Ord Expr` and the O-T composition (§3.5);
- heads as subexpressions (§3.7);
- the doctest form (§7.6);
- the provisional D2.

### Milestone W — the Wolfram documentation corpus

Needs the documentation notebooks that come with a Mathematica licence, and Mathics3; it does not
need Cassini or a Wolfram kernel. So it waits for nothing in the code and runs alongside Stage 0. It should: 1a is the first milestone that can use it, and it is more use as
a corpus waiting there than as a corpus assembled afterwards.

**Done when** `extract_wolfram_docs.py` (§7.9) has run over every reference page in the installed
documentation, and `run.txt` accounts for every example on every page: extracted, or unusable with
its reason. The goal is *as many examples as possible*, and this makes it countable. The measure is
coverage of the documentation, not of Cassini: examples with a usable input and output, over all
examples, recorded in D27's row with the Mathematica version.

- The first-run corrections to §7.9's assumed cell styles and structure made, per D27.
- `corpus/wolfram-docs/` confirmed untracked by `git status` after a run.
- The tutorial notebooks' second pass is not gating.

**Done 2026-09-28**, over Mathematica 14.1's documentation. Every example on all 6,552 pages is
extracted or has a recorded reason, with no extractor failures; the counts are in D27's row.

### Stage 1

Three milestones, each a working evaluator a size larger than the last, then tracks.

#### 1a — the evaluator

Attributes (§4.1), the rule tables and ladder (§4.2), the `Kernel` effect and both interpreters
(§4.3), the evaluation sequence (§4.4), the syntactic matcher (§4.5.3, step 1), automatic
simplification (§4.6), messages (§4.7), `Builtins.Arithmetic`, `.Structural` and `.Assign`, and
`Cassini.Syntax.FullForm` with `runScript` (§4.10). The last is here so that the regression corpus
(§7.4) starts with the code it guards. `Builtins.Arithmetic` and `.Structural` were missing from this
list, though the corpus triage below names both and the criterion needs `Plus`.

**Done when** `Plus[a, Plus[b, a]]` flattens, sorts and collects to `2a + b`, and its golden trace
shows step 7 before step 9.

That criterion is four features at once: `Flat` flattening (step 7), `Orderless` sorting (step 9),
Cohen's `Simplify_sum_rec` merge, and the fixed-point loop. Flattening and sorting to `Plus[a, a, b]`
is the easy half; **collecting like terms is automatic simplification proper**, and the half worth
gating on.

- Tests: the `Attributes`, `Rules`, `Simplify` and `Eval` rows of §7.3; the `Syntax` row's FullForm
  half; the `Pattern` rows over syntactic patterns; the Wolfram evaluation traces as golden traces;
  Cohen §3.2's worked simplifications; the seeded corpus (§7.4), including
  `0002-builtin-upvalue-beats-user-downvalue`.
- Benchmark: §8.4's fixed-point and automatic-simplification rows baselined; the §8.6 gate on, over
  its 1a workload.
- The oracle harness (§7.5) arrives here, with Mathics3: evaluator semantics are where it is most
  informative, and where this stage's behaviour is most easily got subtly wrong.
- Corpus: `cassini-corpus` arrives (§7.8) with its scope rule, ratchet and divergence manifest, over
  milestone W's corpus, which is FullForm and so needs no parser. Every in-scope failure on the
  pages of this milestone's builtins (`Builtins.Arithmetic`, `.Assign`, `.Structural`, and the
  attributes) is triaged: passing, a `divergences.txt` entry, or a fix with its regression case.
  The in-scope pass count is recorded.

**Done 2026-10-09** (PR #12), with CI green on steps 1–8 under `-Werror` in both `intern`
settings, step 8's allocation gate included.

Corpus and oracle at completion:

- **Corpus:** 624 of the 111,806 Wolfram documentation cases are in scope. 535 pass and are the
  ratchet; 24 are in `divergences.txt` (D14, D20, D25, D29, and `pending` §4.5.3, §4.11, §4.13 and
  §4.15); 65 fail on pages outside this milestone. 47 of the 624 came into scope when the
  attribute names became `System`` symbols, after a PR review found they were not; their triage
  fixed an evaluator bug (§4.4's settled round), three gaps in `Attributes` and `Unprotect`, and a
  normalizer defect (D27).
- **Oracle:** 173 of 204 inputs agree with Mathics3 10.0.1. 23 are listed and 8 are inconclusive,
  all from Mathics3's own exceptions.

The departures it found are recorded in their sections:

- the three added kernel operations, the idempotent recursion cut, and where depth and fuel live
  (§4.3);
- the skipped settled round, `Evaluate` in a held position, what the trace records, and rule
  conditions (§4.4, D14);
- `MatchOps` open recursion and the `Expr` head constraint (§4.5.1–§4.5.2);
- SPOW-2 and `isASAE` on `0^w`, MPRD's second constant, and D29 (§4.6);
- the golden format and the test-only upvalue (§7.4);
- the oracle harness (§7.5);
- `pending §N` entries and the adapter's translations (§7.8–§7.9, D27);
- the quadratic merge on unsorted input (§8.4);
- D30, WL's `TerminatedEvaluation`.

#### 1b — the matcher

The sequence and commutative matchers (§4.5.3 steps 2–3, §4.5.4), side conditions through the
kernel (§4.5.2), and `Builtins.Pattern`.

**Done when** Krebber's commutative examples match exactly as the source says — including the one
with six candidate mappings and exactly one match — and §4.5.4's `{g[x_], x_, y_}` against
`{g[1], g[2], 2}` finds `x = 2, y = g[1]`.

- Tests: the `Pattern` rows of §7.3 in full, with `genPattern` over `Orderless` heads and sequence
  variables.
- Benchmark: §8.3 in full; the discrimination-net crossover recorded (§4.5.5), and the net built only
  if it says so; allocation per match on the sequence-variable grid recorded against D11.
- Corpus: the Wolfram pages of `Builtins.Pattern` and the pattern objects (`Blank` and its
  sequences, `Condition`, `Alternatives`, `Except`, `Verbatim`, `OneIdentity`) triaged as in 1a.

#### 1c — calculus in the kernel

Pure-function application (§4.13's `Function`), `D` (§4.9), and the rest of §4.10's Stage 1 syntax:
the infix parser, `Cassini.Syntax.Pretty` and the REPL.

**Done when** `D` gets the product and chain rules right through user definitions: `D[f[x] g[x], x]`
gives both product-rule terms, and after `Derivative[1][f] = 3 #^2 &`, `D[f[x^2], x]` evaluates to
`6 x^5`. The criterion uses user-defined derivatives so that it needs neither §4.11's table nor a
built-in function; the `Function` in it is why **pure-function application gates Stage 1** — every
`Derivative` subvalue is one.

- Tests: the `Syntax` row in full; the `Calculus` row over arithmetic expressions (the elementary
  functions join with their track).
- Benchmark: §8.4's deep-`D` and `//.` rows baselined; the §8.6 workload gains parsing, printing and
  differentiation.
- Corpus: with the infix parser, Expreduce (vendored) and Mathics3 (fetched) join `cassini-corpus`
  (§7.8), and every in-scope case from either, over 1a–1c's builtins, is triaged as in 1a. The
  Wolfram pages of `D`, `Derivative` and `Function` are triaged too.

#### Track: elementary functions (§4.11–§4.12)

Waits for 1c. **Done when** Cohen's Examples 7.15–7.18 simplify to 0 and Fig. 7.9's rows reproduce as
§4.11 specifies — and, once 2a has landed, when `isZero` returns `Just True` for
`Sin[x]^2 + Cos[x]^2 - 1`.

- Tests: the `Simplify.Elementary` and `Simplify.Trig` rows of §7.3; the `Calculus` row over
  elementary expressions; the §7.2 harvest from `cohen2002_*.pdf` ch. 7.
- Benchmark: §8.4's trigonometric expansion, baselined; §8.4's expression swell on `Expand`, which is
  `Cassini.Simplify.Rational`'s `algebraicExpand` (§4.12) and so arrives with this track. **D2 closes
  here**, on that workload, not at a stage boundary.
- Corpus: every corpus's in-scope cases for `Builtins.Elementary` and `Builtins.Simplify`, triaged.
  Expect D16, D18, D19 and D20 to account for most divergence entries here; one that none of them
  explains is a finding.

#### Track: control flow, logic and numbers (§4.13–§4.15)

Waits for 1c. **Done when** its §7.3 rows pass and the regression corpus pins the behaviours §4.13
takes from prose alone (a `Return` inside `If` in a compound body; an uncaught `Return` at the top;
the uncaught-`Throw` message and its `Hold` wrapper; whether `Block` localizes attributes; whether a
pure function catches `Return`) and §4.15's infinity rows taken from memory.

`Equal` is done here over §4.8's rational-only `isZero`, and gets stronger at 2a with no change to
`Cassini.Builtins.Logic`: `(x + 1)^2 == x^2 + 2 x + 1` stays unevaluated until then, which is
§4.14's contract working, not a gap in it.

- Corpus: every corpus's in-scope cases for `Builtins.Control`, `.Logic` and `.Integer`, triaged.
  Each behaviour listed above as taken from prose alone is checked against milestone W's corpus
  where a page documents it, and a regression case that disagrees with a documented output is
  corrected, not whitelisted.

### Stage 2

#### 2a — the substrate

`Cassini.Algebra.Class`, `Poly.Uni`, `Poly.Multi`, `Poly.Convert`, GCD rungs 1–3 with content and
primitive part (§5.4), `Poly.Resultant`, squarefree decomposition (§5.5 step 1), and `isZero`'s
layers 2 and 3 (§5.6); layer 3′ lands when both 2a and the elementary track have. **With their
builtins**: `PolynomialGCD`, `Cancel`, `Together`, `Resultant`, `Discriminant`, `Coefficient`,
`Exponent`, `Variables` and `FactorSquareFree`, in the result forms §6.5 fixes. A stage whose work
reaches a user only a stage later has no user-visible way to be wrong in the meantime.

**Done when** multivariate GCD and content/primitive part are correct on non-trivial inputs — the
worked examples of `geddes_czapor_labahn1992_*.pdf` ch. 7 as unit tests — and `isZero` never returns
`Just` wrongly; visibly, `Cancel[(x^2 - 1)/(x - 1)]` is `1 + x` and `(x + 1)^2 == x^2 + 2 x + 1` is
`True`.

- Tests: the `Algebra`, `Poly`, `Poly.Multi` and `Zero` rows of §7.3, including GCD-ladder agreement
  over rungs 1–3, which is what makes rungs 4 and 5 safe to add.
- Benchmark: §8.5 over rungs 1–3, against `poly`'s own operations; D1 checked against the profile;
  the §8.6 workload gains polynomial arithmetic.
- The oracle gains SymPy.
- Corpus: SymPy's generated cases for GCD, `Cancel`, `Together`, resultants and squarefree
  decomposition vendored (§7.8); they and the Wolfram pages of this milestone's builtins are
  triaged.

#### 2b — modular methods and factorization

GCD rungs 4–5 (§5.4), and factorization over ℤ (§5.5 steps 2–4), with `Factor`, `Factor[…, Modulus
-> p]` and `Apart`. Multivariate factorization (§5.5's last paragraph) is a follow-on, not gating.

**Done when** `Factor` over ℤ[x] multiplies back and returns every factor unchanged when factoring it
again, and rungs 4–5 return associates of rung 3's answers.

**Stopping after §5.5 steps 1–2 is allowed, and is a decision**, recorded in this section with
integer `Factor` limited to the rational-root interim — §5.5 says why that prefix is where the
schedule slips.

- Tests: the `Poly.Factor` row of §7.3; the `Poly` rows over all five rungs.
- Benchmark: §8.5 across the ladder, with the subresultant/modular crossover recorded for the
  dispatcher; factorization at size in `cassini-slow`.
- Corpus: SymPy's generated factorization cases and the Wolfram pages of `Factor` and `Apart`,
  triaged.

### Stage 3

**Deliberately partial.** Four independent milestones, each worth reaching alone, in the order
recommended: cheapest first, and each after the one whose machinery it reuses. None gates another
except as stated.

#### 3a — Gosper (§6.3)

Waits for 2a. **Done when** `Cassini.Summation.Gosper` reproduces the worked examples of
`petkovsek_wilf_zeilberger1996_*.pdf`'s Gosper chapter, including those with no hypergeometric
antidifference, and its `Summation` row passes. This is the library milestone: the `Sum` surface
form for a symbolic bound needs `Pochhammer`/`Gamma`, and so fires D21.

#### 3b — rational integration (§6.2 tier 2)

Waits for 2a. `integrateRational`, `RootSum` (§6.5) with `D` distributing over it, and `Integrate`
dispatching to it. **Done when** `integrateRational` is complete for rational functions, verified by
the `Integrate` row (`D ∘ ∫ ≡ id`) over generated rational functions and by Bronstein ch. 2's worked
examples. `RootSum` resolves to explicit logarithms only as far as factorization over ℚ reaches:
the rational-root interim before 2b, full `Factor` after. The rational integrands of the Rubi test
suite's independent suites (§7.8) are all solved, each checked by `D ∘ ∫ ≡ id`: a complete
algorithm has no excuse on a problem in its class.

#### 3c — the tier-1 rule set (§6.2 tier 1)

Waits for 1b and the elementary track. **Done when** `Cassini.Integrate.Rules` solves a committed
problem list — **written before the rules**, drawn from the Rubi test suite (§7.8) for the
families §6.2 names — with each answer checked by `D ∘ ∫ ≡ id` in `cassini-slow`. The number solved
is the recorded number; conditional answers such as `∫xⁿ` wait on D22.

#### 3d — side relations (§6.1)

Buchberger, `GroebnerBasis` and `PolynomialReduce`. Waits for 2a. **Done when**
`PolynomialReduce[x^2 + y^2 + x, {x^2 + y^2 - 1}, {x, y}]` gives quotients `{1}` and remainder
`x + 1`, Cohen ch. 8's worked examples of simplification with side relations reproduce, and the
`Groebner` row passes. Reaching `Simplify` itself waits on D17.

- Benchmark: §8.5's Gröbner ideals in `cassini-slow`, with their timeout. The oracle gains Singular.
- Corpus: the Wolfram pages of `GroebnerBasis` and `PolynomialReduce`, triaged. Basis order and
  normalization follow WL's documented outputs or carry a divergence entry.

#### Tracks

None of these is on the critical path (§6.4); each has a criterion so that "done" is not a feeling.

| Track | Waits for | Done when |
| :--- | :--- | :--- |
| Zeilberger (§6.3) | 3a | the worked examples of the source's Zeilberger chapter, each certificate verified |
| F4 (§6.1) | 3d | its reduced bases equal Buchberger's on §8.5's ideals; the Buchberger/F4 ratio recorded |
| `Solve` (§6.4) | 2a; 3d for polynomial systems | every returned solution, substituted back, makes each equation's difference `isZero`-`Just True` |
| `Series` (§6.4) | 2a; the elementary track for elementary functions | coefficients agree with repeated `D` at the expansion point, over arithmetic and elementary functions |
| `Limit` (§6.4) | `Series` | every value it returns agrees with the test evaluator approaching the point; anything else stays unevaluated |
| Transcendental Risch (§6.2 tier 3) | 3b | `bronstein2005_*.pdf` ch. 5–6's worked examples; `D ∘ ∫ ≡ id` on every result; `NotElementary` on the source's non-elementary examples — whose answers, such as `Erf`, fire D21 |

The algebraic case of Risch is not a milestone at all (§6.2).

---

## 11. Appendix

### 11.1 Dependency budget

Boring and maintained over clever and abandoned. Every dependency is here because a decision in this
document requires it.

| Package | For | Layer |
| :--- | :--- | :--- |
| `relude` | the prelude (§2.3) | all |
| `effectful-core` | the kernel effect and its interpreters (§4.3). The core package, not `effectful`: everything used (dynamic dispatch, static `Reader`, `State` and `Error`) is in it | L2+ |
| `effectful-th` | the kernel effect's operations, generated by `makeEffect` (§4.3); brings `template-haskell` and `th-abstraction` | L2 |
| `text`, `vector`, `containers`, `unordered-containers`, `hashable`, `deepseq` | representation; `NFData` for benchmarks | L0–L2 |
| `logict` | matcher nondeterminism, confined to one module (§4.5.2) | L2 |
| `recursion-schemes` | traversal that rebuilds through smart constructors (§3.6) | L1 |
| `megaparsec` | surface syntax (§4.10) | L5 |
| `poly`, `semirings` | polynomial substrate and coefficient classes (§5.3) | A |
| `tasty`, `tasty-hunit`, `tasty-quickcheck`, `tasty-golden`, `tasty-bench` | §7, §8 | test |

Deliberately *not* dependencies: `enummapset`, whose `EnumMap` held the four rule tables until a
record replaced it (§4.2); `lens` (the structure operators are a dozen functions, not an optics
library); `uniplate` (§3.6); `sbv` (D10); `symengine` (FFI to a fast external core would settle the
two-layer question by outsourcing it, and this project is the exercise of not doing that);
`vector-sized`/`singletons` for type-level arity (D13), which is also why `poly`'s `sparse` flag is
off (§5.3).

Outside cabal altogether: `doctest`, an installed executable that `cabal repl --with-repl` runs
(§7.6); and the corpus tools of §7.8–§7.9, which are Python scripts, two of which need Mathics3.
None of them is a build dependency.

### 11.2 Deferred decisions

Each is a decision with a trigger, not something to rediscover. When a trigger fires, the row gets an
answer, not a deletion.

| # | Decision | Trigger to revisit |
| :--- | :--- | :--- |
| D1 | `Integer` over a custom bignum (§3.1) | milestone 2a's polynomial benchmarks (§10) showing `Integer` overhead dominating |
| D2 | Interning on or off (§3.4). **Provisionally off, 2026-10-04**, on §8.2's proxy (GHC 9.12.4, plain `cabal bench` as §8.1 requires, one developer machine; figures from `bench/baseline/ghc-9.12.4-{hash,intern}.csv` as regenerated 2026-10-06). The weak table loses the gate on both counts. For the `(a+b+c+d)^30` swell, hash-only takes 26 ms and allocates 31 MiB, and the table takes 36 ms and allocates 70 MiB. The table wins residency, with peak memory of 16 MiB against 82 MiB over the whole run, and it wins equality of equal terms built apart, 2.5 ns against 784 µs on a depth-14 tree. It also builds that tree in about the same time and deep-`substitute`s it in under 60% of the time, but it allocates about twice as much doing either. Most of the table's allocation is one `IORef`, one `Weak` and one `HashMap` path copy per new node. | decided when the elementary-functions track (§10) brings §8.4's `Expand`, with the numbers recorded here |
| D3 | `recursion-schemes` over `uniplate` (§3.6) | traversal showing up in the §8.4 profile |
| D4 | QuickCheck over Hedgehog (§7.3) | shrinking quality becoming the reason counterexamples go uninvestigated |
| D5 | `poly` over Kmett's `algebra` (§5.3) | Gröbner work at Stage 3 needing the `Numeric.Domain.*` chain |
| D6 | `Effectful.State.Static.Local` over `.Shared` (§4.3) | any move toward parallel evaluation |
| D7 | Single package over multi-package (§2.1). **Answered 2026-10-09:** three packages, `cassini-prelude`, `cassini-core` and `cassini-repl`, each in its own directory under one `cabal.project`. The trigger fired early, on the frontend rather than the algebra tower: milestone 1c's interactive loop brings terminal dependencies the kernel should not carry, and the prelude, which every package needs, became a package rather than a sublibrary of one of them. Script mode stays in `cassini-core` as `Cassini.Script`, because every suite runs scripts. The common stanzas are copied per package and checked equal (§2.4) | the algebra tower's dependency footprint diverging, which makes `cassini-algebra` a fourth package (§2.1) |
| D8 | Cohen's canonical order over WL fidelity (§9.2) | oracle-suite false positives becoming the dominant failure |
| D9 | Inexact numbers absent from `Number` (§3.1) | when they are needed; the O-7 slot is reserved |
| D10 | SMT-backed zero testing not adopted (§5.6) | polynomial side conditions needing more than layer 3 decides |
| D11 | `logict` inside `MatchT` over a hand-rolled continuation type (§4.5.2, §9.2). **Measured 2026-10-10 (1b), trigger not fired:** on §8.3's sequence-variable grid allocation per match is flat at 5.0–5.5 KB from 31 to 4495 matches, and does not grow with the number of variables (§8.3's results). Most of it is the substitution map and the bindings, which any monad would build. `logict` stays | §8.3's allocation per match growing with the number of matches or the depth of backtracking on the grid, or a profile putting `LogicT`'s binds ahead of the matchers' own work |
| D12 | Single-GHC CI, pinned to `base ^>=4.21.2.0` (§2.8) | GHC 9.14 reaching a Stackage LTS, or a Hackage upload needing a wider bound; widening the bound and the matrix is one change |
| D13 | **Decided 2026-09-23:** polynomials carry their variables at runtime and every operation aligns them (§1.1, §5.2). Type-level arity is not adopted — it cannot catch same-arity mixing (ℚ[x,y] with ℚ[y,z]) — and type-level labels cannot name generalized variables | §8.5 profiles showing alignment or reindexing cost dominating |
| D14 | No evaluated-expression marker; the fixed point re-evaluates settled subterms (§4.4). A round that fires no rule, or fires a user rule, is already known to be a fixed point and is not repeated, unless step 5 moved a held argument into an unheld position. That is §4.4's bug fix for repeated messages, not the marker. The fix is partial: a built-in's result goes round again with its unevaluated siblings, so `Plus[Part[{1, 2}, 3], x, x]` emits `Part::partw` twice, where WL emits it once (found 2026-10-09 in the PR #12 review) | §8.4's fixed-point benchmark showing re-evaluation dominating; or a message repeated by a built-in's round becoming an oracle or corpus divergence |
| D15 | No numerical layer in `isZero` (§5.6) | D9 delivering interval arithmetic with certified bounds |
| D16 | No `Sin[x]/Cos[x] → Tan[x]` in automatic evaluation, unlike WL: it would undo `Trig_substitute` inside `Simplify` (§4.11) | wanting WL's `Tan` spelling in output — answered first by a rewrite in `Cassini.Syntax.Pretty`, not by an evaluation rule |
| D17 | `Simplify` is Cohen's `Simplify_trig`, one fixed strategy, not WL's search under a complexity measure (§4.12) | a second strategy existing — Gröbner side relations (§6.1), or Cohen's `Simplify_exp` (`cohen2002_*.pdf` §7.2 Exercise 4) — so that choosing between them needs a measure |
| D18 | Identities that hold only over ℝ are not applied: log expansion and contraction, `Log[E^x] → x`, `(E^x)^w → E^(w·x)` for non-integer `w`, `PowerExpand` (§4.11) | an assumptions mechanism that can state "`x` is real" |
| D19 | No `TrigToExp`/`ExpToTrig`, and no `E^(I π) → -1` (§4.12) | exact complex numbers in `Number` (§3.1), a neighbour of D9 |
| D20 | No complex numbers: `I` is a symbol, and `Re`, `Im`, `Conjugate`, `Arg` and `DirectedInfinity` directions other than `±1` are absent. The open choice is a Gaussian-rational `Number` constructor versus symbolic `I` with `I^2 → -1` | D19's trigger; or `Solve` needing the roots of a quadratic with negative discriminant |
| D21 | No special functions beyond §4.11: `Gamma`, `Pochhammer`, `Erf`, `Ei`, `PolyLog` absent. The inverse hyperbolic functions (`ArcSinh` … `ArcCsch`) are elementary but absent too; they would join §4.11 by its pattern | Gosper (§6.3) landing — its closed forms need `Pochhammer`/`Gamma` first; transcendental Risch (§6.2) proving a result non-elementary, where `Erf`/`Ei` would be the answer |
| D22 | No conditional results (`ConditionalExpression`, `Piecewise`): a generic answer is returned, e.g. `∫xⁿ` assumes `n ≠ -1` | tier-1 integration rules (§6.2) or `Solve` (§6.5) needing to report a case split rather than drop it |
| D23 | **Answered 2026-09-25:** `Return` is `UReturn`, caught by the innermost loop or user-rule application, per `wolfram_ref_return.html` (§4.13) | the regression case for `Return` inside `If` in a compound body disagreeing with §4.13 |
| D24 | Radical normalization extracts prime-power factors, and merges coefficients, only for primes below a bound `B`, and does not split radicands with two or more distinct prime factors (§4.15), so it is canonical only for radicands that are a prime below `B` or a power of one | an oracle (§7.5) or zero-test case failing because two spellings of one radical survived |
| D25 | Infinities absorb only numbers: `x + Infinity` stays a sum, where WL gives `Infinity` (`wolfram_ref_directedinfinity.html`), because `x` may itself be infinite (§4.15, §4.8). The unabsorbed terms are guarded against Cohen's cancellations, which would otherwise assume them finite; one case, an infinity-bearing base under non-numeric exponents, is left unmerged (§4.15) | an assumptions mechanism that can state "`x` is finite" (with D18's), or oracle comparisons (§7.5) where the whitelist entry dominates |
| D26 | Imported corpora are vendored only when permissively licensed and small enough to commit; any other corpus is fetched at a pinned commit, and the repository holds only its case IDs (§7.8) | a corpus's licence changing; or the test suites being shipped in a package, where fetched corpora must stay optional |
| D27 | **First run 2026-09-28.** The corpus comes from the documentation notebooks that come with a Mathematica licence (here the 14.1 offline documentation installer), read by `corpus/tools/extract_wolfram_docs.py` with no Wolfram kernel; Mathics3 10.0.1 parses and normalizes in its place (§7.9). It is never scraped from `reference.wolfram.com` and never committed. The run confirmed §7.9's reading of the notebooks and recorded, from Mathematica 14.1's documentation: 6,552 built-in symbol pages, 111,806 examples, 240,983 inputs and 199,497 outputs. Of these, 90,137 examples have every input usable, and 85,555 outputs are usable; most of the loss is graphics, which is out of scope anyway. The five-second limit makes the output count vary by a few between runs | written permission from Wolfram, which would allow a shared copy; a change to either held terms page; a normalizer defect found in triage (§7.9); a new documentation version, which re-runs the extractor and records its counts here. **Trigger fired 2026-10-09 (1a triage):** the extractor writes a message symbol as the notebook displays it (`\[Infinity]::indet`). `cassini-corpus`'s adapter translates it, and the extractor is fixed at the next documentation run, which re-runs it anyway. **Fired again 2026-10-09 (1a triage, after the attribute names became `System`` symbols):** the normalizer evaluated arithmetic held by an attribute the example set on its own symbol, so `SetAttributes[h, HoldFirst]; h[1+1, 2+2, 3+3]` was expected as `h[2, 4, 6]`. Fixed in the extractor (§7.9 step 6) and re-run over the same 14.1 notebooks, under Mathics3 10.0.1 and CPython 3.14: 38,160 examples ok and 85,558 usable outputs (from 38,157 and 85,555). Of the 29 changed files, 13 are that fix (the `Hold*`, `NHold*`, `SetAttributes`, `MapApply`, `ComapApply`, `Complex` and `Rational` pages), and 16 are run-to-run variation: three outputs that timed out before, memory addresses or a version string in eleven garbage outputs, and two `Plus` terms ordered differently by the new Python |
| D28 | `structural` (O-T) recurs through `compareCanonical`, so each level re-runs `cohen` over a child its parent's `cohen` has just walked (§3.5). Two distinct terms that Cohen's rules call equal, differing d levels down, cost O(n·d), not O(n). Only unsimplified terms reach O-T. The likely fix keeps the relation: O-T has already checked equal kind and arity, and for those every kind's rule compares all child pairs, so a parent's `EQ` means every child pair is Cohen-equal and O-T can recur into `structural` directly. That needs the invariant stated in `Cassini.Core.Order` and a property checking the two versions agree | `compareCanonical` prominent in a §8.4 profile, or deep unsimplified terms in matching or `Orderless` sorting |
| D29 | A rational number does not distribute over a sum. `2·(a + b)` and `-(c + d)` stay as products, as Cohen's ASAE has them (ASAE-4 admits a sum among the factors). WL distributes: `a + b - (c + d)` evaluates to `a + b - c - d`. Distributing would put an expansion rule into automatic simplification, which §4.6 keeps to exactly Cohen's operators. Expansion is `Expand`'s job (§4.12) | `Expand` arriving with the elementary-functions track, when the two normal forms can be compared on real workloads; or this entry's corpus and oracle divergences becoming the dominant kind |
| D30 | The recursion limit cuts in place, as `Hold[e]`, and evaluation continues outward (§4.3). WL 14.1 replaces the runaway evaluation whole with `TerminatedEvaluation["RecursionLimit"]` (`wolfram/$RecursionLimit/BasicExamples/1`, `PropertiesAndRelations/1`). The corpus shows the result but not the rule that decides which evaluation is replaced. Mathics3 aborts the input. The in-place cut also emits `$RecursionLimit::reclim` twice for one runaway evaluation: `r[n_] := r[n + 1]; Length[{r[1]}]` gives `1` with the message once where step 3 cuts the argument and again where the rule's right-hand side is cut. WL emits it once. How many messages there are follows from which evaluation is replaced, so it is fixed with the unwinding rule, not before it (found 2026-10-09 in the PR #12 review) | an oracle or corpus case that pins down which enclosing evaluation WL replaces; or `Block` (§4.13), whose own example ends in `TerminatedEvaluation`, needing the same unwinding |
| D31 | With tracing off, steps 2–9 still call `traceStep` and build the expression it would record. The handler drops it, but the effect call and the expression are paid for, on every `Flat` and `Orderless` node among others. Equality tests that guard some of these calls are not the cost: `Eq Expr` answers from the pointer, intern id or hash. Measured 2026-10-09 (GHC 9.12.4, hash interning, one developer machine): reading the flag once a round in `fixpoint` and carrying it on `Node` saves 0.7% of the end-to-end workload's allocation and 0.8–2.2% on the fixed-point benchmarks, with time inside the noise. A no-op `traceStep` bounds the saving at 1.5% and 3.6–6.4%. Gating the traces where rules fire saved nothing more. Not taken, for a change that small, because it means regenerating both allocation baselines | the evaluation sequence prominent in a §8.4 profile, or a benchmark baseline regenerated for another reason, when the change can ride along |
| D32 | Steps 10–13 recompute, rung by rung, what the node already has (§4.2). Both upvalue rungs (10 and 11) collect the arguments' tag symbols and look each one up, and both downvalue rungs (12 and 13) look up the head symbol that step 2 already looked up for its attributes. For k tagged arguments that is about 2k+2 extra effect calls and symbol-table lookups per node per round, on the hottest path. Collecting the tags once per round and carrying the head's `SymbolInfo` on `Node` would remove them. Not measured. Not taken in the PR #12 review (2026-10-09), for D31's reason: it changes allocation, so it means regenerating both baselines | as D31's, and taken with it |

### 11.3 Provenance

The research is `notes/cas-haskell.md`, with its bibliography in `notes/cas-haskell-bibliography.md`
and the documents in `references/`; per §0.3 this document cites them by path and does not restate
facts about them. The corpus is gitignored, so a fresh clone has the indexes and none of the
documents: `references/downloaded-references-summary.md`'s Source column is how to re-fetch them,
and `references/CLAUDE.md` holds the corpus rules, including which copies have OCR defects that make
`grep` lie in both directions.
