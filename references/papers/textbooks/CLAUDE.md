# textbooks/

The CAS algorithm canon (bibliography §1) plus the Axiom literate volumes (§5). Books only —
research papers live in the sibling topical directories.

**Reading order** (from `../../../notes/cas-haskell.md`): Cohen Vol. 1 chs. 2–3 → **Cohen Vol. 2
chs. 2–3** → Geddes → von zur Gathen & Gerhard as needed → Cohen Vol. 2 chs. 5–9 → Bronstein →
*A=B*. Note the early jump into Vol. 2: the automatic-simplification algorithm lives there, not in
Vol. 1.

| File | Read it for |
| :--- | :--- |
| `cohen2002_computer_algebra_elementary_algorithms.pdf` | **Start here**, for expression trees and the *structure* of an automatically simplified expression: ch. 2 (MPL, expression evaluation, where automatic simplification is introduced), ch. 3 (recursive structure; §3.2 expression trees, §3.3 structure-based operators), ch. 6 (polynomials and rational expressions). Algorithms in MPL pseudocode. Prerequisites are calculus through multivariable, linear algebra and ODEs — **not** an abstract-algebra course; those topics are introduced as needed. **The automatic-simplification *algorithm* is not here — it is in Vol. 2 ch. 3.** |
| `cohen2003_computer_algebra_mathematical_methods.pdf` | **Needed at Stage 0/1, not just Stage 3.** Ch. 2 is integer and rational arithmetic; **ch. 3 is *the* automatic-simplification algorithm** (§3.1 the goal, §3.2 the algorithm) — the fiddly core most tutorials skip. Chs. 4–9 then cover single-variable polynomials, decomposition, multivariate polynomials, resultants, side relations and factorization, for Stage 2/3. |
| `geddes_czapor_labahn1992_algorithms_for_computer_algebra.pdf` | The one volume covering the whole pipeline: normal forms, polynomial/rational/power-series arithmetic, CRT, Newton iteration and Hensel construction, GCD, factorization, Gröbner bases, rational-function integration, Risch. Pascal-like pseudocode. The single algorithms reference to own. |
| `vonzurgathen_gerhard2013_modern_computer_algebra.pdf` | Deep reference, graduate level — modular arithmetic, fast Euclid, Hensel lifting, finite-field factorization, evaluation/interpolation, with proofs and complexity. **Look things up in it; do not read it linearly.** |
| `bronstein2005_symbolic_integration_1.pdf` | Integration: Hermite reduction, Rothstein–Trager, Lazard–Rioboo–Trager, Risch proper, plus a 2nd-ed. chapter on parallel/Risch–Norman. Ready-to-implement pseudocode. **Volume II never existed** — Bronstein died before finishing it, so integration of algebraic functions is not in any textbook. |
| `petkovsek_wilf_zeilberger1996_a_eq_b.pdf` | Hypergeometric summation: Gosper, Zeilberger's creative telescoping, WZ, Petkovšek's `Hyper`. Freely released by the authors. **Does not cover Karr's algorithm** — that gap is tracked in `../foundations/CLAUDE.md`. |
| `zippel1993_effective_polynomial_computation.pdf` | Where asymptotically optimal polynomial algorithms are the wrong practical choice; by the originator of sparse modular ("Zippel") interpolation. Optional, valuable at Stage 2. |
| `davenport_siret_tournier1993_computer_algebra_2nd_ed.pdf` | Gentler systems-oriented survey. Conceptual overview, not an implementation cookbook. Optional. |
| `fricas2026_system_for_computer_mathematics.pdf` | The FriCAS project's regenerated adaptation of Axiom Vol. 0 (Jenks & Sutor 1992) — the design document for a strongly-typed CAS, with categories and domains (Ring, Field, …) as first-class types. The closest existing analogue to a type-driven Haskell CAS; essential background for the typed-vs-untyped decision. **Cite it as FriCAS, not as Jenks & Sutor 1992** — the Springer edition is not held. |

## Axiom literate volumes

`.pamphlet` files are literate LaTeX + SPAD sources from `github.com/daly/axiom/books` — no prebuilt
PDFs exist any more (`axiom-developer.org` is gone). They are plain text; grep them.

- `axiom_bookvol1_tutorial.pamphlet` — user-level tutorial.
- `axiom_bookvol10-1_algebra_theory.pamphlet` — **the interesting one**: the *why* of the typed
  algebra hierarchy.
- `axiom_bookvol10-2_categories.pamphlet` / `-3_domains` / `-4_packages` / `-5_numerics` — the
  hierarchy itself. Reference material; grep for a specific category or domain.
