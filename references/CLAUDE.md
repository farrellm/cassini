# references/

The local document corpus for the CAS-in-Haskell project. **56 files, ~395 MB.**

Read [`../notes/cas-haskell-bibliography.md`](../notes/cas-haskell-bibliography.md) and
[`../notes/cas-haskell.md`](../notes/cas-haskell.md) for *what to read and why* — the annotated
reading list, the difficulty ratings, and the staged build plan. Come here for *the files*.

[`downloaded-references-summary.md`](./downloaded-references-summary.md) is the index: every file,
its citation, its provenance URL, page count, and size. **It is the authority on what exists here.**

## Layout

| Directory | Contents |
| :--- | :--- |
| `papers/textbooks/` | The CAS canon — Cohen I/II, Geddes, von zur Gathen & Gerhard, Bronstein, A=B, Zippel, Davenport, plus Axiom Vol. 0 and the literate volumes |
| `papers/term-rewriting/` | Baader & Nipkow, Terese, Klop, the Abramsky handbook, the Rascal paper |
| `papers/foundations/` | Richardson's undecidability result; Swierstra and Bahr on composing data types |
| `papers/pattern-matching/` | Krebber's thesis and MatchPy, AC discrimination nets, the two SMP papers |
| `papers/cas-architecture/` | SymPy, GiNaC, Fateman on Mathematica/MockMMA, the Rubi and Symbolica writeups, a CAS-scoping thesis |
| `papers/haskell/` | Ishii's typed CAS, Zhu on hash consing, numeric-prelude, Olah's HaskSymb |
| `papers/wolfram-language/` | The Wolfram evaluation/attributes/values documentation — the behavioral spec to implement against |
| `papers/web-articles/` | Blog posts and course sites: opinion and build-logs, not specifications |

Each directory has its own `CLAUDE.md` with a per-file annotation saying what to read it *for*.

## Conventions

- Filenames: `author####_slug.ext`, lowercase, underscores. Multiple authors get the first two or
  three joined by `_` (`geddes_czapor_labahn1992_…`). Authorless web sources use a site or product
  prefix instead (`wolfram_ref_…`, `axiom_bookvol…`, `symbolica_…`).
- PDFs are the published version wherever one exists.
- `.html` files are single-file `curl` captures of the live page, fetched **2026-08-29**. They have
  no CSS and no images, but the full text is present — read them with `sed -e 's/<[^>]*>/ /g'` or
  `pandoc -t plain`, not by eye.
- `.pamphlet` files are Axiom's literate LaTeX+SPAD sources; plain text, readable directly.

## Rules

1. **Adding, moving, or deleting a file means updating `downloaded-references-summary.md` and the
   directory's `CLAUDE.md` in the same change.** A stale index is worse than no index.
2. If a cited source cannot be obtained, record it in the summary's "Not obtained" table with the URL
   tried and the reason. Never let a gap disappear silently.
3. Binaries here are **gitignored** (see `.gitignore`: `references/**/*.{pdf,html,pamphlet}`); only
   the `.md` files are tracked. A fresh clone gets the index but not the corpus — the summary's
   Source column is how to re-fetch it.
4. Provenance: several textbook PDFs came from Libgen and several papers from Sci-Hub. The
   bibliography's "Availability at a Glance" section marks which titles are in print and purchasable.
