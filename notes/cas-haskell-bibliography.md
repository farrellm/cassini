# Bibliography: Building a Computer Algebra System in Haskell

Full reference list for the reading & building guide. Entries are grouped by role in the project. Annotations note what each source is *for*, difficulty where relevant, and availability. Every entry has been checked against the local corpus in `references/` or, where no local copy exists, against the live primary source. Items still marked **[unverified]** could not be confirmed either way and should be checked before you rely on them.

---

## 1. Textbooks — Computer Algebra Algorithms

**Cohen, Joel S.** *Computer Algebra and Symbolic Computation: Elementary Algorithms.* A K Peters, 2002. ISBN 1-56881-158-6. Reprinted by Routledge/CRC, ISBN 9781568811581.
> Expressions as trees; structure-based operators; the *structure* of an automatically simplified expression (ch. 2 introduces automatic simplification under Expression Evaluation; ch. 3 covers Recursive Structure, incl. §3.2 Expression Structure and Trees and §3.3 Structure-Based Operators). Algorithms in "Mathematical Pseudo-Language" (MPL) with Maple, Mathematica, and MuPAD companions. Prerequisites per Cohen's preface: freshman–sophomore calculus through multivariable, elementary linear algebra, applied ODEs, a recommended discrete-mathematics course, and some programming experience — abstract-algebra topics are "introduced as needed," not assumed. **Note: the automatic-simplification *algorithm* is in Vol. 2, not here.** *Essential — Stage 0/1.*

**Cohen, Joel S.** *Computer Algebra and Symbolic Computation: Mathematical Methods.* A K Peters, 2003. ISBN 1-56881-159-4; Routledge/CRC reprint ISBN 9780367659479.
> **The volume with the automatic-simplification algorithm** — ch. 3, §3.1 *The Goal of Automatic Simplification* and §3.2 *An Automatic Simplification Algorithm* — plus ch. 2 on integer and rational arithmetic. Then polynomial decomposition, multivariate polynomials, resultants, side relations, and factorization (chs. 4–9) from the same implementer's angle. *Essential — Stage 0/1 for chs. 2–3, Stage 2/3 for the rest.*

**von zur Gathen, Joachim, and Jürgen Gerhard.** *Modern Computer Algebra.* 3rd ed. Cambridge University Press, 2013. 808 pp. ISBN 9781107039032.
> The deep reference: modular arithmetic, Chinese remainder, fast Euclidean algorithm, Hensel lifting, finite-field factorization, evaluation/interpolation. Complete proofs and complexity analysis; includes implementation reports. Edition history, commonly miscited: the **3rd** (2013) edition renovated ch. 11, the Fast Euclidean Algorithm (a correctness bug), and fixed ~80 further errors — nothing more. The new material in chs. 3, 15 and 22 (GCD, symbolic integration) came with the **2nd**, 2003 edition (copyright page: "Cambridge University Press 1999, 2003"; the companion site lists "Second edition 2003: ISBN 978-0521826464" and "First edition 1999: ISBN 0521641764"). February 2002 is that edition's preface date, which is where the "2002 edition" miscitation comes from. Companion site: `cosec.bit.uni-bonn.de` — addenda and corrigenda, and the source confirming the extent (808 pages, 40 tables, 560 exercises). Graduate difficulty; use as a lookup reference, not a linear read. *Essential as reference.*

**Geddes, Keith O., Stephen R. Czapor, and George Labahn.** *Algorithms for Computer Algebra.* Kluwer Academic Publishers, 1992. ISBN 0-7923-9259-0.
> The most complete single volume covering the whole implementer's pipeline: normal forms, polynomial/rational/power-series arithmetic, homomorphisms and CRT, Newton iteration and Hensel construction, polynomial GCD, factorization, solving systems of equations, Gröbner bases, integration of rational functions, and the Risch algorithm. Pascal-like pseudocode. *Essential — the one algorithms reference to own if you buy only one.*

**Bronstein, Manuel.** *Symbolic Integration I: Transcendental Functions.* 2nd ed. Algorithms and Computation in Mathematics vol. 1. Springer, 2005.
> The standard integration reference: Hermite reduction, Rothstein–Trager, Lazard–Rioboo–Trager, and the Risch algorithm proper. 2nd ed. adds a chapter on parallel/Risch–Norman integration. Ready-to-implement pseudocode. **Volume II (algebraic functions) was never completed — Bronstein died before finishing it**, so the algebraic case remains scattered across research papers. *Essential at Stage 3.*

**Petkovšek, Marko, Herbert S. Wilf, and Doron Zeilberger.** *A=B.* A K Peters, 1996. Foreword by Donald E. Knuth.
> Algorithmic hypergeometric summation: Gosper's algorithm, Zeilberger's creative telescoping, the WZ method, Petkovšek's `Hyper`. **Freely and legally available as a PDF from Herbert Wilf's University of Pennsylvania page** — the authors released it. Does *not* cover Karr's algorithm. *Essential for summation; free.*

**Zippel, Richard.** *Effective Polynomial Computation.* Kluwer Academic Publishers, 1993. Kluwer International Series in Engineering and Computer Science 241. 363 pp. Springer softcover reprint ISBN 978-1-4613-6398-9; the original Kluwer hardback ISBN is often given as 0-7923-9375-9 **[unverified]**.
> Practical vs. theoretical tradeoffs in polynomial algorithms, by the originator of sparse modular ("Zippel") interpolation for multivariate GCD. Strong on where asymptotically optimal algorithms are the wrong practical choice. Out of print but findable. *Optional; valuable at Stage 2.*

**Davenport, James H., Yvon Siret, and Évelyne Tournier.** *Computer Algebra: Systems and Algorithms for Algebraic Computation.* 2nd ed. Academic Press, 1993. Preface by Daniel Lazard.
> Gentler, systems-oriented survey. Good conceptual overview; less of an implementation cookbook. *Optional.*

**Jenks, Richard D., and Robert S. Sutor.** *AXIOM: The Scientific Computation System.* Springer, 1992. ISBN 3-540-97855-0 (Berlin) / 0-387-97855-0 (New York).
> The design document for the strongly-typed CAS — categories and domains (Ring, Field, …) as first-class types. Now Volume 0 of the open Axiom literate-program series. *Essential reading for a Haskell implementer* because Axiom's typed algebra hierarchy is the closest existing analogue to a type-driven Haskell CAS. See §5 for the free literate volumes.

---

## 2. Textbooks — Term Rewriting

**Baader, Franz, and Tobias Nipkow.** *Term Rewriting and All That.* Cambridge University Press, 1998. Paperback ISBN 0-521-77920-0 / 9780521779203; hardback 0-521-45520-0.
> The book for the evaluator layer. Chapter map: 1 Motivating Examples, 2 Abstract Reduction Systems, 3 Universal Algebra, 4 Equational Problems (congruence closure, syntactic unification), 5 Termination, 6 Confluence (critical pairs, orthogonality), 7 Completion (Knuth–Bendix, Huet), 8 Gröbner Bases and Buchberger's Algorithm, 9 Combination Problems, 10 Equational Unification (commutative; associative-commutative), 11 Extensions (rewriting modulo equational theories, conditional rewriting, reduction strategies). **Read chs. 1–2 and 5–7 first — chs. 1–4 alone contain no termination, confluence or completion** — then 10–11 when the AC matcher lands. Main algorithms given informally *and* as Standard ML (with an ML primer in Appendix 2); the *efficient* unification and congruence-closure programs are in Pascal. Over 170 exercises. *Essential — read in parallel with Cohen.*

**Terese** (Marc Bezem, Jan Willem Klop, Roel de Vrijer, eds.). *Term Rewriting Systems.* Cambridge Tracts in Theoretical Computer Science 55. Cambridge University Press, 2003.
> The comprehensive advanced reference, 908 pp. *Optional — only if you need confluence/termination theory beyond Baader & Nipkow.* (The copy in `references/` is an image-only scan with no text layer; it cannot be grepped.)

**Klop, Jan Willem.** "Term Rewriting Systems." In *Handbook of Logic in Computer Science*, Vol. 2, ed. Abramsky, Gabbay & Maibaum (Oxford University Press, 1992), pp. 1–116. Circulated by CWI as report `CS-R9053`.
> The classic full survey of rewriting theory: abstract reduction systems (with Knuth–Bendix completion and (E-)unification), orthogonal TRSs and reduction strategies, strong sequentiality, and conditional TRSs. ~112 pp. **Get it as the standalone PDF, not from the Handbook** — the Handbook scan is images only and cannot be searched, whereas the standalone has a full text layer. Two labelling notes: the text carries no report number of its own, and it cites work through 1991, so it is the Handbook-chapter text rather than strictly the 1990-numbered preprint. *Optional; free.*

**Klop, Jan Willem.** "Term Rewriting Systems: From Church-Rosser to Knuth-Bendix and Beyond." *ICALP '90*, Springer LNCS 443. Free from CWI's repository (`ir.cwi.nl/pub/2667`).
> The 20-page version: abstract rewriting, Combinatory Logic, orthogonal systems, strategies, critical pair completion, extended rewriting formats. The cheap way into the same material. *Optional; free.*

---

## 3. Foundational Papers

**Richardson, Daniel.** "Some **Undecidable** Problems Involving Elementary Functions of a Real Variable." *Journal of Symbolic Logic* 33, no. 4 (Dec. 1968): 514–520. DOI: 10.2307/2271358.
> Richardson's theorem: for expressions built from the rationals, π, ln 2, a variable *x*, addition/subtraction/multiplication/composition, and `sin`, `exp`, `abs`, the predicate "E = 0?" is unsolvable. Precisely: condition (1) is that the function class contain log 2, π, eˣ and sin x; condition (2) that it contain some μ with μ(x) = |x| for x ≠ 0 (√x² will do). Conditions (1)+(2) give the identity problem; (1)+(2)+(3) give the integration problem. **The reason no CAS simplifier can be complete.** Read the statement even if you skip the proof. *The title is very commonly miscited as "Unsolvable" — it is "Undecidable".*

**Swierstra, Wouter.** "Data types à la carte." *Journal of Functional Programming* 18, no. 4 (2008): 423–436. DOI: 10.1017/S0956796808006758.
> ASTs as coproducts of functors (`data (f :+: g) e = Inl (f e) | Inr (g e)`) with `Fix` and a subtyping class `(:<:)`. The reference solution to the expression problem in Haskell. Wadler's verdict — on his blog, 28 Feb 2008, *not* in the paper, which cites him only as the problem's namer — was that it "presents the best solution to the Expression Problem that I've seen in Haskell (well, Haskell with `-fglasgow-exts`)." *Read for context; likely unnecessary if your core `Expr` is untyped and uniform.*

**Bahr, Patrick, and Tom Hvitved.** "Compositional Data Types." *Workshop on Generic Programming*, 2011. DOI: 10.1145/2036918.2036930. See also Matthew Pickering's closed-type-family reimplementation.
> Productionized descendants of "Data types à la carte." *Optional.*

**Cole, Christopher A., and Stephen Wolfram.** "SMP: A Symbolic Manipulation Program." *Proceedings of the 1981 ACM Symposium on Symbolic and Algebraic Computation (SYMSAC '81)*.
> The earliest primary source on the symbolic-expression + transformation-rule architecture that became Mathematica. Archived as PDF on Wolfram's content servers.

**Greif, Jerry.** "The SMP Pattern-Matcher." *EUROCAL '85*, Springer LNCS 204.
> The earliest published description of how this family of pattern matchers was designed. Archived on Wolfram's content servers.

**Bachmair, Leo, Ta Chen, and I. V. Ramakrishnan.** "Associative-Commutative Discrimination Nets." *TAPSOFT '93: Theory and Practice of Software Development* (CAAP/FASE, Orsay), ed. Gaudel & Jouannaud, 1993, pp. 61–74.
> Introduces the data structure: generalizing discrimination nets to AC symbols, and term indexing for Knuth–Bendix completion.

**Bachmair, Leo, Ta Chen, I. V. Ramakrishnan, Siva Anantharaman, and Jacques Chabin.** "Experiments with Associative-Commutative Discrimination Nets." *IJCAI '95*, pp. 348–354. Free from `ijcai.org`.
> The measurement paper for the above. Read both before optimizing your matcher — not before writing it.

---

## 4. Pattern Matching — The Hard Engineering

**Krebber, Manuel.** "Non-linear Associative-Commutative Many-to-One Pattern Matching with Sequence Variables." Master's thesis, RWTH Aachen. arXiv:1705.00907.
> The most complete single document on the combined feature set you need: AC matching + sequence variables + non-linear patterns + many-to-one via discrimination nets. *Essential for Stage 1 matcher design.* Free.

**Krebber, Manuel, Henrik Barthels, and Paolo Bientinesi.** "MatchPy: A Pattern Matching Library." arXiv:1710.06915. See also arXiv:1710.00077.
> The readable modern treatment of Mathematica-style matching: syntactic plus associative and/or commutative functions, sequence variables (the `BlankSequence`/`BlankNullSequence` analogue), constraints, many-to-one discrimination nets. Open-source Python implementation. Key facts: general AC matching is **NP-hard** and worst-case exponential — the underlying result is Benanav, Kapur & Narendran (below), which Krebber cites for AC matching being NP-complete. Discrimination nets conventionally treat patterns as linear and check repeated-variable equivalence "in an extra step," but note that **MatchPy itself departs from this**, performing "the full non-linear matching directly at a commutative symbol state instead of just using it as a filter." The polynomial-time result for linear AC matching comes from reduction to bipartite matching (Eker, below), not from these papers. Free.

**Benanav, Dan, Deepak Kapur, and Paliath Narendran.** "Complexity of Matching Problems." *Journal of Symbolic Computation* 3, no. 1 (Feb. 1987): 203–216.
> The NP-completeness result for associative and for AC matching. The citation to give when you assert the hardness bound.

**Eker, Steven M.** "Associative-Commutative Matching via Bipartite Graph Matching." *The Computer Journal* 38, no. 5 (May 1995): 381–399.
> Reduces AC matching to maximum bipartite matching — the source of the polynomial bound for linear patterns, and the technique Maude is built on. Krebber's many-to-one matcher uses the same construction at commutative states.

---

## 5. Open-Source Systems to Study

Ordered roughly by relevance to a Wolfram-style Haskell build.

**Expreduce** (Cory Walker). Go. `github.com/corywalker/expreduce`
> **The single most relevant codebase.** From-scratch Wolfram Language term-rewriter/CAS with Blank/BlankSequence, Orderless/Flat matching, conditional rules, attributes, and the fixed-point evaluator. The README describes it as "experimental quality and… not currently intended for serious use" — which makes it small and readable. *Lesson: how to structure evaluator + matcher in a statically typed host language.*

**Mathics / Mathics3.** Python, GPL v3. `github.com/Mathics3/mathics-core`
> A fuller open Wolfram Language kernel: parser building Expressions, evaluator, WL built-ins, delegating heavy math to SymPy and mpmath. *Lesson: realistic module layout for a batteries-included WL kernel.*

**Symja.** Java; GPL v3 since 2.0.0 (parser/core modules LGPL). Formerly MathEclipse. `github.com/axkr/symja_android_library`
> A long-lived WL reimplementation; mature parser, large function library. Its README confirms it implements `Integrate` from the Rubi ruleset but names no version; per Symbolica's writeup it is "the only other complete port," based on **Rubi 4.16**. *Lesson: grep for specific algorithm implementations.*

**MockMMA** (Richard Fateman, 1991). Lisp.
> The earliest WL reimplementation. The widely repeated cease-and-desist story appears in Wikipedia's Wolfram Language article **with no citation** — treat it as folklore until sourced. *Historical.*
> - **Fateman, Richard J.** "A Review of Mathematica." *Journal of Symbolic Computation* 13, no. 5 (1992). A separate document, and the one actually worth reading: not implementation notes but a sharp design critique of the language, evaluator and pattern matcher, from someone who had built a competing system.

**SymPy.** Python, BSD. `sympy.org`
> The most approachable *full* CAS to read. Pure Python with no invented language — the reference paper notes that Python itself is used for both internal implementation and end-user interaction. *Lesson: how to organize a large CAS — assumptions system, `Basic`/`Expr` core, `polys` module — and how automatic-simplification decisions get made.*
> - **Meurer, Aaron, et al.** "SymPy: symbolic computing in Python." *PeerJ Computer Science* 3 (2017): e103. DOI: 10.7717/peerj-cs.103. (24 authors.) Free.

**GiNaC** ("GiNaC is Not a CAS"). C++. `ginac.de`
> *Lessons:* (1) deliberately abolishes the low-level/high-level language split — relevant to a Haskell-native ambition; (2) reference counting with copy-on-write for structure sharing; (3) numeric tower built on CLN (the paper does not mention GMP); (4) clean polymorphic `ex`/`basic` design with automatic normalization.
> - **Bauer, Christian, Alexander Frink, and Richard Kreckel.** "Introduction to the GiNaC Framework for Symbolic Computation within the C++ Programming Language." *Journal of Symbolic Computation* 33, no. 1 (2002): 1–12.

**SymEngine.** C++ core with bindings in many languages, including a thin Haskell FFI package (`symengine` on Hackage).
> The fast C++ rewrite of SymPy's core. *Lesson: the "fast typed core + scripting frontend" architecture.* Also a candidate to FFI into if you'd rather not write your own numeric/polynomial backend.

**Maxima.** Common Lisp. The open descendant of MIT Macsyma.
> *Lesson: the untyped-expression paradigm in its native habitat* — why homoiconic s-expressions map so naturally onto expression trees, and how a 50-year-old general simplifier and rule system (`tellsimp`, `defrule`) is structured. Large and old; grep, don't read cover to cover. Macsyma is the ancestor of this whole lineage — Wolfram was a Macsyma user, and also studied Schoonschip's code.

**Reduce.** Lisp. Open source.
> The other long-lived Lisp CAS. Same lesson as Maxima, different design choices.

**Axiom / FriCAS.** Lisp core + SPAD algebra language. Sources: `github.com/daly/axiom/books` (`axiom-developer.org` no longer resolves), `fricas.github.io`
> Distributed as a **literate program in ~15 numbered volumes**, freely available as `.pamphlet` LaTeX+SPAD sources — no prebuilt volume PDFs survive: Vol. 0 (Jenks & Sutor), Vol. 10.x covering algebra implementation, theory, categories, domains, and packages. FriCAS maintains a modern regeneration of Vol. 0 as *The FriCAS System for Computer Mathematics*. The volumes explain the *why* of a rigorous typed algebra hierarchy. *Essential background for the typed-vs-untyped decision.*

**Symbolica.** Rust, with Python/C++ bindings. `symbolica.io`
> Modern, source-available, high-performance CAS "built for large expressions." Pattern matcher supports commutative/associative matching and wildcards (`x_`). Per Symbolica's own writeup it provides "the only complete port of the latest Rubi 4.17 integration system outside the Wolfram Language, preserving its 7,000+ ordered rules and passing the complete 72,944-problem Rubi corpus" (MIT-licensed `symbolica-integrate` crate), processing that corpus "in 18 minutes of wall time, on a Ryzen 9 5900X parallelized over 8 cores" (57 ms median per problem). **These are vendor-reported figures.** *Lesson: rule-based integration as a pragmatic complement to Risch, and how to make AC matching fast.*
> **License caveat:** source-available but commercially licensed, and the trigger is employment rather than commerce — "Symbolica is free for hobbyist use. If you use Symbolica as part of your employment, whether in academia or in a commercial or non-commercial organization, a license is required." The free tier is "one core and instance per device"; redistribution needs written permission. Fine to read; check the license before depending on it.

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
> **The authoritative behavioral spec, and the single most important page for Stage 1.** Its section "The Standard Evaluation Sequence" gives the whole algorithm in order, for `h[e1, e2, …]`: (1) raw objects (`Integer`, `String`, …) are left unchanged; (2) evaluate the head `h`; (3) evaluate each element `eᵢ` in turn; (4) `HoldFirst`/`HoldRest`/`HoldAll`/`HoldAllComplete` skip evaluation of certain elements; (5) unless `SequenceHold` or `HoldAllComplete`, flatten `Sequence` objects; (6) unless `HoldAllComplete`, strip outermost `Unevaluated` wrappers; (7) `Flat` flattens nested same-head expressions; (8) `Listable` threads over lists; (9) `Orderless` sorts; (10) user-defined rules for `h[f[e1,…],…]`; (11) built-in rules associated with `f`; (12) user-defined rules for `h[e1,e2,…]` or `h[…][…]`; (13) built-in rules for the same. Then the fixed point: "every time the expression changes, the Wolfram Language effectively starts the evaluation sequence over again." Note that steps 7–9 fix the attribute order as **Flat → Listable → Orderless**, that step 5 precedes step 6, and that steps 10–13 are a four-way ladder — so built-in upvalues beat *user* downvalues.

**Wolfram Research.** "Evaluation of Expressions." Tech note, `reference.wolfram.com`. Free.
> The longer companion: a coarser six-step summary of the same procedure, the full attribute table, worked evaluation traces, and the prose precedence rule — "the Wolfram System always tries upvalue definitions before downvalue ones," with the complete `f[g[x]]` order spelled out. Use this one for the explanations and examples, and "Evaluation" above for the algorithm.

**Wolfram Research.** Documentation on **Attributes**: `HoldAll`, `HoldFirst`, `HoldRest`, `HoldAllComplete`, `Flat`, `Orderless`, `Listable`, `OneIdentity`, `SequenceHold`, `Protected`, `Constant`. Free.
> `OneIdentity` in particular affects pattern matching (treating `f[a]` as `a`) and is easy to get wrong.

**Wolfram Research.** Documentation on **OwnValues, DownValues, UpValues, SubValues**. Free.
> The rule storage model: OwnValues are the symbol's own value (`x = 5`); DownValues attach rules to a symbol as head (`f[...] := ...`); UpValues attach to a symbol appearing as an *argument*; SubValues are "values for `f[…][…]…`", i.e. curried heads. Model these as four separate rule tables keyed by symbol — OwnValues included, so plain assignment falls out of the same machinery.

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

**Zhu, Bowen, Aayush Sabharwal, Songchen Tan, Yingbo Ma, Alan Edelman, and Christopher Rackauckas.** "Efficient Symbolic Computation via Hash Consing." arXiv:2509.20534 (MIT / JuliaHub).
> An implementation report on adding hash-consing to JuliaSymbolics via a global **weak-reference** table (up to 3.2× faster, 2× less memory), not a survey — but its short related-work section is the useful map, and it is more negative than usually reported. SymPy and SymEngine "stor[e] identical subexpressions in a set data structure, instead of … leveraging the DAG structure"; FriCAS and REDUCE get Lisp symbol interning but no proper hash-consing; **GiNaC "does use a form of reference counting," and of GiNaC and Symbolica alike it says "it is trivial to construct programs using either package that demonstrate identical subexpressions with different memory locations"** — i.e. neither hash-conses. On closed source it notes only that a Wolfram-internals page contains descriptions that "suggest hash-consing is used internally," with "no description of the performance effects." **Implication for you (our inference, not theirs): the mechanism needs immutable terms plus a GC that collects through weak references — precisely Haskell's model.** Free.

### Libraries

**`computational-algebra`** (Hiromi Ishii). `github.com/konn/computational-algebra`
> The implementation accompanying the paper above. Depends on his `type-natural` and `ghc-typelits-presburger` (a Presburger arithmetic type-checker plugin) packages.

**`algebra`** (Edward Kmett). Hackage / `github.com/ekmett/algebra`
> Fine-grained algebraic hierarchy: magmas → semigroups → groups → rings → modules → algebras, with additive/multiplicative distinctions. What Ishii's CAS builds on. *Recommended as your coefficient tower.*

**`numeric-prelude`** (Dylan Thurston, Henning Thielemann, Mikael Johansson). Hackage — **the README is where the argument lives**; the HaskellWiki "Numeric Prelude" page adds the structure list and the *Future plans* section.
> The canonical statement of **why the standard `Num` class is wrong for a CAS**: it "defines no semantics for the fundamental operations" (nothing asserts associativity of addition); it forces `Eq` and `Show` as superclasses, which is impossible to satisfy non-trivially for e.g. a function-valued ring (`data IntegerFunction a = IF (a -> Integer)`); and it lumps semantic operations together with representation-specific ones (`toInteger`, `decodeFloat`) while being "not fine-grained enough." Splits `Num` into `Additive`, `Ring`, `Field`, `Algebraic`, `Transcendental`, etc. (`Num → Additive, Ring, Absolute`; `Fractional → Field`; `Floating → Algebraic, Transcendental`). Axioms are stated as QuickCheck properties. The wiki candidly documents the gaps: "the code still misses proper linear algebra code," and static checking is still unsolved for "residue classes, matrix computations, infinite precision numbers, fixed point numbers." (Whether it relies on multi-parameter type classes is **[unverified]**.)

**`numhask`** (Tony Day). Hackage.
> A cleaner, more recently maintained alternative hierarchy. Note that `RebindableSyntax` is not the distinguishing feature — numeric-prelude's own README prescribes it too.

**`poly`** (Andrew Lelechenko / Bodigrim). Hackage.
> Fast `Vector`-backed uni- and multivariate polynomials with Karatsuba multiplication, integrating with the `semirings` `GcdDomain`/`Euclidean` classes. Documented as "at least 20x-40x faster than the [`polynomial`] library" — a self-reported figure, though the published per-operation benchmarks (22–39× on addition, 52–303× on multiplication) are consistent with it.

**`constructive-algebra`** (Anders Mörtberg et al.). Hackage.
> Small and very readable constructive ring/ideal/matrix code; coherent rings without Noetherian assumptions. Good reading rather than a dependency.

**`recursion-schemes`** (Edward Kmett) and **`data-fix`**. Hackage.
> `cata`/`ana` over a base functor — the clean way to write folds, evaluators, and substitution over your `Expr`.

**`uniplate`** (Neil Mitchell). Hackage.
> Generic traversal/rewriting over your expression type. The pragmatic choice for a uniform untyped `Expr`.

**`sbv`** (Levent Erkök). Hackage.
> How to overload `Num`/`Ord` for symbolic values (`.==`, `.>`) and offload to an SMT solver like Z3. Useful for zero-testing side conditions; *not* a rewriting engine.

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
> Maude's ancestor; foundational for "programming = equational specification + rewriting."

**ELAN, Stratego, Tom.** Strategy languages.
> Separate rewrite *rules* from the *strategies* controlling their application. Maps onto the distinction between your rule tables and your evaluation control (`ReplaceRepeated`, `//.`, evaluation order, holding), and the control layer is where the difficulty concentrates. (A line about "the strategies rather than the rewrite rules doing the heavy lifting" is often attributed to the Rascal paper; it is **not there** — don't cite it. What Rascal does show is its `visit` construct carrying explicit `top-down`/`bottom-up` strategy annotations.)

**Rascal** (CWI). Meta-programming / language workbench, descendant of ASF+SDF.
> How to package rewriting into a usable language.

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

**von zur Gathen & Gerhard.** *Modern Computer Algebra* companion site: `cosec.bit.uni-bonn.de`.
> Course materials and errata from the authors.

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
- Wolfram's historical essays
- Klop, *Term Rewriting Systems* (the Handbook chapter / CWI `CS-R9053`), and his shorter ICALP'90 survey (`ir.cwi.nl/pub/2667`)
- Bachmair et al., "Experiments with AC Discrimination Nets" (`ijcai.org`)
- Fateman, "A Review of Mathematica"

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

The following were not fetched directly during research and rest on secondary references — check the primary source before relying on exact editions, page numbers, or ISBNs: Terese (2003); Klop's lecture notes; the `numeric-prelude` Hackage/wiki pages; the Bachmair/Chen/Ramakrishnan AC-discrimination-net papers; the Bahr & Hvitved compositional data types paper; and the DiVA SymPy thesis.

Two figures in this bibliography are **vendor- or maintainer-reported benchmarks**, not independently verified: Symbolica's Rubi corpus timings and rule count, and the `poly` package's speedup claim. The Rubi rule count discrepancy (6600–6700 per Rubi's own site vs. 7,000+ per Symbolica) is noted where it appears.

The claim that the Wolfram kernel uses hash-consing internally is **inferred, not confirmed** — the kernel is closed source, and reverse-engineering writeups (including the wltools specification project) should be treated as informed inference.
