# cassini-core

The library, L0–L5 including script mode (`Cassini.Script`), and every suite that tests or
measures it (`DESIGN.md` §2.1). `DESIGN.md`'s paths under `src/`, `test/`, `bench/`, `corpus/` and
`oracle/` are relative to this directory. Cabal also runs this package's suites here, so their
relative paths (`test/regress`, `corpus/wolfram-docs`, `oracle/cases`) resolve from here too.

| Path | What it is |
| :--- | :--- |
| `cassini-core.cabal` | The library, the `intern` flag, `cassini-test`, `cassini-corpus`, `cassini-oracle` and `cassini-bench`. |
| `src/`, `src-intern/` | The library. `src-intern/{hash,weak}` are the two implementations of `Cassini.Core.Intern`, selected by the `intern` flag (§3.4). |
| `test/` | The fast suite `cassini-test`, with the regression corpus `test/regress/` and golden traces `test/trace/` (§7). |
| `test-support/` | `Test.Script`, the script-format comparison that `cassini-corpus` and `cassini-oracle` share. |
| `bench/` | `cassini-bench`, its committed baselines `bench/baseline/` and the allocation gate `bench/check-allocation.py` (§8). |
| `oracle/` | `cassini-oracle`: differential testing against Mathics3 (§7.5), with its cases, its Python side and its whitelist. |
| `corpus/` | Imported test corpora (§7.8–§7.9): the `cassini-corpus` suite, its ratchet `passing/`, its manifest `divergences.txt`, and `tools/extract_wolfram_docs.py`. `fetched/` and `wolfram-docs/` are gitignored. |

## Rules

1. **A module implementing a published algorithm names its source in the module header** (root
   rule 4):

   ```haskell
   -- | Automatic simplification of sums, products and powers.
   --
   -- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.2.
   module Cassini.Simplify.Automatic (simplify, isASAE) where
   ```

2. **The unsafety audit is one `grep`.** relude withholds `unsafePerformIO`, so
   `grep -rlE 'System.IO.Unsafe|reallyUnsafe' src src-intern`, run here, finds the symbol table,
   the two intern tables and `Eq Expr`'s pointer test. That list is a complete audit of the unsafety
   in the tree (§2.3).

3. **No `effectful` handler can enumerate matches.** `Effectful.NonDet` is `Maybe`-shaped by
   necessity, not because of an old release. So the matcher uses `LogicT` over `Eff` inside the
   `MatchT` **newtype** in `Cassini.Pattern.Match`. That is the one module the `.hlint.yaml` rule
   lets import `Control.Monad.Logic` (§4.5.2, D11). Do not replace the newtype with a synonym.

4. **Test and benchmark mechanics** (root rule 5 holds too).

   - Regression cases are named for the behaviour, not the bug:
     `0002-builtin-upvalue-beats-user-downvalue`, not `0002-issue-17`.
   - A unit test lifted from a source cites where it came from (§7.2). Edge-case and bug tests
     are welcome too, with no citation; their name says what contract they check.
   - A new regression case is also an oracle case: run `cassini-oracle` before committing it.
   - When the oracle disagrees, or is inconclusive because Mathics3 crashes, `corpus/wolfram-docs/`
     often documents WL's answer; cite that case ID in `oracle/divergences.txt` or the regression
     case's comment. Failing that, mathematica.stackexchange.com often quotes WL's real output,
     messages included; cite the question or answer URL. Search it through the Stack Exchange API
     (`api.stackexchange.com/2.3`, `site=mathematica`), not a web search engine, which barely
     indexes it. `search/excerpts` covers answers as well as questions but drops `::`, so search
     the bare tag (`pkspec1`), then fetch the hits' full bodies (`questions/{ids}` or
     `answers/{ids}`, `filter=withbody`) and grep them. If neither documents it, drop the input;
     don't pin a guess.
   - Benchmark baselines are committed per GHC version and `intern` setting. From milestone 1a, an
     allocation regression fails CI (`bench/check-allocation.py`). Time is gated only against a
     baseline from the same CI runner class (§8.6).

5. **Two test corpora are never committed** (§7.8–§7.9, D26–D27). `corpus/fetched/` is cloned at
   pinned commits by `corpus/fetch.sh`. `corpus/wolfram-docs/` is extracted by
   `corpus/tools/extract_wolfram_docs.py` from the documentation notebooks that come with a
   Mathematica licence. Wolfram's terms forbid scraping `reference.wolfram.com`, so do not add a
   scraper, and do not commit an extracted case: only case IDs go in git. Both are gitignored as
   `cassini-core/corpus/…`. A `git add -A` while the ignore pattern is wrong stages thousands of
   them, so check `git status` before committing.

## Commands

Run them from the repository root, which is no package's directory: name the target.

- Tests: `cabal test cassini-test`, and again with `-f intern` for the weak intern table.
- Doctests: `cabal repl --with-repl=doctest --repl-options=-Wno-missing-export-lists lib:cassini-core`.
  This is not a test suite, because an executable cannot see the `mixins` renaming (§7.6), and
  `--with-compiler=doctest` does not work either.
- Haddock floor: `cabal haddock lib:cassini-core 2>&1 | python3 scripts/check-haddock.py`
- Benchmarks: `cabal bench cassini-bench --benchmark-options='--csv /abs/out.csv'`. tasty-bench
  writes a relative `--csv` path into this directory, the suite's cwd, so give an absolute path.
  Compare allocation with
  `python3 cassini-core/bench/check-allocation.py cassini-core/bench/baseline/ghc-9.12.4-hash.csv /abs/out.csv`,
  or against `-intern.csv` after a `-f intern` run. CI's step 8 gates only the end-to-end workload:
  `--benchmark-options='-p EndToEnd --csv …'`, then `check-allocation.py --only All.EndToEnd`.
- The corpus ratchet: `cabal test cassini-corpus` (skips without `corpus/wolfram-docs/`). For
  triage, run its binary (`cabal list-bin cassini-corpus --enable-tests`) **from this directory**,
  with `--page NAME`, `--verbose`, and `--write-passing FILE` to diff against
  `corpus/passing/wolfram.txt`.
- The oracle: `CASSINI_MATHICS_PYTHON=$PWD/.venv/bin/python cabal test cassini-oracle`, from the
  root, with Mathics3 installed in the root's gitignored `.venv` (`.venv/bin/pip install Mathics3`).
  It skips without the variable.
- The Wolfram documentation corpus (milestone W, §7.9):
  `python cassini-core/corpus/tools/extract_wolfram_docs.py <notebook-dir> cassini-core/corpus/wolfram-docs`,
  in a Python environment with `Mathics3` installed. It takes about ten minutes on eight cores.
- Re-extracting needs the notebooks unpacked from the offline installer's `.cab` files with
  `7z x`, about 9.4 GB; `run.txt`'s `source:` line says where. For a trial run, use
  `--only Sym1,Sym2` into the scratchpad, then `diff -r`.
- A corpus `.expected` output has been normalised by Mathics3, so it isn't raw WL. When one looks
  wrong, read the notebook cell before blaming the evaluator or the extractor.
- To compare corpus failures across commits, `git worktree add` the old commit and symlink this
  directory's `corpus/wolfram-docs` into it. Before the split it went at the worktree's root
  `corpus/`. Then diff the `FAIL` lines of each binary's `--verbose` output, each run from its own
  package directory.
