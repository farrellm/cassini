# cassini

A computer algebra system for Haskell: a Wolfram-Language-style term rewriting kernel over an exact
numeric and polynomial substrate.

**The repository is at the design stage.** `src/` is still `cabal init` output; the research is
complete and validated, and [`DESIGN.md`](./DESIGN.md) is the architecture. Where the code and the
design disagree, the design is the intent and the code is behind.

| Path | What it is |
| :--- | :--- |
| [`DESIGN.md`](./DESIGN.md) | The architecture: module boundaries, types, the evaluation contract, the test and benchmark plans. **Start here.** |
| [`notes/`](./notes/) | The reading-and-building guide and its bibliography. Has its own `CLAUDE.md` with strict editing rules. |
| [`references/`](./references/) | The document corpus the notes cite: 87 documents, indexed, with per-file defect annotations. Gitignored; see rule 6. |
| `cassini.cabal` | Package definition. GHC2024, `base ^>=4.21.2.0`. |
| `src/`, `app/`, `test/` | Library, executable, tests. Currently the `cabal init` skeleton. |
| `README.md`, `CHANGELOG.md`, `LICENSE` | Boilerplate. The changelog is written as changes land, not at release. |

## Rules

1. **Four documentation surfaces, one kind of thing each.**

   | Surface | Holds |
   | :--- | :--- |
   | `DESIGN.md` | decisions and their rationale |
   | `notes/` | what to read, in what order, and the bibliography |
   | `references/` | the documents themselves, plus the index |
   | each directory's `CLAUDE.md` | local annotations and rules for that directory |

   **`DESIGN.md` cites sources by path and does not restate facts *about* them** — editions, page
   counts, who proved what first. Those live in `notes/`, where `notes/CLAUDE.md` rule 4 tracks each
   across six files; a seventh copy is a seventh thing to get silently wrong. The exception: where a
   source's *content* is the design (the evaluation steps, the ASAE conditions, the order relation,
   the commutative-matching phases), it is transcribed, because a pointer would not be
   implementable.

   A correction to a claim *about a source* follows `notes/CLAUDE.md` rule 4 wherever it starts,
   including in a `DESIGN.md` review: fix every copy in `notes/` and `references/` in the same
   change.

2. **A decision that changes changes `DESIGN.md` in the same commit.** A decision recorded only in a
   commit message is lost. If an implementation departs from the design, either the design was wrong
   — fix it and say why — or the implementation is, and the departure is a bug. Silent divergence is
   neither.

   `DESIGN.md` §11.2 registers deferred decisions, each with a trigger. When a trigger fires, the row
   gets an answer, not a deletion. Section and D-numbers are cited from elsewhere; keep them stable.

3. **Haskell house style, so it is not re-litigated** (`DESIGN.md` §2.3–§2.6).

   - **`relude` is the prelude**, wired in through cabal `mixins` from the internal
     `cassini-prelude` sublibrary, minus the names that collide with `effectful` or with this
     project's vocabulary. The `mixins` stanza needs the qualified `cassini:cassini-prelude` form in
     both `build-depends` and `mixins`; cabal rejects the bare name.
   - **`effectful` for the kernel** — never a bare `ReaderT Env IO`, never an mtl stack. The kernel
     is a custom dynamically dispatched effect with two interpreters, one of which has no `IOE`;
     that is what makes the evaluator testable as a pure function (§4.3).
   - Explicit export lists everywhere. `Internal` modules hold representations; their non-`Internal`
     siblings hold the API.
   - No partial functions. `head`, `fromJust` and `!!` are not in scope; indexing returns `Either`
     with a message, which the language semantics require anyway.
   - The warning set (§2.4) is not relaxed per module, and CI builds with `-Werror`.
   - Extensions are declared per module, except `OverloadedRecordDot` and `OverloadedStrings`, which
     are project-wide in a `common extensions` stanza. Never re-declare those two or anything
     GHC2024 already has; a redundant pragma is invisible noise.
   - **Record dot syntax is preferred**: `s.symName`, not `symName s`. Prefix selector application
     wants a reason (composition, passing the selector as a function, a section).
   - `ormolu` and `hlint`, both checked in CI. Ormolu has no style config, and that is the point.
     It reads `default-extensions` from the cabal file, so **never pass `--no-cabal`**: without it
     ormolu rewrites `r.field` to `r . field`.
   - **Module layering is a lint rule, not a convention** (§2.6). Imports go down the layer stack;
     `.hlint.yaml` fails a violation.

   Two traps already found, so they are not rediscovered:

   - **relude re-exports mtl's `State`/`Reader` vocabulary** (`get`, `put`, `ask`, `local`, …), which
     collides name-for-name with `effectful`. Resolved once in `Cassini.Prelude` by subtraction, not
     per module by qualification; the same subtraction removes relude's `one` and `Undefined`, and
     the list will grow (§2.3). relude also withholds `unsafePerformIO`, which is a feature: the
     intern table's one `import System.IO.Unsafe` is a complete audit of the unsafety in the tree.
   - **No `effectful` handler can enumerate matches.** `Effectful.NonDet` is `Maybe`-shaped by
     necessity, not by an old release, so the matcher uses `LogicT` over `Eff` inside the `MatchT`
     **newtype** in `Cassini.Pattern.Match`, the one module the `.hlint.yaml` rule lets import
     `Control.Monad.Logic` (§4.5.2, D11). Do not replace the newtype with a synonym.

4. **A module implementing a published algorithm names its source in the module header.**

   ```haskell
   -- | Automatic simplification of sums, products and powers.
   --
   -- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.2.
   module Cassini.Simplify.Automatic (simplify, isASAE) where
   ```

   That ties the code to the corpus that justified it, and makes `DESIGN.md`'s citations checkable
   from the other end.

5. **Test and benchmark discipline** (§7, §8).

   - **Every fixed bug adds a numbered regression case in `test/regress/`, in the same commit as the
     fix.** The evaluation step order, the four-way rule ladder and the matcher's phase order are
     all things a plausible-looking refactor breaks silently.
   - **Goldens are read before they are accepted.** `--accept` makes it trivial to enshrine a bug;
     a person reads the diff, and the commit message says why the new output is right.
   - Regression cases are named for the behaviour, not the bug:
     `0002-builtin-upvalue-beats-user-downvalue`, not `0002-issue-17`.
   - Unit tests are worked examples lifted from the sources, each citing where it came from.
   - Benchmark baselines are committed per GHC version and regenerated deliberately, with the commit
     message saying why. An allocation regression fails CI; time is gated only against a baseline
     from the same CI runner class (§8.6).

6. **The corpus is gitignored.** `references/**/*.{pdf,html,pamphlet}` are not in git; a fresh
   clone gets the `.md` indexes and none of the ~436 MB. That is expected, not a broken checkout.
   `references/downloaded-references-summary.md`'s Source column is how to re-fetch it, and
   `references/CLAUDE.md` carries the corpus rules, including which held copies have OCR defects
   that make `grep` lie in both directions.

## Toolchain

GHC 9.12.4, cabal 3.16.1.0, `default-language: GHC2024`; `ormolu` and `hlint` are installed
locally.

- Full build: `cabal build --enable-tests --enable-benchmarks all`
- Fast tests: `cabal test cassini-test`, and again with `-f intern` — CI runs both interning
  settings (§3.4)
- Lint and format: `hlint .` and `ormolu --mode check $(git ls-files '*.hs')`
