# references/

The local document corpus for the CAS-in-Haskell project. **85 documents, ~436 MB**, plus 2 OCR sidecars.

Read [`../notes/cas-haskell-bibliography.md`](../notes/cas-haskell-bibliography.md) and
[`../notes/cas-haskell.md`](../notes/cas-haskell.md) for *what to read and why* — the annotated
reading list, the difficulty ratings, and the staged build plan. Come here for *the files*.
[`../notes/CLAUDE.md`](../notes/CLAUDE.md) carries the rules for editing those two documents.

[`downloaded-references-summary.md`](./downloaded-references-summary.md) is the index: every file,
its citation, its provenance URL, page count, and size. **It is the authority on what exists here.**
[`missing-documents.md`](./missing-documents.md) is the counterpart: what is cited but *not* held,
what was tried, and which files are present but unreadable (image-only scans, lossy OCR).

## Layout

| Directory | Contents |
| :--- | :--- |
| `papers/textbooks/` | The CAS canon — Cohen I/II, Geddes (with the Springer page carrying its blurb), von zur Gathen & Gerhard, Bronstein, A=B, Zippel, Davenport; the three summation papers (Karr ×2, Schneider) that fill A=B's gap; and Axiom Vol. 0 in both the Springer 1992 edition and the FriCAS regeneration, plus the literate volumes |
| `papers/term-rewriting/` | Baader & Nipkow, Terese, Klop, the Abramsky handbook, the Rascal paper |
| `papers/foundations/` | Richardson's undecidability result; Swierstra and Bahr on composing data types, plus Wadler's blog verdict on the former |
| `papers/pattern-matching/` | Krebber's thesis and the two MatchPy papers; Benanav on AC-matching complexity and Eker on the algorithm; both Bachmair AC-discrimination-net papers; the two SMP papers and three volumes of the 1981 SMP manual |
| `papers/cas-architecture/` | SymPy, GiNaC, Fateman on Mathematica/MockMMA, the Rubi and Symbolica writeups (incl. Symbolica's licence and its home page in three states — current, 2023, 2025), a CAS-scoping thesis, the Expreduce and Symja READMEs, and Wikipedia's *Wolfram Language* article |
| `papers/haskell/` | Ishii's typed CAS, Zhu on hash consing, numeric-prelude and numhask, Penner and Milewski on `Fix`/`Free`, Olah's HaskSymb (post *and* README), the `poly`, `dumb-cas` and `sbv` package pages |
| `papers/wolfram-language/` | The Wolfram evaluation/attributes/values documentation — the behavioral spec to implement against |
| `papers/web-articles/` | Blog posts and course sites: opinion and build-logs, not specifications |

Each directory has its own `CLAUDE.md` with a per-file annotation saying what to read it *for*.

## Conventions

- Filenames: `author####_slug.ext`, lowercase, underscores. Multiple authors get the first two or
  three joined by `_` (`geddes_czapor_labahn1992_…`). Authorless web sources use a site or product
  prefix instead (`wolfram_ref_…`, `axiom_bookvol…`, `symbolica_…`).
- PDFs are the published version wherever one exists.
- `.html` files are single-file `curl` captures — of the live page, or of a Wayback snapshot where
  the live page is gone or bot-gated, which the summary row always says. The original **22** were
  fetched **2026-08-29**; **16** on **2026-08-30** — ten in the second validation round (the
  eight README/package/licence captures that anchor verbatim quotes, plus `pickering2014_*` and
  `sympy_docs_*`), four in the third (`symbolica_home`, `symbolica_home_2023_wayback`,
  `wikipedia_wolfram_language`, `numhask_hackage`), and two in the fourth
  (`springer_geddes_book_page`, `symbolica_home_2025_wayback`); and **1** on **2026-08-31**, in the fifth
  (`sbv_docs_data_sbv`). The summary gives the date per file. They have no
  CSS and no images, but the full text is present — read them with `sed -e 's/<[^>]*>/ /g'` or
  `pandoc -t plain`, not by eye.
- `.pamphlet` files are Axiom's literate LaTeX+SPAD sources; plain text, readable directly.

## Rules

1. **Adding, moving, or deleting a file means updating `downloaded-references-summary.md` and the
   directory's `CLAUDE.md` in the same change.** A stale index is worse than no index.
2. **Every citation in the bibliography resolves to something here — a held file, or a row in the
   summary's "Not obtained" table** with the route tried and the reason. This applies when a source
   is *added* to the bibliography, not only when a fetch fails: adding a citation without attempting
   to obtain it is how five sources ended up cited but unaccounted for. Never let a gap disappear
   silently. The "pointers only, by design" waiver for software repositories and Hackage packages
   covers *citing* a system; it does **not** cover quoting its README, package page or licence
   verbatim. A verbatim quote needs a capture, in the same change that adds the quote. Nor does it
   cover a claim *about* a page — "its README names no version", "the article says this without a
   citation", "numhask is the more recently maintained of the two". Those are assertions about a
   document's contents and go stale the same way a quote does; capture the page.
3. Binaries here are **gitignored** (see `.gitignore`: `references/**/*.{pdf,html,pamphlet}`); only
   the `.md` files are tracked. A fresh clone gets the index but not the corpus — the summary's
   Source column is how to re-fetch it.
4. Provenance: several textbook PDFs came from Libgen and several papers from Sci-Hub. The
   bibliography's "Availability at a Glance" section marks which titles are in print and purchasable.
5. **The per-file annotations here repeat claims that also live in `../notes/`.** When a claim about
   a source is corrected in either place, fix every copy in the same change — the annotation in this
   directory tree, the bibliography entry, the prose in `../notes/cas-haskell.md`, and the row in
   `downloaded-references-summary.md`. Corrections that landed in the notes and not here have had to
   be found again twice. See `../notes/CLAUDE.md` rule 4 for the grep that closes it out.
