# references/papers/

Eight topical directories. See [`../CLAUDE.md`](../CLAUDE.md) for conventions and rules, and
[`../downloaded-references-summary.md`](../downloaded-references-summary.md) for the full index.

## Which directory answers which question

| If you need to know… | Open |
| :--- | :--- |
| How does the evaluator sequence Hold / Flat / Orderless / Listable, and what re-evaluates to a fixed point? | `wolfram-language/wolfram_ref_evaluation.html` — "The Standard Evaluation Sequence", all 13 steps in order |
| Where do OwnValues, DownValues, UpValues, and SubValues attach, and how do I model the rule tables? | `wolfram-language/` |
| How do I make automatic simplification produce a canonical form? | `textbooks/` (**Cohen Vol. 2 ch. 3** — the algorithm is in Vol. 2, not Vol. 1) |
| How do I implement polynomial GCD, factorization, Hensel lifting, Gröbner bases, integration? | `textbooks/` (Geddes, then von zur Gathen & Gerhard, then Bronstein) |
| Is this rewrite system confluent / terminating? What is critical-pair completion? | `term-rewriting/` (Baader & Nipkow) |
| How do I match modulo associativity and commutativity, with sequence variables, fast? | `pattern-matching/` (Krebber's thesis) |
| Why can't `Simplify` be complete? | `foundations/` (Richardson 1968) |
| How is a large CAS actually laid out in modules? | `cas-architecture/` |
| How do I type the algebra layer in Haskell, and how do I share structure? | `haskell/` (Ishii, Zhu) |
| What did someone who tried this before conclude? | `web-articles/`, `haskell/olah2012_hasksymb.html` |

## Reading order for the build

The staged plan lives in `../../notes/cas-haskell.md`. In file terms:

- **Stage 0** — `textbooks/cohen2002_*` chs. 2–3 (expression trees, simplified-expression structure)
  **and `textbooks/cohen2003_*` chs. 2–3 (rational arithmetic, and the automatic-simplification
  algorithm)** + `term-rewriting/baader_nipkow1998_*` chs. 1–2 and 5–7, in parallel.
  `foundations/richardson1968_*` for the ceiling. `haskell/zhu2025_hash_consing.pdf` before
  committing to a representation.
- **Stage 1** — everything in `wolfram-language/` (the spec) +
  `pattern-matching/krebber2017_ac_matching_thesis.pdf` (the matcher).
- **Stage 2** — `textbooks/geddes_*` then `textbooks/vonzurgathen_gerhard2013_*`;
  `haskell/ishii2018_*` if the polynomial layer goes typed.
- **Stage 3** — `textbooks/cohen2003_*` chs. 5–9, `textbooks/bronstein2005_*`,
  `textbooks/petkovsek_wilf_zeilberger1996_a_eq_b.pdf`, plus `cas-architecture/rich_rubi_vision.html`
  for the rule-based alternative to Risch.

## Sizes

Four files are image-only scans with **no text layer** — `pdftotext` returns nothing and extracting
a page range silently yields an empty file:

- `term-rewriting/terese2003_*` (181 MB, 908 pp.) — no mitigation; open it in a viewer.
- `term-rewriting/abramsky1992_*` (71 MB, 582 pp.) — for the Klop chapter use
  `term-rewriting/klop1992_term_rewriting_systems.pdf` instead.
- `pattern-matching/bachmair1993_*` and `pattern-matching/eker1995_*` — both carry a generated
  `.txt` OCR sidecar beside them; grep the sidecar.

**Two traps.** `eker1995_*` *reports* text on every page, so a naive text-layer check passes it — but
the only text is a repeated download watermark, 860 characters across 19 pages; check the variety of
extracted text, not its presence. And `textbooks/karr1985_*` has a real text layer whose OCR drops
every `h`, so `grep theorem` returns nothing and looks like an honest miss.

Other large files: `axiom_bookvol10-5_numerics.pamphlet` (30 MB),
`vonzurgathen_gerhard2013_*` (25 MB, 813 pp.). Extract the page range you need
(`pdftotext -f N -l M`) rather than opening them whole.
