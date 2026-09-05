# cassini

A computer algebra system for Haskell: a Wolfram-Language-style term rewriting kernel over an exact
numeric and polynomial substrate.

**The repository is at the design stage.** `src/` is still `cabal init` output; the research is
complete and validated, and [`DESIGN.md`](./DESIGN.md) is the architecture. Where the code and the
design disagree, the design is the intent and the code is behind.

| Path | What it is |
| :--- | :--- |
| [`DESIGN.md`](./DESIGN.md) | The architecture: module boundaries, types, the evaluation contract, and the test and benchmark plans. **Start here.** |
| [`notes/`](./notes/) | The reading-and-building guide and its bibliography — what to read, in what order, and why. Has its own `CLAUDE.md` with strict editing rules. |
| [`references/`](./references/) | The document corpus the notes cite: 87 files, indexed, with per-file defect annotations. Gitignored; see rule 6. |
| `cassini.cabal` | Package definition. GHC2024, `base ^>=4.21.2.0`. |
| `src/`, `app/`, `test/` | Library, executable, tests. Currently the `cabal init` skeleton. |
| `README.md`, `CHANGELOG.md`, `LICENSE` | Boilerplate. The changelog is written as changes land, not at release (rule 5). |

## Rules

1. **Four documentation surfaces, and each holds one kind of thing.**

   | Surface | Holds |
   | :--- | :--- |
   | `DESIGN.md` | decisions and their rationale |
   | `notes/` | what to read, in what order, and the bibliography |
   | `references/` | the documents themselves, plus the index |
   | each directory's `CLAUDE.md` | local annotations and rules for that directory |

   The rule that keeps them from entangling: **`DESIGN.md` cites sources by path and does not
   restate facts *about* them** — editions, page counts, who proved what first. Those live in
   `notes/`, where `notes/CLAUDE.md` rule 4 already tracks each one across six files. Adding a
   seventh copy adds a seventh thing to correct and a seventh thing to get silently wrong. Design
   rationale here, source provenance there.

   The exception, marked where it occurs: where a source's *content* is the design — the thirteen
   evaluation steps, the ASAE conditions, the five commutative-matching phases — it is transcribed,
   because a design that only pointed at it would not be implementable.

2. **A decision that changes changes `DESIGN.md` in the same commit.** A decision recorded only in a
   commit message is lost, and this repository's whole character is that the reasoning outlives the
   session. If an implementation departs from the design, either the design was wrong — fix it and
   say why — or the implementation is, and the departure is a bug. Silent divergence is neither.

   `DESIGN.md` §11.2 is a register of deferred decisions, each with a trigger to revisit. When a
   trigger fires, that row gets an answer and a number, not a deletion.

3. **Haskell house style, so it is not re-litigated.**

   - **`relude` is the prelude**, wired in through cabal `mixins`, not imported per module. It is
     re-exported from the internal `cassini-prelude` sublibrary minus the names that collide with
     `effectful` (see below). See `DESIGN.md` §2.3.
   - **`effectful` for the kernel** — never a bare `ReaderT Env IO`, never an mtl stack. The kernel
     is a custom dynamically dispatched effect with two interpreters, one of which has no `IOE`;
     that is what makes the evaluator testable as a pure function. See `DESIGN.md` §4.3.
   - Explicit export lists everywhere. `Internal` modules hold representations; their non-`Internal`
     siblings hold the API.
   - No partial functions. `head`, `fromJust` and `!!` are not in scope, and the places that want
     indexing return `Either` with a message — which the language semantics require anyway.
   - The warning set in `DESIGN.md` §2.4 is not relaxed per module. Extensions beyond GHC2024 are
     declared per module, never in `default-extensions`.
   - `fourmolu` and `hlint`, both checked in CI.
   - The `mixins` stanza needs the qualified `cassini:cassini-prelude` form in both
     `build-depends` and `mixins`; cabal rejects the bare sublibrary name.
   - **Module layering is a lint rule, not a convention** (`DESIGN.md` §2.6). Imports go down the
     layer stack. A `Cassini.Core.*` module importing `Cassini.Eval` fails `hlint`.

   Two collisions already found, so they are not rediscovered:

   - **relude re-exports mtl's `State`/`Reader` vocabulary** — `get`, `put`, `modify`, `gets`,
     `state`, `ask`, `asks`, `local` — which collides name-for-name with
     `Effectful.State.Static.Local` and `Effectful.Reader.Static`. Resolved once in
     `Cassini.Prelude` by subtraction, not per module by qualification. relude also takes `one`
     (a singleton-container constructor) and `Undefined` (a debug marker), both of which this
     project wants for its own meanings; the same subtraction handles them, and the list will grow.
     It withholds `unsafePerformIO`, which is a feature: the intern table's one `import
     System.IO.Unsafe` is a complete audit of the unsafety in the tree.
   - **No `effectful` handler can enumerate, and `Effectful.NonDet` is the proof.** `Eff` cannot
     capture and resume a continuation, so a handler cannot run one branch and come back for the
     next; `NonDet` is therefore `Maybe`-shaped, obeying left-catch, and `a :<|>: b` runs `b` only if
     `a` calls `Empty`. The matcher needs *every* match, so it uses a transformer over `Eff` — which
     is what `effectful`'s own README says to do. Do not go looking for a newer release that fixes
     this. The matcher's monad is the `MatchT` **newtype** in `Cassini.Pattern.Match`, the one module
     permitted to import `Control.Monad.Logic`; the fourth `.hlint.yaml` rule enforces that, and a
     transparent synonym would have made the containment a wish. `DESIGN.md` §4.5.2, §2.6, D11.

4. **A module implementing a published algorithm names its source in the module header.**

   ```haskell
   -- | Automatic simplification of sums, products and powers.
   --
   -- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.2.
   module Cassini.Simplify.Automatic (simplify, isASAE) where
   ```

   This is what ties the code to the corpus that justified it, and it makes `DESIGN.md`'s citations
   checkable from the other end. It is also how someone debugging the commutative matcher at 2am
   finds out that the phase order is not arbitrary.

5. **Test and benchmark discipline.**

   - **Every fixed bug adds a numbered regression case in `test/regress/`, in the same commit as the
     fix.** Not "when convenient". The evaluation sequence's step order, the four-way rule ladder and
     the matcher's phase order are all things a plausible-looking refactor breaks silently.
   - **Goldens are read before they are accepted.** `--accept` makes it trivially easy to enshrine a
     bug; a person looks at the diff, and the commit message says why the new output is right.
   - Regression cases are named for the behaviour, not the bug number: `0002-builtin-upvalue-beats-
     user-downvalue`, not `0002-issue-17`.
   - Unit tests are worked examples lifted from the sources, and each cites where it came from — the
     expected values were then computed by someone else, before the implementation existed.
   - Benchmark baselines are committed, per GHC version, and regenerated deliberately with the commit
     message saying why. A performance regression is a CI failure, not a memory. `DESIGN.md` §8.6.

6. **The corpus is gitignored.** `references/**/*.{pdf,html,pamphlet}` are not in git; a fresh clone
   gets the `.md` indexes and none of the ~436 MB. This is expected, not a broken checkout.
   `references/downloaded-references-summary.md`'s Source column is how to re-fetch it, and
   `references/CLAUDE.md` carries the corpus rules — including which held copies have OCR defects
   that make `grep` lie, in both directions.

## Toolchain

GHC 9.12.4, cabal 3.16.1.0, `default-language: GHC2024`. `fourmolu`, `ormolu` and `hlint` are
installed locally. `cabal build --enable-tests --enable-benchmarks all` is the full build.
