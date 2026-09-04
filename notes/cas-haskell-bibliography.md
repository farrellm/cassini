# Bibliography: Building a Computer Algebra System in Haskell

Full reference list for the reading & building guide. Entries are grouped by role in the project. Annotations note what each source is *for*, difficulty where relevant, and availability. Every entry has been checked against the local corpus in `references/` or, where no local copy exists, against the live primary source. Items still marked **[unverified]** could not be confirmed either way and should be checked before you rely on them.

---

## 1. Computer Algebra Algorithms — Textbooks, and the Papers That Fill Their Gaps

**Cohen, Joel S.** *Computer Algebra and Symbolic Computation: Elementary Algorithms.* A K Peters, 2002. ISBN 1-56881-158-6. Reprinted by Routledge/CRC. (9781568811581, often given as the reprint's ISBN, is simply the ISBN-13 of 1-56881-158-6 — the same 2002 printing, not a reissue.)
> Expressions as trees; structure-based operators; the *structure* of an automatically simplified expression (ch. 2 introduces automatic simplification under Expression Evaluation; ch. 3 covers Recursive Structure, incl. §3.2 Expression Structure and Trees and §3.3 Structure-Based Operators). Algorithms in "Mathematical Pseudo-Language" (MPL) with Maple, Mathematica, and MuPAD companions. Prerequisites per Cohen's preface: freshman–sophomore calculus through multivariable, elementary linear algebra, applied ODEs, a recommended discrete-mathematics course, and some programming experience — abstract-algebra topics are "introduced as needed," not assumed. **Note: the automatic-simplification *algorithm* is in Vol. 2, not here.** *Essential — Stage 0/1.*

**Cohen, Joel S.** *Computer Algebra and Symbolic Computation: Mathematical Methods.* A K Peters, 2003. ISBN 1-56881-159-4; Routledge/CRC reprint ISBN 9780367659479 **[unverified]** — the copy held is the 2003 A K Peters printing.
> **The volume with the automatic-simplification algorithm** — ch. 3, §3.1 *The Goal of Automatic Simplification* and §3.2 *An Automatic Simplification Algorithm* — plus ch. 2 on integer and rational arithmetic. Then polynomial decomposition, multivariate polynomials, resultants, side relations, and factorization (chs. 4–9) from the same implementer's angle. *Essential — Stage 0/1 for chs. 2–3, Stage 2/3 for the rest.*

**von zur Gathen, Joachim, and Jürgen Gerhard.** *Modern Computer Algebra.* 3rd ed. Cambridge University Press, 2013. 808 pp. ISBN 9781107039032.
> The deep reference: modular arithmetic, Chinese remainder, fast Euclidean algorithm, Hensel lifting, finite-field factorization, evaluation/interpolation. Complete proofs and complexity analysis; includes implementation reports. Edition history, commonly miscited: the **3rd** (2013) edition renovated ch. 11, the Fast Euclidean Algorithm (a correctness bug), and fixed ~80 further errors — nothing more. The new material in chs. 3, 15 and 22 (GCD, symbolic integration) came with the **2nd**, 2003 edition (copyright page: "Cambridge University Press 1999, 2003"; the companion site lists "Second edition 2003: ISBN 978-0521826464" and "First edition 1999: ISBN 0521641764"). February 2002 is that edition's preface date, which is where the "2002 edition" miscitation comes from. Companion site: `cosec.bit.uni-bonn.de` — addenda and corrigenda, and the source confirming the extent (808 pages, 40 tables, 560 exercises). Graduate difficulty; use as a lookup reference, not a linear read. *Essential as reference.*

**Geddes, Keith O., Stephen R. Czapor, and George Labahn.** *Algorithms for Computer Algebra.* Kluwer Academic Publishers, 1992. ISBN 0-7923-9259-0. Springer's book page for it is held in `references/`.
> The most complete single volume covering the whole implementer's pipeline: normal forms, polynomial/rational/power-series arithmetic, homomorphisms and CRT, Newton iteration and Hensel construction, polynomial GCD, factorization, solving systems of equations, Gröbner bases, integration of rational functions, and the Risch algorithm, “presented in a Pascal-like computer language”. Springer's page is also the source of the often-repeated line that this is “the first comprehensive textbook to be published on the topic of computational symbolic mathematics” — a publisher's claim, not the authors'; the book itself makes no such claim anywhere. *Essential — the one algorithms reference to own if you buy only one.* **Corpus caveat:** the held scan's table-of-contents pages are OCR noise (“In od ion”, “Algo i hm”) while the body text is sound — grep the body for chapter titles, not the TOC.

**Bronstein, Manuel.** *Symbolic Integration I: Transcendental Functions.* 2nd ed. Algorithms and Computation in Mathematics vol. 1. Springer, 2005.
> The standard integration reference: Hermite reduction, Rothstein–Trager, Lazard–Rioboo–Trager, and the Risch algorithm proper. 2nd ed. adds a chapter on parallel/Risch–Norman integration. Ready-to-implement pseudocode. **Volume II (algebraic functions) was never completed — Bronstein died before finishing it**, so the algebraic case remains scattered across research papers. *Essential at Stage 3.*

**Petkovšek, Marko, Herbert S. Wilf, and Doron Zeilberger.** *A=B.* A K Peters, 1996. Foreword by Donald E. Knuth.
> Algorithmic hypergeometric summation: Gosper's algorithm, Zeilberger's creative telescoping, the WZ method, Petkovšek's `Hyper`. Knuth's foreword is signed *Stanford University, 20 May 1995*. **Freely and legally available as a PDF** — the authors released it; mirrored on Wilf's UPenn page and Zeilberger's at Rutgers. Does *not* cover Karr's algorithm. *Essential for summation; free.*
> **Corpus caveat:** the copy held is that free PDF, and it is **not the A K Peters printing this entry cites**. It is the authors' electronic edition — internal title `PwzForPC.DVI`, Acrobat Distiller 3.0, created 27 April 1997, 217 pp. — and contains no publisher imprint, no ISBN, no copyright page and no occurrence of "1996" or "A K Peters" anywhere. It is byte-identical (md5 `02eff372…`) to what `www2.math.upenn.edu/~wilf/AeqB.pdf` serves today, so the availability claim is confirmed exactly; the *publisher and year* are not. Fourth instance of the held-copy-is-a-different-artifact pattern, after SymPy, Fateman and Ishii.

**Karr, Michael.** "Summation in Finite Terms." *Journal of the ACM* 28, no. 2 (1981): 305–350. DOI: 10.1145/322248.322255.
> The difference-field ("ΠΣ-field") theory of symbolic summation — the discrete analogue of Risch's integration algorithm, and **the gap in *A=B***, which covers Gosper/Zeilberger/WZ but not this. Read it when indefinite nested sums and products come up. See also his **"Theory of Summation in Finite Terms," *Journal of Symbolic Computation* 1, no. 3 (1985): 303–315, DOI: 10.1016/S0747-7171(85)80038-9.** *Optional; needed only for the summation requirement.*
> **Corpus caveat:** the 1985 paper's copy in `references/` has a text layer, but its OCR systematically drops the letter `h` — "Teory of Summation", "matematical", "algoritm", "te" for "the". Searches for `the` or `theorem` return nothing and look like honest misses. **The 1981 paper is not clean either** — it was described that way here until the sixth round. Its defect is different and subtler: scattered runs of prose extract letter-spaced ("p a p e r", "c o n c e r n e d w i t h"), so a grep succeeds while *under-counting*. `theorem` returns 76 hits against 100 actually present. Nothing looks wrong, which is the danger.

**Schneider, Carsten.** "Symbolic Summation Assists Combinatorics." *Séminaire Lotharingien de Combinatoire* 56 (2007), Article B56b. Free from RISC (`www3.risc.jku.at`).
> The modern continuation of Karr: the **Sigma** Mathematica package, built on Karr's algorithm with extensions for non-trivial multi-sum problems. The practical entry point to difference-field summation, and easier going than Karr's papers. *Optional; free.*

**Zippel, Richard.** *Effective Polynomial Computation.* Kluwer Academic Publishers, 1993. Kluwer International Series in Engineering and Computer Science 241. 363 pp. Springer softcover reprint ISBN 978-1-4613-6398-9; the original Kluwer hardback ISBN is often given as 0-7923-9375-9 **[unverified]**.
> Practical vs. theoretical tradeoffs in polynomial algorithms, by the originator of sparse modular ("Zippel") interpolation for multivariate GCD. Strong on where asymptotically optimal algorithms are the wrong practical choice. Out of print but findable. *Optional; valuable at Stage 2.*

**Davenport, James H., Yvon Siret, and Évelyne Tournier.** *Computer Algebra: Systems and Algorithms for Algebraic Computation.* 2nd ed. Academic Press, 1993. Preface by Daniel Lazard.
> Gentler, systems-oriented survey. Good conceptual overview; less of an implementation cookbook. *Optional.*

**Jenks, Richard D., and Robert S. Sutor.** *AXIOM: The Scientific Computation System.* Springer, 1992. Original ISBNs 3-540-97855-0 (Berlin) / 0-387-97855-0 (New York) **[unverified]**; the Springer Science+Business Media reprint held here is ISBN 978-1-4612-7729-3 (print) / 978-1-4612-2940-7 (eBook), 765 pp.
> The design document for the strongly-typed CAS — categories and domains (Ring, Field, …) as first-class types. Now Volume 0 of the open Axiom literate-program series. *Essential reading for a Haskell implementer* because Axiom's typed algebra hierarchy is the closest existing analogue to a type-driven Haskell CAS. See §5 for the free literate volumes.

---

## 2. Textbooks — Term Rewriting

**Baader, Franz, and Tobias Nipkow.** *Term Rewriting and All That.* Cambridge University Press, 1998. Hardback ISBN 0-521-45520-0 (the printing held, and the one that ISBN is verified against); paperback 0-521-77920-0 / 9780521779203 **[unverified]**.
> The book for the evaluator layer. Chapter map: 1 Motivating Examples, 2 Abstract Reduction Systems, 3 Universal Algebra, 4 Equational Problems (congruence closure, syntactic unification), 5 Termination, 6 Confluence (critical pairs, orthogonality), 7 Completion (Knuth–Bendix, Huet), 8 Gröbner Bases and Buchberger's Algorithm, 9 Combination Problems, 10 Equational Unification (commutative; associative-commutative), 11 Extensions (rewriting modulo equational theories, conditional rewriting, reduction strategies). **Read chs. 1–2 and 5–7 first — chs. 1–4 alone contain no termination, confluence or completion** — then 10–11 when the AC matcher lands. Main algorithms given informally *and* as Standard ML (with an ML primer in Appendix 2); the *efficient* unification and congruence-closure programs are in Pascal. Over 170 exercises. *Essential — read in parallel with Cohen.*

**Terese** (Marc Bezem, Jan Willem Klop, Roel de Vrijer, eds.). *Term Rewriting Systems.* Cambridge Tracts in Theoretical Computer Science 55. Cambridge University Press, 2003.
> The comprehensive advanced reference, 908 pp. *Optional — only if you need confluence/termination theory beyond Baader & Nipkow.* (The copy in `references/` is an image-only scan with no text layer; it cannot be grepped.)

**Klop, Jan Willem.** "Term Rewriting Systems." In *Handbook of Logic in Computer Science*, Vol. 2, ed. Abramsky, Gabbay & Maibaum (Oxford University Press, 1992), pp. 1–116. Circulated by CWI as report `CS-R9053`.
> The classic full survey of rewriting theory: abstract reduction systems (with Knuth–Bendix completion and (E-)unification), orthogonal TRSs and reduction strategies, strong sequentiality, and conditional TRSs. ~112 pp. **Get it as the standalone PDF, not from the Handbook** — the Handbook scan is images only and cannot be searched, whereas the standalone has a full text layer. Two labelling notes: the text carries no report number of its own, and it cites work through 1991, so it is the Handbook-chapter text rather than strictly the 1990-numbered preprint. **Not freely obtainable** — the copy held here was supplied, and `CS-R9053` could not be located free; the ICALP'90 survey below is the free way into the same material. *Optional.*

**Klop, Jan Willem.** "Term Rewriting Systems: From Church-Rosser to Knuth-Bendix and Beyond." *ICALP '90*, Springer LNCS 443. Free from CWI's repository (`ir.cwi.nl/pub/2667`).
> The 20-page version: abstract rewriting, Combinatory Logic, orthogonal systems, strategies, critical pair completion, extended rewriting formats. The cheap way into the same material. *Optional; free.*

---

## 3. Foundational Papers

**Richardson, Daniel.** "Some **Undecidable** Problems Involving Elementary Functions of a Real Variable." *Journal of Symbolic Logic* 33, no. 4 (Dec. 1968): 514–520. DOI: 10.2307/2271358.
> Richardson's theorem: for expressions built from the rationals, π, ln 2, a variable *x*, addition/subtraction/multiplication/composition, and `sin`, `exp`, `abs`, the predicate "E = 0?" is unsolvable. Precisely: condition (1) is that the function class contain log 2, π, eˣ and sin x; condition (2) that it contain some μ with μ(x) = |x| for x ≠ 0 (√x² will do). Conditions (1)+(2) give the identity problem; (1)+(2)+(3) give the integration problem. **The reason no CAS simplifier can be complete.** Read the statement even if you skip the proof. *The title is very commonly miscited as "Unsolvable" — it is "Undecidable".*

**Swierstra, Wouter.** "Data types à la carte." *Journal of Functional Programming* 18, no. 4 (2008): 423–436. DOI: 10.1017/S0956796808006758.
> ASTs as coproducts of functors (`data (f :+: g) e = Inl (f e) | Inr (g e)`) with `Fix` and a subtyping class `(:<:)`. The reference solution to the expression problem in Haskell. Wadler's verdict — on his blog, 28 Feb 2008, *not* in the paper, which cites him only as the problem's namer — was that it "presents the best solution to the Expression Problem that I've seen in Haskell (well, Haskell with `-fglasgow-exts`)." *Read for context; likely unnecessary if your core `Expr` is untyped and uniform.*

**Bahr, Patrick, and Tom Hvitved.** "Compositional Data Types." *Workshop on Generic Programming*, 2011. DOI: 10.1145/2036918.2036930. See also **Pickering, Matthew.** "Data Types à la Carte with Closed Type Families" (20 Dec 2014, `mpickering.github.io`) — a reimplementation of Swierstra's `(:<:)` machinery using closed type families, held in `references/`.
> Productionized descendants of "Data types à la carte." *Optional.*

**Cole, Christopher A., and Stephen Wolfram.** "SMP: A Symbolic Manipulation Program." *Proceedings of the 1981 ACM Symposium on Symbolic and Algebraic Computation (SYMSAC '81)*.
> The earliest primary source on the symbolic-expression + transformation-rule architecture that became Mathematica. **Paywalled (ACM)** — *not* on Wolfram's content servers, which host the SMP manual instead (below).

**Greif, Jerry.** "The SMP Pattern-Matcher." *EUROCAL '85*, Springer LNCS 204.
> The earliest published description of how this family of pattern matchers was designed. **Paywalled (Springer LNCS)**, likewise not on Wolfram's servers.

**Wolfram, Stephen, with Chris A. Cole et al.** *SMP: A Symbolic Manipulation Program* — Summary (73 pp.), Primer (88 pp.), Reference Manual (238 pp.). California Institute of Technology, 1981. Free from `content.wolfram.com`.
> SMP's own documentation, and the substantial free primary source on the system — where the two conference papers above are three and twelve pages behind paywalls. The **Primer's §3, *Patterns***, is the one to read: the matcher as it stood before Wolfram separated pattern constructs from names. Held in `references/`.

*(The AC-discrimination-net papers by Bachmair et al., previously listed here, now sit with the rest of the matching literature in §4.)*

---

## 4. Pattern Matching — The Hard Engineering

**Krebber, Manuel.** "Non-linear Associative-Commutative Many-to-One Pattern Matching with Sequence Variables." Master's thesis, RWTH Aachen. arXiv:1705.00907.
> The most complete single document on the combined feature set you need: AC matching + sequence variables + non-linear patterns + many-to-one via discrimination nets. *Essential for Stage 1 matcher design.* Free.

**Krebber, Manuel, Henrik Barthels, and Paolo Bientinesi.** "MatchPy: A Pattern Matching Library." arXiv:1710.06915. (SciPy 2017.) And, by the same authors, **"Efficient Pattern Matching in Python," arXiv:1710.00077** — the companion on the algorithms and their measured performance. Both free.
> The readable modern treatment of Mathematica-style matching: syntactic plus associative and/or commutative functions, sequence variables (the `BlankSequence`/`BlankNullSequence` analogue), constraints, many-to-one discrimination nets. Open-source Python implementation. Key facts: general AC matching is **NP-hard** and worst-case exponential — the underlying result is Benanav, Kapur & Narendran (below), which Krebber cites for AC matching being NP-complete. Discrimination nets conventionally treat patterns as linear and check repeated-variable equivalence "in an extra step," but note that **MatchPy itself departs from this**, performing "the full non-linear matching directly at a commutative symbol state instead of just using it as a filter." **Both complexity results belong to Benanav (below), not to two different papers** — see that entry. One more thing not to over-read: Krebber's warning that a net's "number of states can grow exponentially with the number of patterns" is about the *syntactic* (variadic) discrimination nets he benchmarks against, not the many-to-one net he builds — that one he measures growing sublinearly in practice. Free.

**Benanav, Dan, Deepak Kapur, and Paliath Narendran.** "Complexity of Matching Problems." *Journal of Symbolic Computation* 3, no. 1 (Feb. 1987): 203–216. DOI: 10.1016/S0747-7171(87)80027-5.
> **The citation for *both* AC-matching complexity claims** — a point routinely got wrong, including in earlier drafts of these notes. The abstract proves that "the associative-commutative matching problem is shown to be NP-complete", *and* that "if every variable appears at most once in a term being matched, then the associative-commutative matching problem is shown to have an upper-bound of O(|s|·|t|³)" — i.e. the polynomial bound for **linear** patterns is here too, not in Eker. Their algorithm already uses maximum bipartite graph matching. Both Eker and Bachmair et al. cite this paper for both results.

**Eker, Steven M.** "Associative-Commutative Matching via Bipartite Graph Matching." *The Computer Journal* 38, no. 5 (1995): 381–399. DOI: 10.1093/comjnl/38.5.381.
> **A practical algorithm, not a complexity result.** Builds "a hierarchy of bipartite graph matching problems which encodes all the possible solutions of subproblems", then solves the resulting semi-pure AC systems exhaustively, with refinements that "considerably cut down the search space" — aimed at running efficiently on non-pathological instances of the *general*, non-linear problem. Eker credits Benanav for both bounds. The byline is INRIA Lorraine, where the acknowledgements say the research was done; the paper itself "was written at Rutherford Appleton Laboratory", and the contact address on it is already `eker@csl.sri.com` — this is the lineage Maude's AC matcher is built on. (No month is given for the issue: the paper is stamped "Received September 16 1993, revised July 7 1995", so the "May 1995" some catalogues carry cannot be right.) Krebber's many-to-one matcher uses the same bipartite construction at commutative states. *The paper to read for how to make AC matching fast; cite Benanav, not this, for the complexity.*
> **Corpus caveat:** the copy in `references/` is image-only and carries a generated `.txt` OCR sidecar beside it. Worse, it *reports* extractable text on every page — but the only text is an Oxford download watermark repeated, 860 characters across 19 pages. A naive text-layer check passes it; grep the sidecar instead.

**Bachmair, Leo, Ta Chen, and I. V. Ramakrishnan.** "Associative-Commutative Discrimination Nets." *TAPSOFT '93: Theory and Practice of Software Development* (CAAP/FASE, Orsay), Springer LNCS 668, 1993, pp. 61–74. DOI: 10.1007/3-540-56610-4_56.
> Introduces the data structure: an AC-discrimination net that "is a natural generalization of the standard discrimination net in the sense that if no AC-symbols are present in the pattern, it specializes to the standard discrimination net." Useful third-party confirmation of the complexity attribution above — it states that one-to-one AC matching "can be solved in polynomial time if patterns are restricted to linear terms", credits Benanav et al. for it, and notes that "the essential component of the one-to-one AC-matching algorithm described by Benanav, Kapur, and Narendran is the application of maximum bipartite graph matching." Also cites Verma & Ramakrishnan for the result that AC matching and maximum bipartite graph matching are mutually reducible.
> **Corpus caveat:** the copy in `references/` is image-only, with a generated `.txt` OCR sidecar beside it. Grep the sidecar.

**Bachmair, Leo, Ta Chen, I. V. Ramakrishnan, Siva Anantharaman, and Jacques Chabin.** "Experiments with Associative-Commutative Discrimination Nets." *IJCAI '95*, pp. 348–354. Free from `ijcai.org`.
> The measurement paper for the above. Read both before optimizing your matcher — not before writing it.

---

## 5. Open-Source Systems to Study

Ordered roughly by relevance to a Wolfram-style Haskell build.

**Expreduce** (Cory Walker). Go. `github.com/corywalker/expreduce`
> **The single most relevant codebase.** From-scratch Wolfram Language term-rewriter/CAS with Blank/BlankSequence, Orderless/Flat matching, conditional rules, attributes, and the fixed-point evaluator. The README describes it as "experimental quality and… not currently intended for serious use" — which makes it small and readable. *Lesson: how to structure evaluator + matcher in a statically typed host language.*

**Mathics / Mathics3.** Python, GPL v3. `github.com/Mathics3/mathics-core`
> A fuller open Wolfram Language kernel: parser building Expressions, evaluator, WL built-ins, delegating heavy math to SymPy and mpmath. *Lesson: realistic module layout for a batteries-included WL kernel.*

**Symja.** Java; GPL v3 throughout, with the `parser`, `external` and `core` Maven modules relicensed LGPL from version 2.0.0 — the carve-out is what starts there, not the GPL. Formerly MathEclipse. `github.com/axkr/symja_android_library`
> A long-lived WL reimplementation; mature parser, large function library. Its README confirms it implements `Integrate` from the Rubi ruleset but names no version; per Symbolica's writeup it is "the only other complete port," based on **Rubi 4.16**. *Lesson: grep for specific algorithm implementations.*

**MockMMA** (Richard Fateman, 1991). Lisp.
> The earliest WL reimplementation. The widely repeated cease-and-desist story traces to a single sentence in Wikipedia's *Wolfram Language* article — "Richard Fateman's MockMMA from 1991 is of historical note, both for being the earliest reimplementation and for having received a cease-and-desist from Wolfram" — which carries **no citation**; the adjacent footnote belongs to the sentence after it. Treat it as folklore until sourced. (Capture held in `references/`, 2026-08-30.) *Historical.*
> - **Fateman, Richard J.** "A Review of Mathematica." *Journal of Symbolic Computation* 13, no. 5 (1992). A separate document, and the one actually worth reading: not implementation notes but a sharp design critique of the language, evaluator and pattern matcher, from someone who had built a competing system. **Corpus caveat:** the copy in `references/` is an author copy carrying no journal metadata at all — only "(Received: 16 November 1990) (Revised: 16 September 1991)" — so the *JSC* 13(5), 1992 citation cannot be confirmed from the file itself. It mentions neither MockMMA nor the cease-and-desist story.

**SymPy.** Python, BSD. `sympy.org`
> The most approachable *full* CAS to read. Pure Python with no invented language — the reference paper notes that Python itself is used for both internal implementation and end-user interaction. *Lesson: how to organize a large CAS — assumptions system, `Basic`/`Expr` core, `polys` module — and how automatic-simplification decisions get made.*
> - **Meurer, Aaron, et al.** "SymPy: symbolic computing in Python." *PeerJ Computer Science* 3 (2017): e103. DOI: 10.7717/peerj-cs.103. (27 authors, 27 pp.) Free. **Quote the published article, not the preprint** — `references/` held the *PeerJ Preprints* review manuscript under this citation until 2026-08-30, and the two are distinguishable on sight: 27 pp. and 27 authors here, 19 pp. and 24 authors there, and a for-review-only footer on every page of the manuscript. They also differ by a stray apostrophe in the sentence most often quoted, so check which text a quotation came from. The manuscript is deliberately not held; nothing in these notes should quote it.

**GiNaC** ("GiNaC is Not a CAS"). C++. `ginac.de`
> *Lessons:* (1) deliberately abolishes the low-level/high-level language split — relevant to a Haskell-native ambition; (2) reference counting with copy-on-write for structure sharing; (3) numeric tower built on CLN (the paper does not mention GMP); (4) clean polymorphic `ex`/`basic` design with automatic normalization.
> - **Bauer, Christian, Alexander Frink, and Richard Kreckel.** "Introduction to the GiNaC Framework for Symbolic Computation within the C++ Programming Language." *Journal of Symbolic Computation* 33, no. 1 (2002): 1–12.

**SymEngine.** C++ core with bindings in many languages, including a thin Haskell FFI package (`symengine` on Hackage).
> The fast C++ rewrite of SymPy's core. *Lesson: the "fast typed core + scripting frontend" architecture.* Also a candidate to FFI into if you'd rather not write your own numeric/polynomial backend.

**Maxima.** Common Lisp. The open descendant of MIT Macsyma.
> *Lesson: the untyped-expression paradigm in its native habitat* — why homoiconic s-expressions map so naturally onto expression trees, and how a 50-year-old general simplifier and rule system (`tellsimp`, `defrule`) is structured. Large and old; grep, don't read cover to cover. Macsyma is the ancestor of this whole lineage — Wolfram had "written lots of code for systems like Macsyma" before SMP. (He used Schoonschip too, and took the floating-point advice from its author, but the 2013 essay does not say he studied its code.)

**Reduce.** Lisp. Open source.
> The other long-lived Lisp CAS. Same lesson as Maxima, different design choices.

**Axiom / FriCAS.** Lisp core + SPAD algebra language. Sources: `github.com/daly/axiom/books` (`axiom-developer.org` no longer resolves), `fricas.github.io`
> Distributed as a **literate program in ~15 numbered volumes**, freely available as `.pamphlet` LaTeX+SPAD sources — no prebuilt volume PDFs survive: Vol. 0 (Jenks & Sutor), Vol. 10.x covering algebra implementation, theory, categories, domains, and packages. FriCAS maintains a modern regeneration of Vol. 0 as *The FriCAS System for Computer Mathematics*. The volumes explain the *why* of a rigorous typed algebra hierarchy. *Essential background for the typed-vs-untyped decision.*

**Symbolica.** Rust, with Python/C++ bindings. `symbolica.io`
> Modern, source-available, high-performance CAS — in its own words "a high-performance computer algebra library for Python and Rust" for manipulating "large expressions" at speed. (**"Built for large expressions" is not Symbolica's wording** and never was: not on the home page now, and not in the 2023 snapshot, which said "a blazing fast symbolic manipulation toolkit". Earlier drafts of these notes quoted it; both captures are now held so the point stays checkable.) Its pattern matcher, in Symbolica's words, "supports commutative and associative matching, and has wildcards (variables ending in underscores) that can match to any subexpression" — that sentence is from the *Symbolica 2.2* integration writeup; the separate *pattern matching* post demonstrates the same capability as `is_symmetric=True` on a symbol, without using the word "commutative". Per Symbolica's own writeup it provides "the only complete port of the latest Rubi 4.17 integration system outside the Wolfram Language, preserving its 7,000+ ordered rules and passing the complete 72,944-problem Rubi corpus" (MIT-licensed `symbolica-integrate` crate), processing that corpus "in 18 minutes of wall time, on a Ryzen 9 5900X parallelized over 8 cores" (57 ms median per problem). **These are vendor-reported figures.** *Lesson: rule-based integration as a pragmatic complement to Risch, and how to make AC matching fast.*
> **License caveat:** source-available but commercially licensed, and the trigger is employment rather than commerce — "Symbolica is free for hobbyist use. If you use Symbolica as part of your employment, whether in academia or in a commercial or non-commercial organization, a license is required." The separate **Free** tier — not the Hobbyist one — is the one capped at "[o]ne core and instance per device", "for academic/non-commercial use". Redistribution, "modified or unmodified, requires prior written permission". Fine to read; check the license before depending on it.

**Rubi** (Albert Rich). `rulebasedintegration.org`
> The rule-based integration ruleset. Rich's "Vision" page describes "over 6600 integration rules" and states that "Rubi 4.15 has 6,662 rules" — note the discrepancy with Symbolica's "7,000+" count of its port of Rubi 4.17.

**Singular, CoCoA, Macaulay2.** Specialized: Gröbner bases, commutative algebra, algebraic geometry.
> Consult selectively at Stage 3 for specific algorithms done fast and correctly.

**PARI/GP.** C. Number theory.

**FLINT.** C. Fast Library for Number Theory.
> The modern high-performance substrate under Sage and others; the reference for state-of-the-art polynomial and bignum performance.

---

## 6. Wolfram Language Primary Sources

**Wolfram Research.** "Evaluation." Tech note, Wolfram Language & System Documentation Center, `reference.wolfram.com/language/tutorial/Evaluation.html`. Free.
> **The authoritative behavioral spec, and the single most important page for Stage 1.** Its section "The Standard Evaluation Sequence" gives the whole algorithm in order, for `h[e1, e2, …]`: (1) raw objects (`Integer`, `String`, …) are left unchanged; (2) evaluate the head `h`; (3) evaluate each element `eᵢ` in turn; (4) `HoldFirst`/`HoldRest`/`HoldAll`/`HoldAllComplete` skip evaluation of certain elements; (5) unless `SequenceHold` or `HoldAllComplete`, flatten `Sequence` objects; (6) unless `HoldAllComplete`, strip outermost `Unevaluated` wrappers; (7) `Flat` flattens nested same-head expressions; (8) `Listable` threads over lists; (9) `Orderless` sorts; (10) user-defined rules for `h[f[e1,…],…]`; (11) built-in rules associated with `f`; (12) user-defined rules for `h[e1,e2,…]` or `h[…][…]`; (13) built-in rules for the same. Then the fixed point: "every time the expression changes, the Wolfram Language effectively starts the evaluation sequence over again." Note that steps 7–9 fix the attribute order as **Flat → Listable → Orderless**, that step 5 precedes step 6, and that steps 10–13 are a four-way ladder — so built-in upvalues beat *user* downvalues. (Numbering caveat: the page itself gives *twelve* steps, and gives them as a bullet list rather than a numbered one — count them off. The thirteen above split its third into element evaluation and the hold check, so from step 4 on, the source's position is one lower. Its step 11 also reads `h[f[e1,e2,…],…]` where step 12 reads `h[e1,e2,…]` — an inconsistency on Wolfram's side; the latter is right.)

**Wolfram Research.** "Evaluation of Expressions." Tech note, `reference.wolfram.com`. Free.
> The longer companion: a coarser six-step summary of the same procedure, the full attribute table, worked evaluation traces, and the prose precedence rule — "the Wolfram System always tries upvalue definitions before downvalue ones," with the complete `f[g[x]]` order spelled out. Use this one for the explanations and examples, and "Evaluation" above for the algorithm.

**Wolfram Research.** "Transformation Rules and Definitions" (`tutorial/AssociatingDefinitionsWithDifferentSymbols`). Free.
> **The substantive source for the rule-storage model** — where upvalues and downvalues attach, in context and with worked examples. Prefer it to the four symbol reference pages below, whose captures are mostly navigation chrome.

**Wolfram Research.** Documentation on **OwnValues, DownValues, UpValues, SubValues**. Free.
> The model in one line each: OwnValues are the symbol's own value (`x = 5`); DownValues attach rules to a symbol as head (`f[...] := ...`); UpValues attach to a symbol appearing as an *argument*; SubValues are "values for `f[…][…]…`", i.e. curried heads. Model these as four separate rule tables keyed by symbol — OwnValues included, so plain assignment falls out of the same machinery. These reference pages give little beyond those definitions; go to the tutorial above for the reasoning.

**Wolfram Research.** Documentation on **Attributes**: `HoldAll`, `HoldFirst`, `HoldRest`, `HoldAllComplete`, `Flat`, `Orderless`, `Listable`, `OneIdentity`, `SequenceHold`, `Protected`, `Constant`. Free.
> `OneIdentity` in particular affects pattern matching — the attribute table's wording is "`f[f[a]]`, etc. are equivalent to `a` for pattern matching" — and is easy to get wrong. **Do not go to `ref/Attributes` for the list** — that page carries only the `Attributes[symbol]` signatures. The full attribute table, each entry with its one-line meaning, is inside *Evaluation of Expressions*.

**riptutorial.** "Wolfram Language — Evaluation Order." **Dead — do not cite.**
> The site's Wolfram Language content is gone and no Wayback snapshot exists. Everything it summarized is in *Evaluation of Expressions* above, including the point that `Hold`, `HoldComplete`, `HoldForm`, `ReleaseHold` and `Unevaluated` are not evaluator special cases but fall out of attributes plus ordinary definitions.

**Wolfram, Stephen.** "There Was a Time before Mathematica…" (2013). `writings.stephenwolfram.com`. Free.
> SMP's design and the origin of the symbolic-expression + transformation-rule paradigm. **Read the famous line carefully:** "quite a bit of that code is still running in Mathematica today, especially in the pattern matcher and evaluator" refers to the *Mathematica* code Wolfram wrote in 1986–88, not to SMP code — the essay is explicit that SMP's surface design was reworked, not carried over.

**Wolfram, Stephen.** "Celebrating a Third of a Century of Mathematica…" (2021). `writings.stephenwolfram.com`. Free.
> The clearest statement of the core design decision: represent everything as a symbolic expression, represent all operations as transformations, and apply the first transformation that applies until nothing changes.

**wltools.** "Wolfram Language Specification" community project. `wltools.github.io`.
> Community reverse-engineering of WL semantics. **Informed inference, not authoritative** — the kernel is closed source.

---

## 7. Haskell — Papers, Libraries, and Design

### Papers

**Ishii, Hiromi.** "A Purely Functional Computer Algebra System Embedded in Haskell." arXiv:1807.01456. Published in *Computer Algebra in Scientific Computing (CASC 2018)*, Springer LNCS 11077, pp. 288–303. DOI: 10.1007/978-3-319-99639-4_20.
> **The reference for typed algebra in Haskell.** Encodes polynomial arity, monomial ordering, and coefficient ring as type-level parameters so elements of ℚ[x,y,z] and ℚ[w,x,y] can't be added by mistake. Implements Gröbner bases with F4, F5, and Hilbert-driven algorithms. Positioned explicitly against DoCon "with more emphasis on safety and correctness." *Caveat: the type system checks arity and identity, not ring axioms — those are verified by QuickCheck property tests, not proof.* Free on arXiv.
> **Corpus caveat:** the copy held is the **arXiv pre-print** (`arXiv:1807.01456v2`, 16 pp.), which says so on its own last page — "This is a pre-print of an article published in 'Computer Algebra in Scientific Computing' (2018)" — and carries only the *book*-level DOI `10.1007/978-3-319-99639-4`. The LNCS volume number, the page range and the chapter DOI `…_20` in the citation above appear nowhere in the file; they are verified against Crossref, which confirms the title, "Lecture Notes in Computer Science", pages 288–303, 2018, and the CASC editors (Gerdt, Koepf, Seiler, Vorozhtsov). Same shape as the Fateman and SymPy findings: quote the text freely, but do not treat the published-venue details as confirmed by the held file.

**Zhu, Bowen, Aayush Sabharwal, Songchen Tan, Yingbo Ma, Alan Edelman, and Christopher Rackauckas.** "Efficient Symbolic Computation via Hash Consing." arXiv:2509.20534 (MIT / JuliaHub).
> An implementation report on adding hash-consing to JuliaSymbolics via a global **weak-reference** table (up to 3.2× faster, 2× less memory), not a survey — but its short related-work section is the useful map, and it is more negative than usually reported. the **common subexpression elimination code** in SymPy and SymEngine is "implemented by storing identical subexpressions in a set data structure, instead of by leveraging the DAG structure" — a claim about their CSE passes, not their expression representation; FriCAS and REDUCE get Lisp symbol interning but no proper hash-consing; **GiNaC "does use a form of reference counting," and of GiNaC and Symbolica alike it says "it is trivial to construct programs using either package that demonstrate identical subexpressions with different memory locations"** — i.e. neither hash-conses. On closed source it notes only that a Wolfram-internals page contains descriptions that "suggest hash-consing is used internally," with "no description of the performance effects." **Implication for you (our inference, not theirs): the mechanism needs immutable terms plus a GC that collects through weak references — precisely Haskell's model.** Free.

### Libraries

**`computational-algebra`** (Hiromi Ishii). `github.com/konn/computational-algebra`
> The implementation accompanying the paper above. Depends on his `type-natural` and `ghc-typelits-presburger` (a Presburger arithmetic type-checker plugin) packages.

**`algebra`** (Edward Kmett). Hackage / `github.com/ekmett/algebra` — the package page is held in `references/`.
> "Constructive abstract algebra", and what Ishii's CAS builds on. The hierarchy, read off its own module and class index: an **additive/multiplicative split** (`Numeric.Additive.*` against the `Multiplicative` class), through `Monoidal` and `Group` to `Rig`/`Rng`/`Ring`, then `Module`, then `Algebra`/`Coalgebra` — plus the `Numeric.Domain.*` tower that a coefficient tower actually needs, whose superclass chain is `Domain` → `IntegralDomain` → `GCDDomain` → `UFD` → `PID` → `Euclidean`. **It has no `Magma` class, and its pages prescribe `RebindableSyntax` nowhere** — both were asserted here until the eighth round; the magma-rooted hierarchy is `numhask`'s, and the `RebindableSyntax` point belongs to the numhask/numeric-prelude comparison. *Recommended as your coefficient tower.*

**`numeric-prelude`** (Dylan Thurston, Henning Thielemann, Mikael Johansson). Hackage — **the README is where the argument lives**; the HaskellWiki "Numeric Prelude" page adds the structure list and the *Future plans* section.
> The canonical statement of **why the standard `Num` class is wrong for a CAS**, in four distinct objections — keep them apart, the last two are not one point: it "defines no semantics for the fundamental operations" (nothing asserts associativity of addition); it has "superfluous superclasses" — `Eq` and `Show` under `Num`, impossible to satisfy non-trivially for e.g. a function-valued ring (`data IntegerFunction a = IF (a -> Integer)`); it carries "a mix of semantic operations and representation specific operations" (`toInteger`, `toRational`, `decodeFloat`); and "the hierarchy is not finely grained enough", so that "operations that are often defined independently are lumped together" — its example being that defining `+` for a `Dollar` or `Vector` type forces `*` on you as well. Splits `Num` into `Additive`, `Ring`, `Field`, `Algebraic`, `Transcendental`, etc. (`Num → Additive, Ring, Absolute`; `Fractional → Field`; `Floating → Algebraic, Transcendental`). Axioms are stated as QuickCheck properties. The wiki candidly documents the gaps: "the code still misses proper linear algebra code," and static checking is still unsolved for "residue classes, matrix computations, infinite precision numbers, fixed point numbers." It does rely on extensions beyond Haskell 98: the wiki's opening sentence names **multi-parameter type classes** specifically.

**`numhask`** (Tony Day). Hackage — the package page is held in `references/`.
> A cleaner, more recently maintained alternative hierarchy. `RebindableSyntax` is not the distinguishing feature — both package pages prescribe it. Upkeep is: numhask's Hackage release is dated 2026-07-10, numeric-prelude's 2022-05-28 — with the caveat, from the same page, that numeric-prelude's metadata was revised 2025-05-19, so the gap is in releases rather than in attention.

**`poly`** (Andrew Lelechenko / Bodigrim). Hackage.
> Fast `Vector`-backed uni- and multivariate polynomials with Karatsuba multiplication, integrating with the `semirings` `GcdDomain`/`Euclidean` classes. Documented as "at least 20x-40x faster than the [`polynomial`] library" — a self-reported figure, though the published per-operation benchmarks (22–39× on addition, 52–303× on multiplication) are consistent with it.

**`constructive-algebra`** (Anders Mörtberg et al.). Hackage — the package page is held in `references/`.
> Small and very readable constructive ring/ideal/matrix code. Its page states the design point directly: "Classical structures are implemented without Noetherian assumptions. This means that it is not assumed that all ideals are finitely generated" — so principal ideal domains give way to Bezout domains. Good reading rather than a dependency.

**`recursion-schemes`** (Edward Kmett) and **`data-fix`**. Hackage.
> `cata`/`ana` over a base functor — the clean way to write folds, evaluators, and substitution over your `Expr`.
> - **Penner, Chris.** "ASTs with Fix and Free" (24 Feb 2018), `chrispenner.ca/posts/asts-with-fix-and-free`. The readable how-to: parameterize the recursive slots, derive `Functor`, then use `Fix` for a plain AST and `Free` for one with holes. The practical companion to the à-la-carte paper in §3.
> - **Milewski, Bartosz.** The *Category Theory for Programmers* posts on F-algebras, catamorphisms, and free monads (`bartoszmilewski.com`). The theory underneath the same constructions, if you want to know *why* `Fix` and `Free` are the right shapes.

**`uniplate`** (Neil Mitchell). Hackage.
> Generic traversal/rewriting over your expression type. The pragmatic choice for a uniform untyped `Expr`.

**`sbv`** (Levent Erkök). Hackage — the `Data.SBV` haddock page is held in `references/`.
> **Which numeric classes a symbolic type can reuse, and which it cannot** — the question a CAS `Expr` hits immediately. `SBV a` belongs to the "standard classes `Num`, `Bits`", but *not* to `Eq` or `Ord`: those return `Bool` and `Ordering`, and a symbolic comparison cannot. The page says so twice — "we can't use Haskell's `Eq` class since Haskell insists on returning `Bool`" and "we cannot implement Haskell's `Ord` class since there is no way to return an `Ordering` value from a symbolic comparison" — and supplies "custom versions of `Eq` (`EqSymbolic`) and `Ord` (`OrdSymbolic`)" whose `.==` and `.>` return `SBool`. **Do not describe this as overloading `Num`/`Ord`**; the `Ord` half is the opposite, and the split is the lesson. Also offloads to an SMT solver like Z3, useful for zero-testing side conditions; *not* a rewriting engine.

**`symengine`.** Hackage.
> Thin FFI bindings to the SymEngine C++ core, if you want a fast external backend.

**`dumb-cas`** (Justus Sagemüller). Hackage.
> "A computer \"algebra\" system that knows nothing about algebra, at the core": untyped symbolic computation with the transformation rules *you* supply rather than baked-in algebra, combining "the flexibility of a Lisp with the conciseness of a Regex engine." Minimal, but worth reading as a starting point, since **no Haskell library offers Mathematica-grade pattern matching off the shelf.**

**DoCon** (Sergei D. Mechveliani).
> The pioneering Haskell CAS. Used runtime "sample arguments" for ring identity — the design Ishii explicitly improves on. Historical reference.

**HaskSymb** (Christopher Olah, 2012). `github.com/colah/HaskSymb`; blog post 1 June 2012.
> Small, readable illustration of untyped symbolic rewriting with QuasiQuoters and ViewPatterns. **Read the repository README for the author's conclusion** — the blog post is only a demo of `expand`/`collectTerms` and does not contain it. There he found no clean way to put variables into types: "The *big* issue I'm facing is appropriate types for symbolic expressions. In particular, how do I handle variables in types?", settling for "My bad solution for now has been to just not have type-level variable representation, which kind of bothers me." He wants dependent types and concludes Haskell cannot practically supply them here. Take the hint and keep the core untyped.

---

## 8. Rewriting-Based Language Design

**Maude** (SRI International). Rewriting logic and membership equational logic.
> **The system to study for efficient, correct matching modulo associativity/commutativity/identity.** High-performance C++ engine with powerful reflection and metaprogramming.

**OBJ / OBJ3** (Joseph Goguen et al.). Order-sorted equational logic.
> Maude's ancestor; foundational for the idea of programming *as* equational specification plus rewriting. (Our formulation, not a quotation — no OBJ paper is held here.)

**ELAN, Stratego, Tom.** Strategy languages.
> Separate rewrite *rules* from the *strategies* controlling their application. Maps onto the distinction between your rule tables and your evaluation control (`ReplaceRepeated`, `//.`, evaluation order, holding), and the control layer is where the difficulty concentrates. (A line about "the strategies rather than the rewrite rules doing the heavy lifting" is often attributed to the Rascal paper; it is **not there** — don't cite it. What Rascal does show is its `visit` construct carrying explicit `top-down`/`bottom-up` strategy annotations.)

**Rascal** (CWI). Meta-programming / language workbench, descendant of ASF+SDF.
> How to package rewriting into a usable language.
> - **Klint, Paul, Tijs van der Storm, and Jurgen Vinju.** "RASCAL: A Domain Specific Language for Source Code Analysis and Manipulation." *SCAM '09* (9th IEEE International Working Conference on Source Code Analysis and Manipulation), pp. 168–177. DOI: 10.1109/SCAM.2009.28. Author copy free from `homepages.cwi.nl`. Later given SCAM's most-influential-paper award.

**Pure** (Albert Gräf).
> A modern, practical, dynamically typed functional language *based on term rewriting*, with ML-style syntax. Arguably the closest existing "small language built on term rewriting" to what you're building. Readable.

---

## 9. Blog Posts, Theses, and Course Materials

**Johansson, Fredrik.** "Things I would like to see in a computer algebra system." Blog post.
> A practitioner's list from the FLINT/Arb author. Central point for your Stage 0: "the core datatype in computer algebra is the arbitrary-size integer," while "hardware, compilers, programming languages are not at all designed for" it — a direct argument for getting the bignum substrate right first.

**Lioubartsev, Dmitrij.** "Constructing a Computer Algebra System Capable of Generating Pedagogical Step-by-Step Solutions." MSc thesis, KTH, 2016. DiVA `diva2:945222`.
> "Largely built upon SymPy"; a worked example of scoping a CAS project and of how automatic-simplification decisions get made.

**Brun, Victor.** "Building a Computer Algebra System in Go, Part 1: Multivariate Expressions and Differentiation" (2022).
> Worked build-log of a from-scratch CAS; useful for scoping intuition. **Part 1 is all that exists** — no later installments are discoverable, and the live URL is Cloudflare-gated (use the Wayback capture).

**von zur Gathen & Gerhard.** *Modern Computer Algebra* companion site: `cosec.bit.uni-bonn.de/science/mca/`.
> The authors' book page: "Addenda and corrigenda" (per-edition errata), reviews, downloads, and the MCA gallery. Also the citable source for the book's extent and edition ISBNs — see §1.

**Olah, Christopher.** "HaskSymb: An Experiment in Haskell Symbolic Algebra" (1 June 2012).
> See §7 — and note the design retrospective is in the repository README, not this post.

---

## Availability at a Glance

**Free PDFs / online, start here at zero cost:**
- *A=B* (released free by the authors)
- Wolfram evaluation & attributes documentation (`reference.wolfram.com`)
- Ishii, arXiv:1807.01456
- Krebber MatchPy papers, arXiv:1710.06915 / 1710.00077 / 1705.00907
- Zhu et al. on hash consing, arXiv:2509.20534
- Axiom literate `.pamphlet` volumes (`github.com/daly/axiom/books`)
- SymPy architecture paper (PeerJ CS, open access)
- Wolfram's historical essays, and the **1981 SMP manual** (Summary / Primer / Reference Manual, `content.wolfram.com`)
- Klop, "Term Rewriting Systems: From Church-Rosser to Knuth-Bendix and Beyond" — the ICALP'90 survey, free from CWI (`ir.cwi.nl/pub/2667`)
- Bachmair et al., "Experiments with AC Discrimination Nets" (`ijcai.org`)
- Fateman, "A Review of Mathematica"
- Schneider, "Symbolic Summation Assists Combinatorics" (RISC) — the readable way into difference-field summation
- Klint, van der Storm & Vinju, the Rascal paper (author copy, `homepages.cwi.nl`)
- Penner, "ASTs with Fix and Free" (`chrispenner.ca`) and Milewski, "F-Algebras" (`bartoszmilewski.com`)
- Wadler, "Data Types a la Carte" (blog, 28 Feb 2008, `wadler.blogspot.com`) — the source of the verdict quoted in §3
- Pickering, "Data Types à la Carte with Closed Type Families" (`mpickering.github.io`) and SymPy's *Advanced Expression Manipulation* page (`docs.sympy.org`)
- The READMEs and package pages quoted in §5 and §7: Expreduce, Symja, HaskSymb, `poly`, `dumb-cas`, `numhask`, `sbv` (the `Data.SBV` haddock page), `numeric-prelude` (both the Hackage README, which carries the four objections to `Num`, and the HaskellWiki page), and Symbolica's licence and home pages. All captured in `references/` — the `numeric-prelude` pair on 2026-08-29, `sbv` on 2026-08-31, and the rest on 2026-08-30 — so the quotes have anchors.
- Wikipedia's *Wolfram Language* article (§5, for the MockMMA cease-and-desist sentence and its missing citation)

**Paywalled journal/conference papers — held here, but not freely re-obtainable.** Re-obtaining any
of these needs institutional access. Where a free substitute exists it is named:

- Karr, "Summation in Finite Terms" (*JACM* 28(2), 1981) and "Theory of Summation in Finite Terms"
  (*JSC* 1(3), 1985) — ACM and Elsevier. *Substitute: Schneider's Sigma paper, free, above.*
- Benanav, Kapur & Narendran, "Complexity of Matching Problems" (*JSC* 3(1), 1987) — Elsevier.
  Reported as hybrid open access by Semantic Scholar, so it may be free-to-read in a browser.
- Eker, "AC Matching via Bipartite Graph Matching" (*Computer Journal* 38(5), 1995) — Oxford
  Academic; reported as closed.
- Bachmair, Chen & Ramakrishnan, "Associative-Commutative Discrimination Nets" (TAPSOFT '93) —
  Springer LNCS. *The 1995 IJCAI companion is free, above, and is the more practical of the two.*
- Klop, "Term Rewriting Systems" (*Handbook of Logic in CS* Vol. 2 / CWI `CS-R9053`) — the report
  number could not be located free. *Substitute: the ICALP'90 survey, free, above.*
- Cole & Wolfram, "SMP: A Symbolic Manipulation Program" (SYMSAC '81) — ACM — and Greif, "The SMP
  Pattern-Matcher" (EUROCAL '85) — Springer LNCS. Both were listed in this bibliography until
  2026-08-30 as free from Wolfram's content servers; they are not, and appear nowhere on
  `stephenwolfram.com/publications`. *Substitute: the 1981 SMP manual, free, above — 399 pp. against
  their 15, and the Primer's §3 covers the pattern matcher directly.*

**In print / purchase:**
- Cohen Vols. 1–2 (Routledge/CRC reprints)
- von zur Gathen & Gerhard (Cambridge)
- Baader & Nipkow (Cambridge)
- Bronstein (Springer)
- Terese (Cambridge)
- Jenks & Sutor (Springer; but see free Axiom volumes)

**Out of print, findable secondhand:**
- Geddes/Czapor/Labahn
- Zippel
- Davenport/Siret/Tournier

**Two-book minimum if budget-constrained:** Cohen **Vol. 2** + Baader & Nipkow — Vol. 2 is the one carrying the automatic-simplification algorithm and the rational arithmetic. Add Vol. 1 next for the expression-tree material.

---

## Verification Notes

Every entry above has been checked against a document held in the local corpus in `references/` or,
where the entry names a *system* rather than a document — the source repositories and Hackage packages
of §5, §7 and §8, which the corpus summary covers under "pointers only, by design" — against the live
primary source. The eight pages that were previously checked live and not captured — the Expreduce, Symja and HaskSymb
READMEs, the `poly` and `dumb-cas` package pages, Wadler's blog post, Symbolica's licence, and the
`OwnValues` reference page — were fetched on 2026-08-30 and indexed. A sweep then tested every quoted
phrase of five words or more in both documents against a plain-text index of the whole corpus; it added
Pickering's blog post and SymPy's *Advanced Expression Manipulation* page, and unquoted two phrases that
turned out to be our own wording rather than a source's (a compression of the `dumb-cas` description,
and the OBJ slogan).

**A third pass, later on 2026-08-30, re-ran all of that from scratch rather than trusting the first
two**, and also opened the primary source behind every structural claim — chapter maps, edition
histories, tables of contents, abstracts — and ran the Haskell claims through GHC 9.12.4. It corrected
nine entries (see the repo history) and closed four more source gaps: Symbolica's home page, Wikipedia's
*Wolfram Language* article, `numhask`'s package page, and the **published** SymPy article, which had
been standing in as the PeerJ paper while the file held was actually the PeerJ Preprints review
manuscript. It also found a third phrase in quotation marks that was our own and not a source's —
Symbolica "built for large expressions", which is in no version of Symbolica's own page. A follow-up
sweep of the *availability* claims — every "free from X" this bibliography makes, tested live — found
one more: the two SMP conference papers were described as archived on Wolfram's content servers.
They are not; the SMP **manual** is, and is now held (three volumes, 399 pp.), while the papers moved
to the paywalled list where their Sci-Hub provenance always said they belonged.

**Four ISBNs remain genuinely open**, each tagged `[unverified]` wherever it appears — in this file and
in `cas-haskell.md` alike — and in every case because the copy held is a different printing from the one
the ISBN names: Zippel's original Kluwer hardback ISBN (held: the Springer softcover reprint,
978-1-4613-6398-9); Baader & Nipkow's paperback ISBN 0-521-77920-0 (held: the hardback, 0-521-45520-0,
which does check out); Cohen *Methods*' Routledge/CRC reprint ISBN 9780367659479 (held: the 2003 A K
Peters printing); and Jenks & Sutor's original Springer ISBNs 3-540-97855-0 / 0-387-97855-0 (held: the
Springer Science+Business Media printing, 978-1-4612-7729-3, which the file does confirm). Jenks & Sutor
was the odd one out until 2026-08-30 — described on its entry but not tagged, and counted in neither
file's total; all four now follow one rule. The `numeric-prelude` multi-parameter-type-class question,
once listed here, was answered by a page already in the corpus — `numeric_prelude_haskellwiki.html` names
them in its opening sentence.

**A fourth round, 2026-08-31**, re-ran the whole sweep from a text index rebuilt from scratch, on the
principle that a check inherited from the previous round is not a check. It re-tested every quoted
phrase in both documents, reopened every structural claim, re-ran the Haskell claims through GHC
9.12.4, and re-derived every PDF page count and every corpus total mechanically against this index.
Almost everything held. Four claims did not, and are corrected above:

- **Eker's affiliation.** The entry had the paper written at INRIA Lorraine. Its acknowledgements say
  the research was done there and the paper "was written at Rutherford Appleton Laboratory"; the
  byline is INRIA Lorraine and the contact address is already `eker@csl.sri.com`.
- **Eker's issue month.** Given as May 1995, against a paper stamped "revised July 7 1995". Dropped.
- **Fateman.** Cited as *JSC* 13(5), 1992 with no caveat, though the held author copy carries no
  journal metadata at all. The defect was recorded in the corpus index but had never reached the
  entry — `../references/CLAUDE.md` rule 5.
- **Wolfram's step 3**, quoted with "of the expression" silently dropped from the middle.

It also closed two gaps of the kind rule 2 names last — a claim *about* a page nobody held. Springer's
book page for Geddes is now held, and turns out to source both the "first comprehensive textbook"
line and the "Pascal-like computer language" description used throughout; Symbolica's home page as of
2025-04-15 is held, so the claim about what 2025 snapshots say is checkable. And four bookkeeping
statements that had gone stale were corrected: the `[unverified]` count and convention (above); the
sentence that opens these Verification Notes, which claimed every entry was checked against a *held*
document and so contradicted this file's own opening paragraph; `missing-documents.md`'s tally of
deliberately-unresolved quotations; and the free-PDF list, which named every quoted package page
except `numeric-prelude`'s.

One quotation was removed rather than sourced: this file reproduced the SymPy *preprint's* wording to
contrast it with the published article, after the third round had deliberately deleted the preprint
from the corpus. The contrast survives on metadata that does not require it.

**A fifth round, 2026-08-31**, rebuilt the text index from scratch again — splicing the two OCR
sidecars back in after the `pdftotext` sweep, as the fourth round's warning says to — and re-tested
every quoted phrase in both documents, every chapter map and edition history, every PDF page count
against the index, and the Haskell claims against GHC 9.12.4. All 40 page counts matched their rows,
and every quotation resolved. This round's focus was the half the previous four had touched least:
the **recommendations**. One is wrong, and it is corrected above.

- **`sbv` does not demonstrate overloading `Num`/`Ord`.** Both files described it as showing "how to
  overload `Num`/`Ord` for symbolic values (`.==`, `.>`)". `SBV a` does take the standard `Num`, but
  `Eq` and `Ord` are exactly the classes it *cannot* reuse — "we can't use Haskell's `Eq` class since
  Haskell insists on returning `Bool`", "there is no way to return an `Ordering` value from a symbolic
  comparison" — which is why `EqSymbolic`/`OrdSymbolic` exist and where `.==` and `.>` come from. The
  entry had it backwards on the half that carries the lesson: a CAS `Expr` hits the same wall, and
  reusing `Num` while forking `Eq`/`Ord` is the shape of the answer. The `Data.SBV` haddock page is now
  held — it was a claim about a page nobody had opened, the same failure mode as the fourth round's
  Geddes and Symbolica gaps, and it went unexamined because the entry read as a plausible summary.
- Two smaller repairs, neither changing a conclusion: Maxima's "general simplifier" was in quotation
  marks in `cas-haskell.md` and unquoted here, with no corpus anchor for a verbatim quote — the only
  occurrence anywhere in the corpus is Greif's reference list, citing Fateman's 1979 *MACSYMA's General
  Simplifier: Philosophy and Operation*. It is now unquoted in both, like the OBJ slogan before it. And
  a stray double period in `cas-haskell.md`'s `Expr` paragraph.

**A sixth round, 2026-08-31**, rebuilt the index again and re-ran the quotation sweep (107 quotes in
`cas-haskell.md`, all resolving), then audited three categories the previous five had not swept
mechanically: **bibliographic identifiers** (every ISBN, DOI, arXiv id and volume/page range),
**held-copy identity across all 40 PDFs**, and **author lists**. All eleven ISBNs check out against
the printings held. Every source named in `cas-haskell.md` has an entry here. Three things did not
hold:

- **The Ishii copy held is the arXiv pre-print, and the citation's published-venue details are not in
  it.** The file says so itself — "This is a pre-print of an article published in 'Computer Algebra in
  Scientific Computing' (2018)" — and carries only the *book* DOI `10.1007/978-3-319-99639-4`. LNCS
  11077, pp. 288–303 and the chapter DOI `…_20` appear nowhere in it. They are correct — Crossref
  confirms the title, the LNCS series, pages 288–303, 2018 and the CASC editors — but they were being
  presented as if the held file established them. This is the third instance of one pattern: SymPy
  (round 3, preprint substituted for the article), Fateman (round 4, author copy with no journal
  metadata), Ishii (here). An identity check on every held PDF is now part of the sweep, not an
  incident response.
- **Letter-spacing is a third silent-grep failure mode, and the first that fails while *succeeding*.**
  Karr 1981 — recorded in these notes as "the clean one" through five rounds — extracts scattered prose
  as "p a p e r", "c o n c e r n e d w i t h": `grep theorem` returns 76 of 100. Benanav returns zero for
  `important` and `programming`. The IJCAI '95 discrimination-net paper letter-spaces its byline, so
  `grep Anantharaman` and `grep Chabin` return zero on a paper both co-wrote. Every previously recorded
  defect announces itself by returning nothing; this one returns most of the hits and hides the rest,
  which is why five rounds of checks all passed against it. Recorded on each entry and in
  `../references/missing-documents.md`, with a despacing probe that is tested rather than plausible.
- **The "roughly 60×" AST speedup is a chart reading.** Krebber's thesis prose says only that the AST
  speedup is "even greater" than LinAlg's five-to-twenty; 60 comes from Figure 5.4a's axis. It is a fair
  reading, but the MatchPy *paper* separately reports a "speedup of up to 60" for a different
  measurement — the syntactic discrimination net on LinAlg — so the two are now kept apart explicitly,
  before a later round "corrects" one into the other.

**A seventh round, 2026-09-01**, re-ran the quotation sweep against a rebuilt index — this time
searching a *despaced* copy of every document alongside the plain one, so round six's letter-spacing
defect could not hide a hit — and then swept four categories still untouched: the **algorithm
attributions** in the staged plan, every **publication year**, every **publisher**, and every
**edition statement**.

Almost everything held, and several claims are now grounded rather than assumed. vzGG credits the
sparse-interpolation idea to Zippel (1979) and the modular GCD approach to Brown (1971) and Collins
(1971), so both Stage 2 attributions are sound. Bronstein's chapter 2 is titled *Integration of
Rational Functions* and contains §2.2 Hermite Reduction, §2.4 Rothstein–Trager and §2.5
Lazard–Rioboo–Trager, with chapter 5 covering the transcendental case — exactly the split Stage 3
prescribes. A=B contains Gosper, creative telescoping, WZ and `Hyper`; Baader & Nipkow chapter 7
contains Huet; Karr's copy confirms *JACM* 28(2), April 1981, pp. 305–350. Every publication year,
publisher and edition statement checks out against the held printing, with two expected exceptions
(Terese is image-only; the IJCAI '95 paper prints no year) — and one real one.

- **The A=B copy held is not the edition cited.** It is the authors' free electronic edition of 27
  April 1997, with no publisher, no ISBN, no copyright page and no "1996" in it. The A K Peters 1996
  printing is a different artifact. Recorded on the entry above. This is the fourth instance of the
  pattern — SymPy, Fateman, Ishii, now A=B — and the first that round six's marker sweep structurally
  could not find, because the file makes no claim about its own status. Checking a citation's *fields*
  against the file is what caught it; scanning for markers is not enough.

One residual, unchanged from round six: **"Terese is in print" could not be confirmed.** Cambridge's
site returns 500 to `curl` and Open Library carries no availability data. The claim is plausible and
low-stakes, but it has now failed verification twice and is recorded here rather than left as though
it had been checked.

**An eighth round, 2026-09-01**, started from the narrow question *is any document missing?* The
bookkeeping was clean — 85 index rows against 85 files, and the three standing gaps re-tested live
rather than trusted — but the sweep for claims resting on unheld pages found two more, and one of
them was wrong in both halves.

- **Kmett's `algebra` has no `Magma` class, and prescribes `RebindableSyntax` nowhere.** §7 described
  its hierarchy as "magmas → semigroups → groups → rings → modules → algebras" and said its page
  prescribes `RebindableSyntax`. Its full documentation index returns **zero** for `Magma`;
  `RebindableSyntax` appears neither on the Hackage page, nor in `Numeric.Algebra`, nor in the README.
  The magma-rooted hierarchy is `numhask`'s — the package named in the next sentence — and the
  `RebindableSyntax` point belongs to the numhask/numeric-prelude comparison, where this file already
  had it right. The entry now describes the hierarchy the package actually has, including the
  `Numeric.Domain.*` chain `Domain` → `IntegralDomain` → `GCDDomain` → `UFD` → `PID` → `Euclidean`,
  read off the class declarations rather than assumed.
- **`constructive-algebra`'s page is now held**, and its claim checks out verbatim.

Both pages are captured, taking the corpus to **87 documents / 41 HTML captures**. This is the third
time an unanchored assertion about a package's API has turned out wrong — after `sbv` in round five
and the `numhask` comparison in round three — and all three were invisible to quotation sweeps because
they quoted nothing.

Everything previously flagged here as unverified — Terese, Klop, the `numeric-prelude` pages, the Bachmair AC-discrimination-net papers, Bahr & Hvitved, and the DiVA thesis — has since been confirmed, and several of those checks changed the entry.

**Readability, not availability, is now the live risk.** Four held documents cannot simply be grepped, and one of them fails silently:

| File | Problem | Mitigation |
| :--- | :--- | :--- |
| Terese (2003) | Image-only, 908 pp | **None.** Open in a viewer. |
| Abramsky, *Handbook* Vol. 2 | Image-only, 582 pp | Use the standalone Klop chapter for pp. 1–116; the rest needs a viewer. |
| Bachmair et al. (TAPSOFT '93) | Image-only | `.txt` OCR sidecar beside it |
| Eker (1995) | Image-only *except* a repeated download watermark | `.txt` OCR sidecar beside it |
| Karr (1985) | Has a text layer, but the OCR **drops every `h`** | None — search around it |
| Klop (1992) | Has a text layer, but it **drops `fi`/`ffi` ligatures** — "uni cation", "speci cations" | None — search `uni cation`, or either side of the ligature |
| Geddes et al. (1992) | Body text is sound; the **table-of-contents pages are OCR noise** ("In od ion", "Algo i hm") | Grep the body for chapter titles, not the TOC |

Three traps worth carrying into any future audit. **Eker passes a naive text-layer check** — it reports text on every page, but the only text is an Oxford watermark, 860 characters across 19 pages; check the *variety* of extracted text, not its presence. **Karr 1985 and Klop 1992 fail silently** — `grep theorem` on the first and `grep unification` on the second both return nothing and look like honest misses. And a **failed** grep is never by itself evidence of absence: treat it as a question about the file before treating it as an answer about the text. The four Wolfram `ref/` value pages (`OwnValues`, `DownValues`, `UpValues`, `SubValues`) likewise preserved little beyond their one-line definitions — roughly 13 KB of text each, almost all navigation chrome — and `ref/Attributes` in particular does not contain the attribute list. Use *Transformation Rules and Definitions* for the rule-storage model and *Evaluation of Expressions* for the attribute table.

See [`../references/missing-documents.md`](../references/missing-documents.md) for the three sources still not held, the routes tried, and the command that regenerates the OCR sidecars.

Two figures in this bibliography are **vendor- or maintainer-reported benchmarks**, not independently verified: Symbolica's Rubi corpus timings and rule count, and the `poly` package's speedup claim. The Rubi rule count discrepancy ("over 6600", and "Rubi 4.15 has 6,662 rules", per Rubi's own site vs. 7,000+ for Rubi 4.17 per Symbolica) is noted where it appears.

The claim that the Wolfram kernel uses hash-consing internally is **inferred, not confirmed** — the kernel is closed source, and reverse-engineering writeups (including the wltools specification project) should be treated as informed inference.
