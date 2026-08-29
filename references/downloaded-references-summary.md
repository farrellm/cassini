# Downloaded References Summary

Local document corpus for the Computer Algebra System in Haskell project. Every entry corresponds to
a source cited in [`cas-haskell-bibliography.md`](../notes/cas-haskell-bibliography.md); read that
file for *what to read and why*, and this one for *where the file is*.

Files live under [`papers/`](./papers/), grouped into eight topical directories. Each directory has
its own `CLAUDE.md` with an annotated inventory.

**55 files — 43 PDFs, 6 Axiom literate sources, 20 HTML captures.** (Counts overlap: see per-section
tables.) HTML entries are single-file `curl` captures of the live page on the date noted in
[`papers/CLAUDE.md`](./papers/CLAUDE.md); they render without CSS but retain the full text.

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
| [`zippel1993_effective_polynomial_computation.pdf`](./papers/textbooks/zippel1993_effective_polynomial_computation.pdf) | ***Effective Polynomial Computation***<br>*Richard Zippel (1993)* | Libgen MD5: `cd77941d8297c50b7b37e361ff419f84` | 363 | 8.23 MB |
| [`davenport_siret_tournier1993_computer_algebra_2nd_ed.pdf`](./papers/textbooks/davenport_siret_tournier1993_computer_algebra_2nd_ed.pdf) | ***Computer Algebra: Systems and Algorithms for Algebraic Computation*** (2nd ed.)<br>*James H. Davenport, Yvon Siret, Évelyne Tournier (1993)* | Libgen MD5: `84f0d17ebb48c1d7211e90a9ff7bdf7e` | 313 | 1.07 MB |
| [`jenks_sutor1992_axiom.pdf`](./papers/textbooks/jenks_sutor1992_axiom.pdf) | ***AXIOM: The Scientific Computation System*** (Axiom Book Vol. 0)<br>*Richard D. Jenks, Robert S. Sutor (1992)* | Axiom / FriCAS Project | 812 | 5.01 MB |

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
| [`terese2003_term_rewriting_systems.pdf`](./papers/term-rewriting/terese2003_term_rewriting_systems.pdf) | ***Term Rewriting Systems*** (Cambridge Tracts in Theoretical CS 55)<br>*Terese (Marc Bezem, Jan Willem Klop, Roel de Vrijer, eds., 2003)* | Libgen MD5: `2365bb42b3b6b0a37af19fafe1b238f7` | 908 | 181.07 MB |
| [`klop1992_term_rewriting_systems.pdf`](./papers/term-rewriting/klop1992_term_rewriting_systems.pdf) | **Term Rewriting Systems**<br>*Jan Willem Klop (1992)* | CWI Technical Report `CS-R9053` | 10 | 313.7 KB |
| [`abramsky1992_handbook_of_logic_in_computer_science_vol2.pdf`](./papers/term-rewriting/abramsky1992_handbook_of_logic_in_computer_science_vol2.pdf) | ***Handbook of Logic in Computer Science, Vol. 2*** (incl. Klop, *Term Rewriting Systems*, pp. 1–116)<br>*S. Abramsky, Dov M. Gabbay, T. S. E. Maibaum, eds. (1992)* | Libgen MD5: `d3059b05b47ca64724ab84e75ce38aed` | 582 | 70.57 MB |
| [`klint_vanderstorm_vinju2009_rascal.pdf`](./papers/term-rewriting/klint_vanderstorm_vinju2009_rascal.pdf) | **RASCAL: A Domain Specific Language for Source Code Analysis and Manipulation**<br>*Paul Klint, Tijs van der Storm, Jurgen Vinju (2009)* | SCAM '09 / DOI: [`10.1109/SCAM.2009.28`](https://doi.org/10.1109/SCAM.2009.28) — author copy, `homepages.cwi.nl/~storm` | 10 | 161.2 KB |

---

## 3. `papers/foundations/` — undecidability & expression representation (bibliography §3)

| File | Document & Authors | Source / Identifier | Pages | Size |
| :--- | :--- | :--- | :--- | :--- |
| [`richardson1968_some_unsolvable_problems.pdf`](./papers/foundations/richardson1968_some_unsolvable_problems.pdf) | **Some Unsolvable Problems Involving Elementary Functions of a Real Variable**<br>*Daniel Richardson (1968)* | Sci-Hub / DOI: [`10.2307/2271358`](https://doi.org/10.2307/2271358) | 8 | 579.5 KB |
| [`swierstra2008_data_types_a_la_carte.pdf`](./papers/foundations/swierstra2008_data_types_a_la_carte.pdf) | **Data types à la carte**<br>*Wouter Swierstra (2008)* | Sci-Hub / DOI: [`10.1017/S0956796808006758`](https://doi.org/10.1017/S0956796808006758) | 15 | 511.5 KB |
| [`bahr_hvitved2011_compositional_data_types.pdf`](./papers/foundations/bahr_hvitved2011_compositional_data_types.pdf) | **Compositional Data Types**<br>*Patrick Bahr, Tom Hvitved (2011)* | Sci-Hub / DOI: [`10.1145/2036918.2036930`](https://doi.org/10.1145/2036918.2036930) | 12 | 474.8 KB |

---

## 4. `papers/pattern-matching/` — AC matching, discrimination nets, SMP (bibliography §3, §4)

| File | Document & Authors | Source / Identifier | Pages | Size |
| :--- | :--- | :--- | :--- | :--- |
| [`krebber2017_ac_matching_thesis.pdf`](./papers/pattern-matching/krebber2017_ac_matching_thesis.pdf) | **Non-linear Associative-Commutative Many-to-One Pattern Matching with Sequence Variables** (MSc Thesis)<br>*Manuel Krebber (2017)* | arXiv: [`1705.00907`](https://arxiv.org/abs/1705.00907) | 67 | 864.8 KB |
| [`krebber2017_matchpy.pdf`](./papers/pattern-matching/krebber2017_matchpy.pdf) | **MatchPy: A Pattern Matching Library**<br>*Manuel Krebber, Henrik Barthels, Paolo Bientinesi (2017)* | arXiv: [`1710.06915`](https://arxiv.org/abs/1710.06915) | 8 | 324.9 KB |
| [`barthels2017_linear_algebra_rewrite_rules.pdf`](./papers/pattern-matching/barthels2017_linear_algebra_rewrite_rules.pdf) | **Automating the Generation of Efficient Linear Algebra Algorithms using Rewrite Rules**<br>*Henrik Barthels, Manuel Krebber, Paolo Bientinesi (2017)* | arXiv: [`1710.00077`](https://arxiv.org/abs/1710.00077) | 9 | 335.3 KB |
| [`bachmair1995_ac_discrimination_nets.pdf`](./papers/pattern-matching/bachmair1995_ac_discrimination_nets.pdf) | **Experiments with Associative-Commutative Discrimination Nets**<br>*Leo Bachmair, Ta Chen, C. R. Ramakrishnan, I. V. Ramakrishnan (1995)* | IJCAI '95 Proceedings | 6 | 185.1 KB |
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

---

## 6. `papers/haskell/` — Haskell papers & library documentation (bibliography §7)

| File | Document & Authors | Source / Identifier | Pages | Size |
| :--- | :--- | :--- | :--- | :--- |
| [`ishii2018_purely_functional_cas_haskell.pdf`](./papers/haskell/ishii2018_purely_functional_cas_haskell.pdf) | **A Purely Functional Computer Algebra System Embedded in Haskell**<br>*Hiromi Ishii (2018)* | arXiv: [`1807.01456`](https://arxiv.org/abs/1807.01456) / CASC 2018 | 16 | 252.6 KB |
| [`zhu2025_hash_consing.pdf`](./papers/haskell/zhu2025_hash_consing.pdf) | **Efficient Symbolic Computation via Hash Consing**<br>*Bowen Zhu (2025)* | arXiv: [`2509.20534`](https://arxiv.org/abs/2509.20534) | 15 | 657.7 KB |
| [`numeric_prelude_haskellwiki.html`](./papers/haskell/numeric_prelude_haskellwiki.html) | *Numeric Prelude* — HaskellWiki (the "why `Num` is wrong" statement) | [`wiki.haskell.org/Numeric_Prelude`](https://wiki.haskell.org/Numeric_Prelude) | — | 40.8 KB |
| [`numeric_prelude_hackage.html`](./papers/haskell/numeric_prelude_hackage.html) | *numeric-prelude* — Hackage package page (module/class hierarchy) | [`hackage.haskell.org/package/numeric-prelude`](https://hackage.haskell.org/package/numeric-prelude) | — | 42.2 KB |
| [`olah2012_hasksymb.html`](./papers/haskell/olah2012_hasksymb.html) | *HaskSymb: An Experiment in Haskell Symbolic Algebra*<br>*Christopher Olah (2012-06-01)* | [`christopherolah.wordpress.com`](https://christopherolah.wordpress.com/2012/06/01/hasksymb-an-experiment-in-haskell-symbolic-algebra/) — **note:** the bibliography dates this 2012-11; the post is dated June 2012 | — | 81.9 KB |

---

## 7. `papers/wolfram-language/` — the evaluator behavioral spec (bibliography §6)

| File | Document | Source | Size |
| :--- | :--- | :--- | :--- |
| [`wolfram_ref_evaluation_of_expressions.html`](./papers/wolfram-language/wolfram_ref_evaluation_of_expressions.html) | *Evaluation of Expressions* — the full tutorial chapter, incl. the standard evaluation procedure and the Attributes section (~26k words) | [`reference.wolfram.com/.../tutorial/EvaluationOfExpressions.html`](https://reference.wolfram.com/language/tutorial/EvaluationOfExpressions.html) | 851.9 KB |
| [`wolfram_ref_evaluation.html`](./papers/wolfram-language/wolfram_ref_evaluation.html) | *Evaluation* — the guide page | [`.../tutorial/Evaluation.html`](https://reference.wolfram.com/language/tutorial/Evaluation.html) | 183.8 KB |
| [`wolfram_ref_attributes.html`](./papers/wolfram-language/wolfram_ref_attributes.html) | `Attributes` — the symbol reference page (full attribute list) | [`.../ref/Attributes.html`](https://reference.wolfram.com/language/ref/Attributes.html) | 212.8 KB |
| [`wolfram_guide_attributes.html`](./papers/wolfram-language/wolfram_guide_attributes.html) | *Attributes* — the guide page | [`.../guide/Attributes.html`](https://reference.wolfram.com/language/guide/Attributes.html) | 188.0 KB |
| [`wolfram_ref_associating_definitions.html`](./papers/wolfram-language/wolfram_ref_associating_definitions.html) | *Transformation Rules and Definitions* — the UpValues/DownValues rule-storage model in context | [`.../tutorial/AssociatingDefinitionsWithDifferentSymbols.html`](https://reference.wolfram.com/language/tutorial/AssociatingDefinitionsWithDifferentSymbols.html) | 496.8 KB |
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
| [`vonzurgathen_gerhard_cosec_companion.html`](./papers/web-articles/vonzurgathen_gerhard_cosec_companion.html) | *Modern Computer Algebra* companion site (errata & course material index) | [`cosec.bit.uni-bonn.de/science/mca/`](https://cosec.bit.uni-bonn.de/science/mca/) | 7.4 KB |

---

## Coverage against the bibliography

**Fully covered locally:** §1 (textbooks), §2 (term rewriting), §3 (foundational papers), §4
(pattern matching), §6 (Wolfram Language primary sources — one exception below), §7 papers, §9.

**Pointers only, by design:** §5 and §8 name *software systems* (Expreduce, Mathics, Symja, SymPy,
GiNaC, SymEngine, Maxima, Reduce, FriCAS, Symbolica, Maude, OBJ, Stratego, Rascal, Pure, FLINT…) and
§7 names *Hackage packages*. Those are source repositories, not documents; clone or browse them
rather than archiving them here. Where such an entry cites an actual paper, that paper is present
(SymPy, GiNaC, Rascal, Fateman/MockMMA).

### Not obtained

| Source | Bibliography § | Why |
| :--- | :--- | :--- |
| riptutorial, *Wolfram Language — Evaluation Order* | §6 | The site's Wolfram Language content is gone — `riptutorial.com/wolfram-language` now serves a generic landing page, `/topic/2549/evaluation-order` serves unrelated iOS content, and the Wayback Machine holds no snapshot of either URL. The material it summarized is covered in full by `wolfram_ref_evaluation_of_expressions.html`. |
| Axiom volumes as PDFs | §5 | `axiom-developer.org` does not resolve and no prebuilt volume PDFs were found; the upstream `.pamphlet` literate sources are stored instead. |
| Brun, *Building a CAS in Go*, parts 2+ | §9 | Only Part 1 is discoverable; no later installments found on Medium or in search. |

---

## Provenance caveat

Several textbook PDFs were obtained from Libgen and several papers from Sci-Hub, as recorded in the
Source column. The bibliography's "Availability at a Glance" section marks which of these titles are
in print and purchasable — Cohen Vols. 1–2, von zur Gathen & Gerhard, Baader & Nipkow, Bronstein,
Terese, and Jenks & Sutor. *A=B*, the arXiv papers, the Axiom material, the PeerJ SymPy paper, and
every HTML capture are freely and legally available from their publishers or authors.
