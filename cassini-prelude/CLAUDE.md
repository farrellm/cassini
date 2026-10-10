# cassini-prelude

One module, `Cassini.Prelude`: relude, minus the names that collide with `effectful` or with this
project's vocabulary (`DESIGN.md` §2.3). Every stanza of every other package builds against it in
place of `base`'s `Prelude`.

## Wiring

Each consuming stanza carries the same two `mixins` lines, with the bare package name in both
`build-depends` and `mixins`:

```cabal
  build-depends:    base, cassini-prelude, ...
  mixins:
    base hiding (Prelude),
    cassini-prelude (Cassini.Prelude as Prelude)
```

The bare name works because this is a package. While it was an internal sublibrary of the old single
`cassini` package, cabal rejected the bare name and required `cassini:cassini-prelude`. Don't bring
that form back.

This package itself depends on `relude` alone, through `relude (Relude as Prelude)` and a bare
`relude`. It imports nothing from `base`, so it needs no `base hiding (Prelude)` (§2.3 says why each
line is there).

## Traps

- **relude re-exports mtl's `State`/`Reader` vocabulary** (`get`, `put`, `ask`, `local`, …), which
  collides name-for-name with `effectful`. That is resolved here once by subtraction, not per
  module by qualification. The same subtraction removes relude's `one` and `Undefined`, and the list
  will grow (§2.3). Where relude's meaning is unrelated to ours, subtract it here; don't rename a
  domain type to dodge it.
- **relude withholds `unsafePerformIO`, which is a feature.** It makes the unsafety audit a `grep`
  (see `cassini-core/CLAUDE.md`).
- `scripts/check-haddock.py` excludes `Cassini.Prelude`, whose exports are relude's documentation.
