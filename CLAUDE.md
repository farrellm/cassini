# cassini

A computer algebra system for Haskell: a Wolfram-Language-style term rewriting kernel over an exact
numeric and polynomial substrate.

**Stage 0 is built**: exact numbers, symbols, `Expr` with switchable interning, canonical order,
traversal and structural operators, under the tooling that enforces the rules below. Stage 1, the
evaluator, is next. [`DESIGN.md`](./DESIGN.md) is the architecture, and it is ahead of the code.
Where the two disagree, the design is the intent and the code is behind.

| Path | What it is |
| :--- | :--- |
| [`DESIGN.md`](./DESIGN.md) | The architecture: module boundaries, types, the evaluation contract, the test and benchmark plans. **Start here.** |
| [`notes/`](./notes/) | The reading-and-building guide and its bibliography. Has its own `CLAUDE.md` with strict editing rules. |
| [`references/`](./references/) | The document corpus the notes cite, indexed, with per-file defect annotations; its totals are in `references/CLAUDE.md`. Gitignored; see rule 6. |
| `cassini.cabal` | Package definition. GHC2024, `base ^>=4.21.2.0`. |
| `src/`, `src-intern/` | The library. `src-intern/{hash,weak}` are the two implementations of `Cassini.Core.Intern`, selected by the `intern` flag (§3.4). |
| `prelude/` | `Cassini.Prelude`, the internal `cassini-prelude` sublibrary (§2.3). |
| `app/`, `test/`, `bench/` | The executable (a stub until the REPL), the fast suite `cassini-test`, and `cassini-bench` with its committed baselines (§7, §8). |
| `lint/`, `scripts/`, `.hlint.yaml` | The §2.6 layering rules, their fixtures and checker, and the Haddock coverage floor. |
| `.github/workflows/ci.yml` | CI, §2.8 steps 1–7. |
| `corpus/` | Imported test corpora (`DESIGN.md` §7.8–§7.9). So far only `tools/extract_wolfram_docs.py`; `fetched/` and `wolfram-docs/` are gitignored. |
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
   - The warning set (§2.4) is not relaxed per module, and CI builds with `-Werror`. That includes
     `-Worphans`: an instance goes with its type, through an `hs-boot` import if a cycle is in the
     way, as `Cassini.Core.Expr.Internal` does (§3.4, §3.6).
   - Extensions are declared per module, except `OverloadedRecordDot` and `OverloadedStrings`, which
     are project-wide in a `common extensions` stanza. Never re-declare those two or anything
     GHC2024 already has; a redundant pragma is invisible noise.
   - **Record dot syntax is preferred**: `s.symName`, not `symName s`. Prefix selector application
     wants a reason (composition, passing the selector as a function, a section).
   - `ormolu` and `hlint`, both checked in CI. Ormolu has no style config, and that is the point.
     It reads `default-extensions` from the cabal file, so **never pass `--no-cabal`**: without it
     ormolu rewrites `r.field` to `r . field`. hlint does not read the cabal file at all, so
     `.hlint.yaml` passes those extensions itself. Without them hlint suggests `f x . field` for
     `(f x).field` (§2.5).
   - **Module layering is a lint rule, not a convention** (§2.6). Imports go down the layer stack;
     `.hlint.yaml` fails a violation, and `lint/check-layering.sh` checks the rules themselves.

   Two traps already found, so they are not rediscovered:

   - **relude re-exports mtl's `State`/`Reader` vocabulary** (`get`, `put`, `ask`, `local`, …), which
     collides name-for-name with `effectful`. Resolved once in `Cassini.Prelude` by subtraction, not
     per module by qualification; the same subtraction removes relude's `one` and `Undefined`, and
     the list will grow (§2.3). relude also withholds `unsafePerformIO`, which is a feature:
     `grep -rl System.IO.Unsafe src src-intern` finds the symbol table and the two intern tables,
     and that is a complete audit of the unsafety in the tree.
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
   - A unit test lifted from a source cites where it came from (§7.2). Edge-case and bug tests
     are welcome too, with no citation; their name says what contract they check.
   - Benchmark baselines are committed per GHC version and `intern` setting, and regenerated
     deliberately, with the commit message saying why. From milestone 1a, an allocation regression
     fails CI (`bench/check-allocation.py`). Time is gated only against a baseline from the same CI
     runner class (§8.6).

6. **The corpus is gitignored.** `references/**/*.{pdf,html,pamphlet}` are not in git, and neither
   are the `*.txt` OCR sidecars for the two image-only PDFs, which are the only way to `grep` those
   two; regenerate them after a fetch (`references/missing-documents.md`, "Regenerating the
   sidecars"). A fresh clone gets the `.md` indexes and none of the documents. That is expected,
   not a broken checkout.
   `references/downloaded-references-summary.md`'s Source column is how to re-fetch it, and
   `references/CLAUDE.md` carries the corpus rules, including which held copies have OCR defects
   that make `grep` lie in both directions.

   **Two test corpora are never committed either** (`DESIGN.md` §7.8–§7.9, D26–D27):
   `corpus/fetched/`, cloned at pinned commits by `corpus/fetch.sh`, and `corpus/wolfram-docs/`,
   extracted by `corpus/tools/extract_wolfram_docs.py` from the documentation notebooks that come
   with a Mathematica licence. Wolfram's terms forbid scraping
   `reference.wolfram.com`, so do not add a scraper, and do not commit an extracted case: only case
   IDs go in git.

## Toolchain

GHC 9.12.4, cabal 3.16.1.0, `default-language: GHC2024`. Installed locally: `ormolu` 0.8.0.2,
`hlint` 3.10, and `doctest` 0.25.0 (`cabal install doctest`). CI pins the same versions.

CI (`.github/workflows/ci.yml`) runs `DESIGN.md` §2.8 steps 1–7 on every push and PR. Step 8, the
§8.6 benchmark gate, arrives with milestone 1a. To run the same checks by hand:

- Build, with CI's warnings: `cabal build all --enable-tests --enable-benchmarks --ghc-options=-Werror`
- Tests: `cabal test cassini-test`, and again with `-f intern` for the weak intern table
- Doctests: `cabal repl --with-repl=doctest --repl-options=-Wno-missing-export-lists lib:cassini`.
  This is not a test suite, because an executable cannot see the `mixins` renaming (§7.6), and
  `--with-compiler=doctest` does not work either.
- Lint: `hlint --ignore-glob='lint/fixtures/**' .` and `lint/check-layering.sh`
- Format: `ormolu --mode check $(git ls-files '*.hs')`
- Haddock floor: `cabal haddock lib:cassini 2>&1 | python3 scripts/check-haddock.py`
- Benchmarks: `cabal bench --benchmark-options='--csv out.csv'`. Compare allocation with
  `python3 bench/check-allocation.py bench/baseline/ghc-9.12.4-hash.csv out.csv`, or against
  `-intern.csv` after a `-f intern` run.
- The Wolfram documentation corpus (milestone W, `DESIGN.md` §7.9):
  `python corpus/tools/extract_wolfram_docs.py <notebook-dir> corpus/wolfram-docs`, in a Python
  environment with `Mathics3` installed. It takes about ten minutes on eight cores.

Two cabal behaviours to know. cabal accepts an undeclared `-f` flag silently, so a misspelt
`-f intren` tests nothing. And `-Wunused-packages` is deliberately absent from the warning set:
under the mixins prelude it reports false positives, and `-Werror` would fail the build (§2.4).
