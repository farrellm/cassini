# Downloaded References Summary

Local document corpus for the Computer Algebra System in Haskell project. Every entry corresponds to
a source cited in [`cas-haskell-bibliography.md`](../notes/cas-haskell-bibliography.md); read that
file for *what to read and why*, and this one for *where the file is*.

Files live under [`papers/`](./papers/), grouped into eight topical directories. Each directory has
its own `CLAUDE.md` with an annotated inventory.

**73 documents (~423 MB) — 37 PDFs, 6 Axiom literate `.pamphlet` sources, 30 HTML captures — plus 2 OCR sidecars.**

Two PDFs are image-only and carry a generated `.txt` sidecar beside them (`bachmair1993_…`, `eker1995_…`) so the corpus stays greppable; the sidecars are gitignored like the documents they derive from, and are regenerated with `pdftoppm -r 300 -gray -png` piped through `tesseract --psm 1`. HTML
entries are single-file `curl` captures of the live page on the date noted in
[`papers/CLAUDE.md`](./papers/CLAUDE.md); they render without CSS but retain the full text. The
original 22 were fetched **2026-08-29**; the eight README/package/licence captures added to anchor
verbatim quotes were fetched **2026-08-30**.

---

## 1. `papers/textbooks/` — the CAS canon (bibliography §1, §5 Axiom)

| File | Document & Authors | Source / Identifier | Pages | Size |
| :--- | :--- | :--- | :--- | :--- |
| [`cohen2002_computer_algebra_elementary_algorithms.pdf`](./papers/textbooks/cohen2002_computer_algebra_elementary_algorithms.pdf) | ***Computer Algebra and Symbolic Computation: Elementary Algorithms***<br>*Joel S. Cohen (2002)* | Libgen MD5: `eb0554c9c1b3f9468e8fb4aaee2a433f` | 344 | 2.21 MB |
| [`cohen2003_computer_algebra_mathematical_methods.pdf`](./papers/textbooks/cohen2003_computer_algebra_mathematical_methods.pdf) | ***Computer Algebra and Symbolic Computation: Mathematical Methods***<br>*Joel S. Cohen (2003)* | Libgen MD5: `52dc1eb488352883d45e03d8a1caff5b` | 470 | 3.13 MB |
| [`geddes_czapor_labahn1992_algorithms_for_computer_algebra.pdf`](./papers/textbooks/geddes_czapor_labahn1992_algorithms_for_computer_algebra.pdf) | ***Algorithms for Computer Algebra***<br>*Keith O. Geddes, Stephen R. Czapor, George Labahn (1992)* | Libgen MD5: `c16e1a9f9f9c07baddd12a4922de90b7` | 593 | 7.84 MB |
| [`vonzurgathen_gerhard2013_modern_computer_algebra.pdf`](./papers/textbooks/vonzurgathen_gerhard2013_modern_computer_algebra.pdf) | ***Modern Computer Algebra*** (3rd ed.)<br>*Joachim von zur Gathen, Jürgen Gerhard (2013)* | Libgen MD5: `265536cedb43347e70dfc6a523371578` | 813 | 24.83 MB |
| [`bronstein2005_symbolic_integration_1.pdf`](./papers/textbooks/bronstein2005_symbolic_integration_1.pdf) | ***Symbolic Integration I: Transcendental Functions*** (2nd ed.)<br>*Manuel Bronstein (2005)* | Springer / DOI: [`10.1007/b138171`](https://doi.org/10.1007/b138171) | 331 | 15.15 MB |
| [`petkovsek_wilf_zeilberger1996_a_eq_b.pdf`](./papers/textbooks/petkovsek_wilf_zeilberger1996_a_eq_b.pdf) | ***A=B***<br>*Marko Petkovšek, Herbert S. Wilf, Doron Zeilberger (1996)* | UPenn / Rutgers Open Access | 217 | 1.19 MB |
| [`karr1981_summation_in_finite_terms.pdf`](./papers/textbooks/karr1981_summation_in_finite_terms.pdf) | **Summation in Finite Terms**<br>*Michael Karr (1981)*<br>Difference-field (ΠΣ) summation — the discrete analogue of Risch, and the half of symbolic summation *A=B* omits. | *JACM* 28(2):305–350 / DOI: [`10.1145/322248.322255`](https://doi.org/10.1145/322248.322255) — user-supplied | 46 | 1.4 MB |
| [`karr1985_theory_of_summation_in_finite_terms.pdf`](./papers/textbooks/karr1985_theory_of_summation_in_finite_terms.pdf) | **Theory of Summation in Finite Terms**<br>*Michael Karr (1985)*<br>The follow-up. **Poor OCR — it systematically drops the letter `h`** ("Teory", "algoritm", "matematical"), so grep accordingly. | *JSC* 1(3):303–315 / DOI: [`10.1016/S0747-7171(85)80038-9`](https://doi.org/10.1016/S0747-7171(85)80038-9) — user-supplied | 13 | 589 KB |
| [`schneider2007_symbolic_summation_assists_combinatorics.pdf`](./papers/textbooks/schneider2007_symbolic_summation_assists_combinatorics.pdf) | **Symbolic Summation Assists Combinatorics**<br>*Carsten Schneider (2007)*<br>The **Sigma** package and difference-field summation — the continuation of Karr, and the part of symbolic summation *A=B* does not cover. | *Séminaire Lotharingien de Combinatoire* 56, Article B56b — free from RISC: [`www3.risc.jku.at`](https://www3.risc.jku.at/research/combinat/software/Sigma/pub/SLC06.pdf) | 36 | 471 KB |
| [`zippel1993_effective_polynomial_computation.pdf`](./papers/textbooks/zippel1993_effective_polynomial_computation.pdf) | ***Effective Polynomial Computation***<br>*Richard Zippel (1993)* | Libgen MD5: `cd77941d8297c50b7b37e361ff419f84` | 363 | 8.23 MB |
| [`davenport_siret_tournier1993_computer_algebra_2nd_ed.pdf`](./papers/textbooks/davenport_siret_tournier1993_computer_algebra_2nd_ed.pdf) | ***Computer Algebra: Systems and Algorithms for Algebraic Computation*** (2nd ed.)<br>*James H. Davenport, Yvon Siret, Évelyne Tournier (1993)* | Libgen MD5: `84f0d17ebb48c1d7211e90a9ff7bdf7e` | 313 | 1.07 MB |
| [`jenks_sutor1992_axiom.pdf`](./papers/textbooks/jenks_sutor1992_axiom.pdf) | ***AXIOM: The Scientific Computation System*** (Axiom Book Vol. 0)<br>*Richard D. Jenks, Robert S. Sutor (1992)*<br>The genuine Springer edition: "© Springer Science+Business Media New York 1992", ISBN 978-1-4612-7729-3 / 978-1-4612-2940-7 (eBook). Full text layer. | Springer — user-supplied | 765 | 20.4 MB |
| [`fricas2026_system_for_computer_mathematics.pdf`](./papers/textbooks/fricas2026_system_for_computer_mathematics.pdf) | ***The FriCAS System for Computer Mathematics***<br>the FriCAS project's regenerated adaptation of *AXIOM: The Scientific Computation System* (Axiom Book Vol. 0), *Jenks & Sutor (1992)*, whose sources were BSD-relicensed in 2002. Generated **2026-03-06**. **Not the Springer edition** — cite it as FriCAS, not as Jenks & Sutor 1992. | FriCAS project (`fricas.github.io`) | 812 | 5.01 MB |

### Axiom literate volumes (bibliography §5)

Axiom is distributed as a literate program. `axiom-developer.org` no longer resolves and no prebuilt
PDFs of the numbered volumes were found; these are the upstream `.pamphlet` sources
(LaTeX + SPAD, plain text, readable directly) from `github.com/daly/axiom/books`.

| File | Volume | Size |
| :--- | :--- | :--- |
| [`axiom_bookvol1_tutorial.pamphlet`](./papers/textbooks/axiom_bookvol1_tutorial.pamphlet) | Vol. 1 — Tutorial | 434.2 KB |
| [`axiom_bookvol10-1_algebra_theory.pamphlet`](./papers/textbooks/axiom_bookvol10-1_algebra_theory.pamphlet) | Vol. 10.1 — Axiom Algebra: Theory | 1.13 MB |
| [`axiom_bookvol10-2_categories.pamphlet`](./papers/textbooks/axiom_bookvol10-2_categories.pamphlet) | Vol. 10.2 — Axiom Algebra: Categories | 3.65 MB |
| [`axiom_bookvol10-3_domains.pamphlet`](./papers/textbooks/axiom_bookvol10-3_domains.pamphlet) | Vol. 10.3 — Axiom Algebra: Domains | 7.38 MB |
| [`axiom_bookvol10-4_packages.pamphlet`](./papers/textbooks/axiom_bookvol10-4_packages.pamphlet) | Vol. 10.4 — Axiom Algebra: Packages | 9.46 MB |
| [`axiom_bookvol10-5_numerics.pamphlet`](./papers/textbooks/axiom_bookvol10-5_numerics.pamphlet) | Vol. 10.5 — Axiom Algebra: Numerics | 30.29 MB |

---

## 2. `papers/term-rewriting/` — rewriting theory (bibliography §2, §8)

| File | Document & Authors | Source / Identifier | Pages | Size |
| :--- | :--- | :--- | :--- | :--- |
| [`baader_nipkow1998_term_rewriting_and_all_that.pdf`](./papers/term-rewriting/baader_nipkow1998_term_rewriting_and_all_that.pdf) | ***Term Rewriting and All That***<br>*Franz Baader, Tobias Nipkow (1998)* | Libgen MD5: `670e57c6f705f33f49b540c8009e4b93` | 313 | 4.72 MB |
| [`terese2003_term_rewriting_systems.pdf`](./papers/term-rewriting/terese2003_term_rewriting_systems.pdf) | ***Term Rewriting Systems*** (Cambridge Tracts in Theoretical CS 55)<br>*Terese (Marc Bezem, Jan Willem Klop, Roel de Vrijer, eds., 2003)*<br>**Image-only scan — no text layer.** `pdftotext` returns nothing on every page; it cannot be grepped or excerpted as text. | Libgen MD5: `2365bb42b3b6b0a37af19fafe1b238f7` | 908 | 181.07 MB |
| [`klop1992_term_rewriting_systems.pdf`](./papers/term-rewriting/klop1992_term_rewriting_systems.pdf) | **Term Rewriting Systems**<br>*Jan Willem Klop (1992)*<br>The chapter from *Handbook of Logic in Computer Science* Vol. 2 (its bibliography cites that volume as "this volume"), circulated by CWI as report `CS-R9053`. **Full text layer** — use this, not the Handbook scan below. Two labelling notes: the text carries no report number of its own, and it cites work through 1991, so it is the Handbook-chapter text rather than strictly the 1990-numbered preprint. | User-supplied | 112 | 700 KB |
| [`klop1990_church_rosser_to_knuth_bendix.pdf`](./papers/term-rewriting/klop1990_church_rosser_to_knuth_bendix.pdf) | **Term Rewriting Systems: From Church-Rosser to Knuth-Bendix and Beyond**<br>*Jan Willem Klop (1990)*<br>A separate, shorter survey — the quick way in. | ICALP '90, Springer LNCS 443 — free from CWI: [`ir.cwi.nl/pub/2667`](https://ir.cwi.nl/pub/2667/2667D.pdf) | 20 | 4.15 MB |
| [`abramsky1992_handbook_of_logic_in_computer_science_vol2.pdf`](./papers/term-rewriting/abramsky1992_handbook_of_logic_in_computer_science_vol2.pdf) | ***Handbook of Logic in Computer Science, Vol. 2*** (incl. Klop, *Term Rewriting Systems*, pp. 1–116)<br>*S. Abramsky, Dov M. Gabbay, T. S. E. Maibaum, eds. (1992)*<br>**Image-only scan — no text layer** (0 of 10 sampled pages carry text). For the Klop chapter use `klop1992_term_rewriting_systems.pdf` above, which is the same text, searchable, at 1/100th the size. | Libgen MD5: `d3059b05b47ca64724ab84e75ce38aed` | 582 | 70.57 MB |
| [`klint_vanderstorm_vinju2009_rascal.pdf`](./papers/term-rewriting/klint_vanderstorm_vinju2009_rascal.pdf) | **RASCAL: A Domain Specific Language for Source Code Analysis and Manipulation**<br>*Paul Klint, Tijs van der Storm, Jurgen Vinju (2009)* | SCAM '09 / DOI: [`10.1109/SCAM.2009.28`](https://doi.org/10.1109/SCAM.2009.28) — author copy, `homepages.cwi.nl/~storm` | 10 | 161.2 KB |

---

## 3. `papers/foundations/` — undecidability & expression representation (bibliography §3)

| File | Document & Authors | Source / Identifier | Pages | Size |
| :--- | :--- | :--- | :--- | :--- |
| [`richardson1968_some_undecidable_problems.pdf`](./papers/foundations/richardson1968_some_undecidable_problems.pdf) | **Some Undecidable Problems Involving Elementary Functions of a Real Variable**<br>*Daniel Richardson (1968)*<br>*J. Symbolic Logic* 33(4):514–520. Note the title: "Undecidable", not "Unsolvable" — the miscitation is widespread. | Sci-Hub / DOI: [`10.2307/2271358`](https://doi.org/10.2307/2271358) | 8 | 579.5 KB |
| [`swierstra2008_data_types_a_la_carte.pdf`](./papers/foundations/swierstra2008_data_types_a_la_carte.pdf) | **Data types à la carte**<br>*Wouter Swierstra (2008)* | Sci-Hub / DOI: [`10.1017/S0956796808006758`](https://doi.org/10.1017/S0956796808006758) | 15 | 511.5 KB |
| [`wadler2008_data_types_a_la_carte_blog.html`](./papers/foundations/wadler2008_data_types_a_la_carte_blog.html) | **Data Types a la Carte** (blog post, 28.2.08)<br>*Philip Wadler*<br>The source of the "presents the best solution to the Expression Problem that I've seen in Haskell (well, Haskell with `-fglasgow-exts`)" verdict — which is here, **not** in Swierstra's paper. Fetched 2026-08-30. | [`wadler.blogspot.com`](https://wadler.blogspot.com/2008/02/data-types-la-carte.html) | — | 112.8 KB |
| [`bahr_hvitved2011_compositional_data_types.pdf`](./papers/foundations/bahr_hvitved2011_compositional_data_types.pdf) | **Compositional Data Types**<br>*Patrick Bahr, Tom Hvitved (2011)* | Sci-Hub / DOI: [`10.1145/2036918.2036930`](https://doi.org/10.1145/2036918.2036930) | 12 | 474.8 KB |

---

## 4. `papers/pattern-matching/` — AC matching, discrimination nets, SMP (bibliography §3, §4)

| File | Document & Authors | Source / Identifier | Pages | Size |
| :--- | :--- | :--- | :--- | :--- |
| [`krebber2017_ac_matching_thesis.pdf`](./papers/pattern-matching/krebber2017_ac_matching_thesis.pdf) | **Non-linear Associative-Commutative Many-to-One Pattern Matching with Sequence Variables** (MSc Thesis)<br>*Manuel Krebber (2017)* | arXiv: [`1705.00907`](https://arxiv.org/abs/1705.00907) | 67 | 864.8 KB |
| [`krebber2017_matchpy.pdf`](./papers/pattern-matching/krebber2017_matchpy.pdf) | **MatchPy: A Pattern Matching Library**<br>*Manuel Krebber, Henrik Barthels, Paolo Bientinesi (2017)* | arXiv: [`1710.06915`](https://arxiv.org/abs/1710.06915) | 8 | 324.9 KB |
| [`krebber2017_efficient_pattern_matching_python.pdf`](./papers/pattern-matching/krebber2017_efficient_pattern_matching_python.pdf) | **Efficient Pattern Matching in Python**<br>*Manuel Krebber, Henrik Barthels, Paolo Bientinesi (2017)* | arXiv: [`1710.00077`](https://arxiv.org/abs/1710.00077) | 9 | 335.3 KB |
| [`bachmair1993_ac_discrimination_nets.pdf`](./papers/pattern-matching/bachmair1993_ac_discrimination_nets.pdf) | **Associative-Commutative Discrimination Nets**<br>*Leo Bachmair, Ta Chen, I. V. Ramakrishnan (1993)*<br>The paper that **introduces** the data structure. **Image-only — OCR sidecar `.txt` alongside.** | TAPSOFT '93, Springer LNCS 668, pp. 61–74 / DOI: [`10.1007/3-540-56610-4_56`](https://doi.org/10.1007/3-540-56610-4_56) — user-supplied | 14 | 758 KB |
| [`bachmair1995_ac_discrimination_nets.pdf`](./papers/pattern-matching/bachmair1995_ac_discrimination_nets.pdf) | **Experiments with Associative-Commutative Discrimination Nets**<br>*Leo Bachmair, Ta Chen, I. V. Ramakrishnan, Siva Anantharaman, Jacques Chabin (1995)* | IJCAI '95, pp. 348–354: [`ijcai.org/Proceedings/95-1/Papers/046.pdf`](https://www.ijcai.org/Proceedings/95-1/Papers/046.pdf) | 7 | 248.1 KB |
| [`benanav1987_complexity_of_matching_problems.pdf`](./papers/pattern-matching/benanav1987_complexity_of_matching_problems.pdf) | **Complexity of Matching Problems**<br>*Dan Benanav, Deepak Kapur, Paliath Narendran (1987)*<br>**The source for *both* AC-matching complexity claims** — NP-completeness, *and* the O(\|s\|·\|t\|³) bound for linear patterns. | *JSC* 3(1):203–216 / DOI: [`10.1016/S0747-7171(87)80027-5`](https://doi.org/10.1016/S0747-7171(87)80027-5) — user-supplied | 14 | 633 KB |
| [`eker1995_associative_commutative_matching.pdf`](./papers/pattern-matching/eker1995_associative_commutative_matching.pdf) | **Associative-Commutative Matching Via Bipartite Graph Matching**<br>*S. M. Eker (1995)*<br>A practical AC-matching algorithm for the general case — the Maude lineage. Not a complexity result; it cites Benanav for those. **Image-only apart from an Oxford download watermark — OCR sidecar `.txt` alongside.** | *The Computer Journal* 38(5):381–399 / DOI: [`10.1093/comjnl/38.5.381`](https://doi.org/10.1093/comjnl/38.5.381) — user-supplied | 19 | 2.4 MB |
| [`cole_wolfram1981_smp.pdf`](./papers/pattern-matching/cole_wolfram1981_smp.pdf) | **SMP: A Symbolic Manipulation Program**<br>*Christopher A. Cole, Stephen Wolfram (1981)* | Sci-Hub / DOI: [`10.1145/800206.806365`](https://doi.org/10.1145/800206.806365) | 3 | 269.7 KB |
| [`greif1985_smp_pattern_matcher.pdf`](./papers/pattern-matching/greif1985_smp_pattern_matcher.pdf) | **The SMP Pattern-Matcher**<br>*Jerry Greif (1985)* | Sci-Hub / DOI: [`10.1007/3-540-15984-3_281`](https://doi.org/10.1007/3-540-15984-3_281) | 12 | 884.5 KB |

---

## 5. `papers/cas-architecture/` — how existing CASs are built (bibliography §5)

| File | Document & Authors | Source / Identifier | Pages | Size |
| :--- | :--- | :--- | :--- | :--- |
| [`meurer2017_sympy.pdf`](./papers/cas-architecture/meurer2017_sympy.pdf) | **SymPy: symbolic computing in Python**<br>*Aaron Meurer et al. (2017)* | PeerJ CS / DOI: [`10.7717/peerj-cs.103`](https://doi.org/10.7717/peerj-cs.103) | 19 | 853.8 KB |
| [`bauer2002_ginac_framework.pdf`](./papers/cas-architecture/bauer2002_ginac_framework.pdf) | **Introduction to the GiNaC Framework for Symbolic Computation within the C++ Programming Language**<br>*Christian Bauer, Alexander Frink, Richard Kreckel (2002)* | Sci-Hub / DOI: [`10.1006/jsco.2001.0494`](https://doi.org/10.1006/jsco.2001.0494) | 12 | 309.4 KB |
| [`fateman1992_review_of_mathematica.pdf`](./papers/cas-architecture/fateman1992_review_of_mathematica.pdf) | **A Review of Mathematica**<br>*Richard J. Fateman (1992)* | *J. Symbolic Computation* 13(5) — author copy via Wayback (`people.eecs.berkeley.edu` unreachable) | 35 | 314.5 KB |
| [`lioubartsev2016_pedagogical_cas_thesis.pdf`](./papers/cas-architecture/lioubartsev2016_pedagogical_cas_thesis.pdf) | **Constructing a Computer Algebra System Capable of Generating Pedagogical Step-by-Step Solutions** (MSc Thesis)<br>*Dmitrij Lioubartsev (2016)* | KTH / DiVA: `diva2:945222` | 91 | 1.96 MB |
| [`rich_rubi_vision.html`](./papers/cas-architecture/rich_rubi_vision.html) | *Organizing Math as a Rule-based Decision Tree* (Rubi "Vision")<br>*Albert Rich* | [`rulebasedintegration.org/vision.html`](https://rulebasedintegration.org/vision.html) | — | 14.3 KB |
| [`symbolica_2_2_symbolic_integration.html`](./papers/cas-architecture/symbolica_2_2_symbolic_integration.html) | *Symbolica 2.2: symbolic integration* — the source of the Rubi-port and benchmark figures quoted in §5 | [`symbolica.io/posts/symbolic_integration/`](https://symbolica.io/posts/symbolic_integration/) | — | 103.2 KB |
| [`symbolica_pattern_matching.html`](./papers/cas-architecture/symbolica_pattern_matching.html) | *Algorithms through the lens of symbolic pattern matching* | [`symbolica.io/posts/pattern_matching/`](https://symbolica.io/posts/pattern_matching/) | — | 74.2 KB |
| [`symbolica_license.html`](./papers/cas-architecture/symbolica_license.html) | *Pricing and plans* — the source for the licence terms quoted in §5: the employment trigger, and the **Free** tier's "[o]ne core and instance per device" cap. Fetched 2026-08-30. | [`symbolica.io/license/`](https://symbolica.io/license/) | — | 50.0 KB |
| [`expreduce_readme.html`](./papers/cas-architecture/expreduce_readme.html) | Expreduce's GitHub README — the source for "This software is experimental quality and is not currently intended for serious use." Fetched 2026-08-30. | [`github.com/corywalker/expreduce`](https://github.com/corywalker/expreduce) | — | 308.6 KB |
| [`symja_readme.html`](./papers/cas-architecture/symja_readme.html) | Symja's GitHub README — confirms "the Rubi symbolic integration rules are used to implement the `Integrate` function" and, as the notes say, **names no Rubi version**. Fetched 2026-08-30. | [`github.com/axkr/symja_android_library`](https://github.com/axkr/symja_android_library) | — | 376.2 KB |

---

## 6. `papers/haskell/` — Haskell papers & library documentation (bibliography §7)

| File | Document & Authors | Source / Identifier | Pages | Size |
| :--- | :--- | :--- | :--- | :--- |
| [`ishii2018_purely_functional_cas_haskell.pdf`](./papers/haskell/ishii2018_purely_functional_cas_haskell.pdf) | **A Purely Functional Computer Algebra System Embedded in Haskell**<br>*Hiromi Ishii (2018)* | arXiv: [`1807.01456`](https://arxiv.org/abs/1807.01456) / CASC 2018 | 16 | 252.6 KB |
| [`zhu2025_hash_consing.pdf`](./papers/haskell/zhu2025_hash_consing.pdf) | **Efficient Symbolic Computation via Hash Consing**<br>*Bowen Zhu (2025)* | arXiv: [`2509.20534`](https://arxiv.org/abs/2509.20534) | 15 | 657.7 KB |
| [`numeric_prelude_haskellwiki.html`](./papers/haskell/numeric_prelude_haskellwiki.html) | *Numeric Prelude* — HaskellWiki (the "why `Num` is wrong" statement) | [`wiki.haskell.org/Numeric_Prelude`](https://wiki.haskell.org/Numeric_Prelude) | — | 40.8 KB |
| [`numeric_prelude_hackage.html`](./papers/haskell/numeric_prelude_hackage.html) | *numeric-prelude* — Hackage package page (module/class hierarchy) | [`hackage.haskell.org/package/numeric-prelude`](https://hackage.haskell.org/package/numeric-prelude) | — | 42.2 KB |
| [`penner2018_asts_with_fix_and_free.html`](./papers/haskell/penner2018_asts_with_fix_and_free.html) | *ASTs with Fix and Free* — Chris Penner (2018-02-24). The practical how-to for parameterizing an AST's recursive slots and folding it with `Fix`/`Free`. | [`chrispenner.ca`](https://chrispenner.ca/posts/asts-with-fix-and-free) | — | 86.2 KB |
| [`milewski2017_f_algebras.html`](./papers/haskell/milewski2017_f_algebras.html) | *F-Algebras* — Bartosz Milewski (2017-02-28), part 24 of *Category Theory for Programmers*. The theory under `Fix`/`cata`: initial algebras and catamorphisms. | [`bartoszmilewski.com`](https://bartoszmilewski.com/2017/02/28/f-algebras/) | — | 154.6 KB |
| [`olah2012_hasksymb.html`](./papers/haskell/olah2012_hasksymb.html) | *HaskSymb: An Experiment in Haskell Symbolic Algebra*<br>*Christopher Olah (2012-06-01)* | [`christopherolah.wordpress.com`](https://christopherolah.wordpress.com/2012/06/01/hasksymb-an-experiment-in-haskell-symbolic-algebra/) — **note:** the bibliography dates this 2012-11; the post is dated June 2012 | — | 81.9 KB |
| [`olah_hasksymb_readme.html`](./papers/haskell/olah_hasksymb_readme.html) | HaskSymb's GitHub README — **the design retrospective the blog post does not contain**: "The *big* issue I'm facing is appropriate types for symbolic expressions. In particular, how do I handle variables in types?" and "My bad solution for now has been to just not have type-level variable representation, which kind of bothers me." Fetched 2026-08-30. | [`github.com/colah/HaskSymb`](https://github.com/colah/HaskSymb) | — | 265.0 KB |
| [`poly_hackage.html`](./papers/haskell/poly_hackage.html) | The `poly` Hackage page — source for the maintainer-reported "poly is at least 20x-40x faster than the `polynomial` library", with the per-operation benchmark table behind it. Fetched 2026-08-30. | [`hackage.haskell.org/package/poly`](https://hackage.haskell.org/package/poly) | — | 29.2 KB |
| [`dumb_cas_hackage.html`](./papers/haskell/dumb_cas_hackage.html) | The `dumb-cas` Hackage page — source for "combine the flexibility of a Lisp with the conciseness of a Regex engine". Fetched 2026-08-30. | [`hackage.haskell.org/package/dumb-cas`](https://hackage.haskell.org/package/dumb-cas) | — | 18.2 KB |

---

## 7. `papers/wolfram-language/` — the evaluator behavioral spec (bibliography §6)

| File | Document | Source | Size |
| :--- | :--- | :--- | :--- |
| [`wolfram_ref_evaluation_of_expressions.html`](./papers/wolfram-language/wolfram_ref_evaluation_of_expressions.html) | *Evaluation of Expressions* — the full tutorial chapter, incl. the standard evaluation procedure and the Attributes section (~26k words) | [`reference.wolfram.com/.../tutorial/EvaluationOfExpressions.html`](https://reference.wolfram.com/language/tutorial/EvaluationOfExpressions.html) | 851.9 KB |
| [`wolfram_ref_evaluation.html`](./papers/wolfram-language/wolfram_ref_evaluation.html) | *Evaluation* — **the page carrying "The Standard Evaluation Sequence", the complete ordered algorithm — 12 numbered steps as the page gives them.** Short, and the most important file here for Stage 1. | [`.../tutorial/Evaluation.html`](https://reference.wolfram.com/language/tutorial/Evaluation.html) | 183.8 KB |
| [`wolfram_ref_attributes.html`](./papers/wolfram-language/wolfram_ref_attributes.html) | `Attributes` — the symbol reference page. **Thin capture: it does *not* contain the attribute list** — only the `Attributes[symbol]` signatures plus bare section labels; the "Details" section did not capture. The full attribute table is in `wolfram_ref_evaluation_of_expressions.html`. | [`.../ref/Attributes.html`](https://reference.wolfram.com/language/ref/Attributes.html) | 212.8 KB |
| [`wolfram_guide_attributes.html`](./papers/wolfram-language/wolfram_guide_attributes.html) | *Attributes* — the guide page; a list of links to attribute-related functions, no prose | [`.../guide/Attributes.html`](https://reference.wolfram.com/language/guide/Attributes.html) | 188.0 KB |
| [`wolfram_ref_associating_definitions.html`](./papers/wolfram-language/wolfram_ref_associating_definitions.html) | *Transformation Rules and Definitions* — the UpValues/DownValues rule-storage model in context | [`.../tutorial/AssociatingDefinitionsWithDifferentSymbols.html`](https://reference.wolfram.com/language/tutorial/AssociatingDefinitionsWithDifferentSymbols.html) | 496.8 KB |
| [`wolfram_ref_ownvalues.html`](./papers/wolfram-language/wolfram_ref_ownvalues.html) | `OwnValues` reference page. Thin in the same way as its three siblings (~13 KB of text): "`OwnValues[x]` gives a list of transformation rules corresponding to all ownvalues defined for the symbol `x`", and little else. Fetched 2026-08-30. | [`.../ref/OwnValues.html`](https://reference.wolfram.com/language/ref/OwnValues.html) | 232.0 KB |
| [`wolfram_ref_downvalues.html`](./papers/wolfram-language/wolfram_ref_downvalues.html) | `DownValues` reference page | [`.../ref/DownValues.html`](https://reference.wolfram.com/language/ref/DownValues.html) | 229.7 KB |
| [`wolfram_ref_upvalues.html`](./papers/wolfram-language/wolfram_ref_upvalues.html) | `UpValues` reference page | [`.../ref/UpValues.html`](https://reference.wolfram.com/language/ref/UpValues.html) | 248.2 KB |
| [`wolfram_ref_subvalues.html`](./papers/wolfram-language/wolfram_ref_subvalues.html) | `SubValues` reference page | [`.../ref/SubValues.html`](https://reference.wolfram.com/language/ref/SubValues.html) | 234.2 KB |
| [`wltools_language_spec.html`](./papers/wolfram-language/wltools_language_spec.html) | *Wolfram Language Specification* — community reverse-engineering project index. **Informed inference, not authoritative.** | [`wltools.github.io/LanguageSpec/`](https://wltools.github.io/LanguageSpec/) | 35.0 KB |

---

## 8. `papers/web-articles/` — blog posts & course sites (bibliography §9)

| File | Document & Authors | Source | Size |
| :--- | :--- | :--- | :--- |
| [`johansson2022_cas_wishes.html`](./papers/web-articles/johansson2022_cas_wishes.html) | *Things I would like to see in a computer algebra system* — Fredrik Johansson (2022) | [`fredrikj.net`](https://fredrikj.net/blog/2022/04/things-i-would-like-to-see-in-a-computer-algebra-system/) | 30.2 KB |
| [`wolfram2013_before_mathematica.html`](./papers/web-articles/wolfram2013_before_mathematica.html) | *There Was a Time before Mathematica…* — Stephen Wolfram (2013) | [`writings.stephenwolfram.com`](https://writings.stephenwolfram.com/2013/06/there-was-a-time-before-mathematica/) | 137.3 KB |
| [`wolfram2021_third_of_a_century.html`](./papers/web-articles/wolfram2021_third_of_a_century.html) | *Celebrating a Third of a Century of Mathematica, and Looking Forward* — Stephen Wolfram (2021) | [`writings.stephenwolfram.com`](https://writings.stephenwolfram.com/2021/10/celebrating-a-third-of-a-century-of-mathematica-and-looking-forward/) | 93.3 KB |
| [`brun2022_building_a_cas_in_go_part1.html`](./papers/web-articles/brun2022_building_a_cas_in_go_part1.html) | *Building a Computer Algebra System in Go, Part 1: Multivariate Expressions and Differentiation* — Victor Brun (2022) | Better Programming / Medium, via Wayback (live URL is Cloudflare-gated). **Part 1 only — no later parts found.** | 252.9 KB |
| [`vonzurgathen_gerhard_cosec_companion.html`](./papers/web-articles/vonzurgathen_gerhard_cosec_companion.html) | *Modern Computer Algebra* companion site — a book landing page with "Addenda and corrigenda"; the source confirming the extent (808 pages, 40 tables, 560 exercises) and the edition ISBNs (1st 1999 `0521641764`, 2nd 2003 `978-0521826464`) | [`cosec.bit.uni-bonn.de/science/mca/`](https://cosec.bit.uni-bonn.de/science/mca/) | 7.4 KB |

---

## Coverage against the bibliography

**Fully covered locally:** §1 (textbooks), §2 (term rewriting), §3 (foundational papers), §4
(pattern matching), §6 (Wolfram Language primary sources — one exception below), §7 papers, §9.

**Pointers only, by design:** §5 and §8 name *software systems* (Expreduce, Mathics, Symja, SymPy,
GiNaC, SymEngine, Maxima, Reduce, FriCAS, Symbolica, Maude, OBJ, Stratego, Rascal, Pure, FLINT…) and
§7 names *Hackage packages*. Those are source repositories, not documents; clone or browse them
rather than archiving them here. Where such an entry cites an actual paper, that paper is present
(SymPy, GiNaC, Rascal, Fateman/MockMMA).

**But the waiver covers citing a system, not quoting its page.** Where the notes quote a README,
package page or licence *verbatim*, the page is captured here so the quote has an anchor — that is
what `expreduce_readme.html`, `symja_readme.html`, `symbolica_license.html`,
`olah_hasksymb_readme.html`, `poly_hackage.html` and `dumb_cas_hackage.html` are for. Two further
captures close the same kind of gap outside §5/§7: `wadler2008_data_types_a_la_carte_blog.html` (a
blog post, which the waiver never reached) and `wolfram_ref_ownvalues.html` (cited in §6 alongside
its three siblings, but previously the only one not held). Adding a verbatim quote from a live page
means capturing that page in the same change.

### Not obtained

Nine sources were once listed here. Six were subsequently supplied and are now held (Klop's survey,
then Karr ×2, Benanav, Eker, Bachmair '93 and the Springer Jenks & Sutor — see the corrections log
below). The three that remain are not paywalled but genuinely gone or nonexistent.

| Source | Bibliography § | Why |
| :--- | :--- | :--- |
| riptutorial, *Wolfram Language — Evaluation Order* | §6 | The site's Wolfram Language content is gone — `riptutorial.com/wolfram-language` now serves a generic landing page, `/topic/2549/evaluation-order` serves unrelated iOS content, and the Wayback Machine holds no snapshot of either URL. The material it summarized is covered in full by `wolfram_ref_evaluation_of_expressions.html`. |
| Axiom volumes as PDFs | §5 | `axiom-developer.org` does not resolve and no prebuilt volume PDFs were found; the upstream `.pamphlet` literate sources are stored instead. |
| Brun, *Building a CAS in Go*, parts 2+ | §9 | Only Part 1 is discoverable; no later installments found on Medium or in search. |

---

### Corrections, 2026-08-29

A validation pass against `../notes/cas-haskell.md` found four entries in this index describing a
document other than the file actually stored. Recording what changed, so the corrections are not
silently re-introduced:

| Was indexed as | The file actually was | Resolution |
| :--- | :--- | :--- |
| Klop, *Term Rewriting Systems*, CWI `CS-R9053` (10 pp.) | van Schuppen, *Adaptive Stochastic Filtering Problems: The Continuous Time Case*, CWI/Mathematisch Centrum `BW 167/82` (1982) — zero occurrences of "rewrit" | **Resolved 2026-08-30**: the correct document was supplied and is now stored under the original filename (112 pp., full text layer). Klop's ICALP '90 survey, fetched as an interim substitute, is kept as an additional shorter survey. |
| Bachmair et al., *Experiments with AC Discrimination Nets*, IJCAI '95 (6 pp.) | Jian Zhang & Hantao Zhang, *SEM: a System for Enumerating Models*, IJCAI '95 — zero occurrences of "discrimination" or "Bachmair" | Replaced with the real paper from `ijcai.org` (7 pp., pp. 348–354) |
| Barthels, Krebber & Bientinesi, *Automating the Generation of Efficient Linear Algebra Algorithms using Rewrite Rules* | Krebber, Barthels & Bientinesi, *Efficient Pattern Matching in Python* (arXiv:1710.00077v1) — a MatchPy paper | Renamed to `krebber2017_efficient_pattern_matching_python.pdf` and re-described |
| Jenks & Sutor, *AXIOM: The Scientific Computation System*, Springer 1992 | *The FriCAS System for Computer Mathematics*, generated 2026-03-06 | Renamed to `fricas2026_system_for_computer_mathematics.pdf`. The Springer edition was briefly moved to **Not obtained**, then supplied; both are now held as separate files. |

Also corrected in the same pass: `richardson1968_some_unsolvable_problems.pdf` →
`richardson1968_some_undecidable_problems.pdf` (the paper's title is "Undecidable"), and the Terese
scan is now flagged as having no text layer.

**Thin captures.** The Wolfram `ref/` HTML captures for `DownValues`, `UpValues`, `SubValues` and
`Attributes` render to roughly 13 KB of text each, almost all navigation chrome; only the one-line
definitions survived, and the "Details" sections did not. In particular `wolfram_ref_attributes.html`
does **not** contain the attribute list, despite what this index previously claimed. The substantive
captures are `wolfram_ref_evaluation_of_expressions.html` (~114 KB of text — the full attribute table
and worked traces) and `wolfram_ref_associating_definitions.html` (~55 KB — the rule-storage model in
context).

### Second audit pass, 2026-08-30

Every file was then checked: 29 PDFs for identity, page count and text-layer health (10 sampled pages
each), 20 HTML captures for title identity and content, 6 pamphlets for `\VolumeName`. **No further
wrong documents** — every PDF matches its filename and page count, every HTML title matches its
claimed page, every pamphlet matches its volume. New findings recorded above:

- `wolfram_ref_evaluation.html`, indexed only as "the guide page", in fact carries **"The Standard
  Evaluation Sequence"** — the complete ordered algorithm, in 12 numbered steps. It had not been opened during the
  first pass, and `notes/cas-haskell.md` was briefly "corrected" *away* from the right answer as a
  result. Re-indexed as the primary evaluator spec.
- `abramsky1992_*` is image-only, like Terese. It had been offered as the way to read Klop's chapter.
- `wolfram_ref_attributes.html` does not carry the attribute list (above).
- The cosec companion capture is the source for von zur Gathen & Gerhard's page count and edition
  ISBNs, which fixes a second-edition year miscited as 2002 (it is 2003) in the notes.

Four captures are thin but *complete* for what they are — `numeric_prelude_haskellwiki.html` (4.7 KB
of text), `olah2012_hasksymb.html` (2.0 KB), `wltools_language_spec.html` (4.7 KB) and the cosec
companion (2.0 KB) are all genuinely short pages, not truncated fetches.

---

## Provenance caveat

Several textbook PDFs were obtained from Libgen and several papers from Sci-Hub, as recorded in the
Source column. The bibliography's "Availability at a Glance" section marks which of these titles are
in print and purchasable — Cohen Vols. 1–2, von zur Gathen & Gerhard, Baader & Nipkow, Bronstein,
Terese, and Jenks & Sutor. *A=B*, the arXiv papers, the Axiom material, the PeerJ SymPy paper, and
every HTML capture are freely and legally available from their publishers or authors.
