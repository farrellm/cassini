# cassini-repl

The `cassini` executable (`DESIGN.md` §4.10). `app/Main.hs` starts the interactive loop,
`Cassini.REPL` in `app/Cassini/REPL.hs`, with no arguments; `--script FILE` reads FullForm, one
input per line, and writes FullForm, and `--trace FILE` adds the evaluation steps. Both call
`Cassini.Script` in cassini-core.

- **The package exists for the frontend's dependencies** (D7): `haskeline` for line editing and
  history, and `unix` for the SIGINT handler. They go in this `.cabal`, never in cassini-core's.
  A dependency that core also needs goes in core.
- **`Cassini.REPL` is the one module here**, and it is L5: the `.hlint.yaml` rules name it beside
  `Cassini.Script`, so it may import anything L5 may.
- **Script mode stays in core.** The test suites, the oracle, the corpus and the benchmarks all run
  scripts, so `runScript`, `traceScript`, `evaluateInput` and `resolveName` don't move here. The
  loop evaluates through `evaluateInput` too, so the two record history the same way.
- **Interrupts are polled, not thrown** (§4.13). The SIGINT handler only sets a flag that
  `runEvalInterruptible` polls at each evaluation step; only a second Ctrl-C, while the flag is
  still set, is thrown. Haskeline's `withInterrupt` replaces the handler while it reads a line and
  restores it after, which is what lets the two coexist.
- **Driving it from a script** (piped stdin) works: haskeline reads a file-style input. To test an
  interrupt, run it reading from a FIFO and `kill -INT` it mid-evaluation.

Run it from the root: `cabal run cassini` (or `-- --script FILE`, `-- --trace FILE`).
