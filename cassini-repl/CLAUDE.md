# cassini-repl

The `cassini` executable (`DESIGN.md` §4.10). For now `app/Main.hs` is script mode only:
`--script FILE` reads FullForm, one input per line, and writes FullForm, and `--trace FILE` adds the
evaluation steps. Both call `Cassini.Script` in cassini-core.

- **The package exists for the frontend's dependencies** (D7). The 1c interactive loop's terminal
  dependencies (line editing, history) go in this `.cabal`, never in cassini-core's. A dependency
  that core also needs goes in core.
- **`Cassini.REPL` is reserved for the 1c interactive loop**, in this package. It is L5: the
  `.hlint.yaml` rules already name it beside `Cassini.Script`, so it may import anything L5 may.
- **Script mode stays in core.** The test suites, the oracle, the corpus and the benchmarks all run
  scripts, so `runScript`, `traceScript` and `resolveName` don't move here.

Run it from the root: `cabal run cassini -- --script FILE` (or `--trace FILE`).
