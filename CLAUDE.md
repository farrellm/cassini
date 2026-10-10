# cassini

A computer algebra system for Haskell: a Wolfram-Language-style term rewriting kernel over an exact
numeric and polynomial substrate.

**Stage 0 and milestone 1a are built.** Stage 0 is the foundations: exact numbers, symbols, `Expr`
with switchable interning, canonical order, traversal and structural operators, under the tooling
that enforces the rules below. 1a is the evaluator: attributes, the rule tables, the `Kernel` effect,
the standard evaluation sequence, the syntactic matcher, Cohen's automatic simplification, the
arithmetic, structural and assignment builtins, FullForm and script mode. Milestone 1b, the
sequence and commutative matchers, is next. [`DESIGN.md`](./DESIGN.md) is the architecture, and it is ahead of the code.
Where the two disagree, the design is the intent and the code is behind.

Three packages under one `cabal.project` (`DESIGN.md` §2.1, D7). Each has its own `CLAUDE.md`
with its paths, commands and local traps:

| Package | What it is |
| :--- | :--- |
| [`cassini-prelude/`](./cassini-prelude/CLAUDE.md) | `Cassini.Prelude`: relude minus the collisions (§2.3). |
| [`cassini-core/`](./cassini-core/CLAUDE.md) | The library, L0–L5 including script mode; the `intern` flag; every test suite, the corpora, the oracle and the benchmarks. |
| [`cassini-repl/`](./cassini-repl/CLAUDE.md) | The `cassini` executable; the interactive loop from milestone 1c. |

What spans packages stays at the root:

| Path | What it is |
| :--- | :--- |
| [`DESIGN.md`](./DESIGN.md) | The architecture: module boundaries, types, the evaluation contract, the test and benchmark plans. **Start here.** Its paths under `src/`, `test/`, `bench/`, `corpus/` and `oracle/` are relative to `cassini-core/`. |
| [`notes/`](./notes/) | The reading-and-building guide and its bibliography. Has its own `CLAUDE.md` with strict editing rules. |
| [`references/`](./references/) | The document corpus the notes cite, indexed, with per-file defect annotations; its totals are in `references/CLAUDE.md`. Gitignored; see rule 6. |
| `cabal.project` | Lists the three packages. GHC2024, `base ^>=4.21.2.0`. |
| `lint/`, `scripts/`, `.hlint.yaml` | The §2.6 layering rules, their fixtures and checker; the Haddock coverage floor; the common-stanza check. |
| `.github/workflows/ci.yml` | CI, §2.8 steps 1–8. |
| `README.md`, `CHANGELOG.md`, `LICENSE` | Boilerplate, one copy for the project; each package's `LICENSE` is a symlink to the root's. The changelog is written as changes land, not at release. |

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

   - **`relude` is the prelude**, through cabal `mixins` from the `cassini-prelude` package. The
     wiring and the names subtracted are in [`cassini-prelude/CLAUDE.md`](./cassini-prelude/CLAUDE.md).
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
   - **The `common warnings` and `common extensions` stanzas are copied into every package's
     `.cabal`**, because cabal cannot import a stanza across files and ormolu reads each package's
     own. Change all three together; `scripts/check-common-stanzas.sh` fails CI if they differ.
   - **Record dot syntax is preferred**: `s.symName`, not `symName s`. Prefix selector application
     wants a reason (composition, passing the selector as a function, a section).
   - `ormolu` and `hlint`, both checked in CI. Ormolu has no style config, and that is the point.
     It reads `default-extensions` from the nearest `.cabal` file, so **never pass `--no-cabal`**:
     without it ormolu rewrites `r.field` to `r . field`. hlint does not read the cabal file at all,
     so `.hlint.yaml` passes those extensions itself. Without them hlint suggests `f x . field` for
     `(f x).field` (§2.5).
   - **Module layering is a lint rule, not a convention** (§2.6). Imports go down the layer stack;
     `.hlint.yaml` fails a violation, and `lint/check-layering.sh` checks the rules themselves. The
     rules are by module name, so they span packages: L5 is `Cassini.Script` in cassini-core and
     `Cassini.REPL` in cassini-repl.

4. **A module implementing a published algorithm names its source in the module header.** The form
   is in [`cassini-core/CLAUDE.md`](./cassini-core/CLAUDE.md). It ties the code to the corpus that
   justified it, and makes `DESIGN.md`'s citations checkable from the other end.

5. **Test and benchmark discipline** (§7, §8). The mechanics are cassini-core's; these hold everywhere.

   - **Every fixed bug adds a numbered regression case in `cassini-core/test/regress/`, in the same
     commit as the fix.** The evaluation step order, the four-way rule ladder and the matcher's phase
     order are all things a plausible-looking refactor breaks silently.
   - **Goldens are read before they are accepted.** `--accept` makes it trivial to enshrine a bug;
     a person reads the diff, and the commit message says why the new output is right.
   - A fix commit adds its `CHANGELOG.md` line in the same commit.
   - Benchmark baselines are regenerated deliberately, with the commit message saying why. From
     milestone 1a, an allocation regression fails CI.

6. **The corpus is gitignored.** `references/**/*.{pdf,html,pamphlet}` are not in git, and neither
   are the `*.txt` OCR sidecars for the two image-only PDFs, which are the only way to `grep` those
   two; regenerate them after a fetch (`references/missing-documents.md`, "Regenerating the
   sidecars"). A fresh clone gets the `.md` indexes and none of the documents. That is expected,
   not a broken checkout.
   `references/downloaded-references-summary.md`'s Source column is how to re-fetch it, and
   `references/CLAUDE.md` carries the corpus rules, including which held copies have OCR defects
   that make `grep` lie in both directions.

   Two test corpora are never committed either; their rules, including the licence terms that
   forbid a scraper, are in [`cassini-core/CLAUDE.md`](./cassini-core/CLAUDE.md).

## Toolchain

GHC 9.12.4, cabal 3.16.1.0, `default-language: GHC2024`. Installed locally: `ormolu` 0.8.0.2,
`hlint` 3.10, and `doctest` 0.25.0 (`cabal install doctest`). CI pins the same versions.

CI (`.github/workflows/ci.yml`) runs `DESIGN.md` §2.8 steps 1–8 on every push and PR. From the
root, the project-wide checks are:

- Build, with CI's warnings: `cabal build all --enable-tests --enable-benchmarks --ghc-options=-Werror`,
  and again with `-f intern` for the weak intern table
- Lint: `hlint --ignore-glob='lint/fixtures/**' .`, `lint/check-layering.sh` and
  `scripts/check-common-stanzas.sh`
- Format: `ormolu --mode check $(git ls-files '*.hs')`

Tests, doctests, the Haddock floor, the corpus, the oracle and the benchmarks are cassini-core's
commands, and running the evaluator is cassini-repl's. Every cabal command runs from the root:
**the root is no package's directory, so name a target.** A bare `cabal bench` or `cabal test` there
fails with *no package in the current directory*.

Three cabal behaviours to know. **A command-line `-f intern` reaches cassini-core whatever target is
named**, because cabal applies it to every local package that declares the flag (checked in
`dist-newstyle/cache/plan.json`). **cabal accepts an undeclared `-f` flag silently**, so a misspelt
`-f intren` tests nothing. And `-Wunused-packages` is deliberately absent from the warning set:
under the mixins prelude it reports false positives, and `-Werror` would fail the build (§2.4).
