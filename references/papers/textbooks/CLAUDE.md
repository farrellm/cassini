# textbooks/

The CAS algorithm canon (bibliography §1) plus the Axiom literate volumes (§5). Mostly books — the
exceptions are the three summation papers (Karr ×2, Schneider), which live here rather than in a
sibling directory so that they sit beside *A=B*, whose gap they fill.

**Reading order** (from `../../../notes/cas-haskell.md`), for the books in *this* directory:
Cohen Vol. 1 chs. 2–3 → **Cohen Vol. 2 chs. 2–3** → Geddes → von zur Gathen & Gerhard as needed →
Cohen Vol. 2 chs. 5–9 → Bronstein → *A=B*. Note the early jump into Vol. 2: the
automatic-simplification algorithm lives there, not in Vol. 1.

That is not the whole order. **Baader & Nipkow chs. 1–2 and 5–7 run in parallel with Cohen from the
start**, and chs. 10–11 arrive between Cohen Vol. 2 chs. 5–9 and Bronstein; it lives next door in
`../term-rewriting/`. The guide is emphatic that the rewriting theory is read alongside the algebra,
not after it.

| File | Read it for |
| :--- | :--- |
| `cohen2002_computer_algebra_elementary_algorithms.pdf` | The 2002 A K Peters printing, ISBN 1-56881-158-6 (= ISBN-13 9781568811581 — the same book, despite that number sometimes being listed as a Routledge/CRC reprint). **Start here**, for expression trees and the *structure* of an automatically simplified expression: ch. 2 (MPL, expression evaluation, where automatic simplification is introduced), ch. 3 (recursive structure; §3.2 expression trees, §3.3 structure-based operators), ch. 6 (polynomials and rational expressions). Algorithms in MPL pseudocode. Prerequisites are calculus through multivariable, linear algebra and ODEs — **not** an abstract-algebra course; those topics are introduced as needed. **The automatic-simplification *algorithm* is not here — it is in Vol. 2 ch. 3.** |
| `cohen2003_computer_algebra_mathematical_methods.pdf` | **Needed at Stage 0/1, not just Stage 3.** Ch. 2 is integer and rational arithmetic; **ch. 3 is *the* automatic-simplification algorithm** (§3.1 the goal, §3.2 the algorithm) — the fiddly core most tutorials skip. Chs. 4–9 then cover single-variable polynomials, decomposition, multivariate polynomials, resultants, side relations and factorization, for Stage 2/3. |
| `geddes_czapor_labahn1992_algorithms_for_computer_algebra.pdf` | The one volume covering the whole pipeline: normal forms, polynomial/rational/power-series arithmetic, CRT, Newton iteration and Hensel construction, GCD, factorization, Gröbner bases, rational-function integration, Risch. Pascal-like pseudocode. The single algorithms reference to own. **Its table-of-contents pages are OCR noise** — "In od ion", "Algo i hm", "Pol nomial Fa" — while the body text is sound and every chapter title is findable there. A failed grep against the TOC is not evidence the file is broken. |
| `springer_geddes_book_page.html` | Springer's book page for the above, held so two claims the notes make *about* this book stop resting on a page nobody had. It is the publisher who calls it "the first comprehensive textbook to be published on the topic of computational symbolic mathematics" — the book itself makes no such claim anywhere, so attribute it to the blurb, not to Geddes. Same page for "presented in a Pascal-like computer language", and for the per-chapter page ranges the OCR-garbage TOC cannot give you. Wayback capture: the live page serves a JavaScript bot challenge to `curl`. |
| `vonzurgathen_gerhard2013_modern_computer_algebra.pdf` | Deep reference, graduate level — modular arithmetic, fast Euclid, Hensel lifting, finite-field factorization, evaluation/interpolation, with proofs and complexity. **Look things up in it; do not read it linearly.** |
| `bronstein2005_symbolic_integration_1.pdf` | Integration: Hermite reduction, Rothstein–Trager, Lazard–Rioboo–Trager, Risch proper, plus a 2nd-ed. chapter on parallel/Risch–Norman. Ready-to-implement pseudocode. **Volume II never existed** — Bronstein died before finishing it, so integration of algebraic functions is not in any textbook. |
| `petkovsek_wilf_zeilberger1996_a_eq_b.pdf` | Hypergeometric summation: Gosper, Zeilberger's creative telescoping, WZ, Petkovšek's `Hyper`. Freely released by the authors. **Does not cover Karr's algorithm** — for that see the Schneider paper below. |
| `karr1981_summation_in_finite_terms.pdf` | **The origin of difference-field summation** (*JACM* 28(2), 46 pp.) — the discrete analogue of Risch, and what *A=B* leaves out. Dense; read Schneider first unless you are implementing the theory.  **Partial letter-spacing defect (found round 6):** scattered prose runs extract as "p a p e r", "c o n c e r n e d w i t h", so greps *under-count* rather than fail — `theorem` shows 76 of 100. This file was described as "clean" until round 6; it is not. Despace before concluding a term is absent. |
| `karr1985_theory_of_summation_in_finite_terms.pdf` | Karr's follow-up (*JSC* 1(3), 13 pp.). **Poor OCR — the letter `h` is dropped throughout** ("Teory", "algoritm"), so searches for `the`/`theorem` silently fail. |
| `schneider2007_symbolic_summation_assists_combinatorics.pdf` | **Start here for summation beyond *A=B***: difference fields and the Sigma package, built on Karr's algorithm and far more approachable than his papers. 36 pp., free. |
| `zippel1993_effective_polynomial_computation.pdf` | Where asymptotically optimal polynomial algorithms are the wrong practical choice; by the originator of sparse modular ("Zippel") interpolation. Optional, valuable at Stage 2. |
| `davenport_siret_tournier1993_computer_algebra_2nd_ed.pdf` | Gentler systems-oriented survey. Conceptual overview, not an implementation cookbook. Optional. |
| `jenks_sutor1992_axiom.pdf` | **The genuine Springer 1992 edition** (765 pp., full text layer) — the design document for a strongly-typed CAS, categories and domains (Ring, Field, …) as first-class types. The closest existing analogue to a type-driven Haskell CAS; essential background for the typed-vs-untyped decision. |
| `fricas2026_system_for_computer_mathematics.pdf` | The FriCAS project's regenerated adaptation of the same book — the design document for a strongly-typed CAS, with categories and domains (Ring, Field, …) as first-class types. The closest existing analogue to a type-driven Haskell CAS; essential background for the typed-vs-untyped decision. **Cite it as FriCAS, not as Jenks & Sutor 1992** — for that, use `jenks_sutor1992_axiom.pdf` above, which is held. |

## Axiom literate volumes

`.pamphlet` files are literate LaTeX + SPAD sources from `github.com/daly/axiom/books` — no prebuilt
PDFs exist any more (`axiom-developer.org` is gone). They are plain text; grep them.

- `axiom_bookvol1_tutorial.pamphlet` — user-level tutorial.
- `axiom_bookvol10-1_algebra_theory.pamphlet` — **the interesting one**: the *why* of the typed
  algebra hierarchy.
- `axiom_bookvol10-2_categories.pamphlet` / `-3_domains` / `-4_packages` / `-5_numerics` — the
  hierarchy itself. Reference material; grep for a specific category or domain.
