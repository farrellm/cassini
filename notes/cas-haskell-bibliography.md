# Bibliography: Building a Computer Algebra System in Haskell

Full reference list for the reading & building guide. Entries are grouped by role in the project. Annotations note what each source is *for*, difficulty where relevant, and availability. Items marked **[unverified]** were drawn from secondary references during research and should be spot-checked against the primary source before you rely on exact edition, page, or ISBN details.

---

## 1. Textbooks — Computer Algebra Algorithms

**Cohen, Joel S.** *Computer Algebra and Symbolic Computation: Elementary Algorithms.* A K Peters, 2002. ISBN 1-56881-158-6. Reprinted by Routledge/CRC, ISBN 9781568811581.
> The core implementer's text. Expressions as trees; structure-based operators; automatic simplification. Algorithms in "Mathematical Pseudo-Language" (MPL) with Maple, Mathematica, and MuPAD companions. Prerequisite: one undergraduate abstract algebra course. *Essential — Stage 0/1.*

**Cohen, Joel S.** *Computer Algebra and Symbolic Computation: Mathematical Methods.* A K Peters, 2003. Routledge/CRC reprint ISBN 9780367659479.
> Polynomial decomposition, factorization, and further methods from the same implementer's angle. *Essential — Stage 2/3.*

**von zur Gathen, Joachim, and Jürgen Gerhard.** *Modern Computer Algebra.* 3rd ed. Cambridge University Press, 2013. 808 pp. ISBN 9781107039032.
> The deep reference: modular arithmetic, Chinese remainder, fast Euclidean algorithm, Hensel lifting, finite-field factorization, evaluation/interpolation. Complete proofs and complexity analysis; includes implementation reports. 3rd edition adds GCD and symbolic integration material and reworks the Fast Euclidean chapter. Companion site: `cosec.bit.uni-bonn.de`. Graduate difficulty; use as a lookup reference, not a linear read. *Essential as reference.*

**Geddes, Keith O., Stephen R. Czapor, and George Labahn.** *Algorithms for Computer Algebra.* Kluwer Academic Publishers, 1992. ISBN 0-7923-9259-0.
> The most complete single volume covering the whole implementer's pipeline: normal forms, polynomial/rational/power-series arithmetic, homomorphisms and CRT, Newton iteration and Hensel construction, polynomial GCD, factorization, Gröbner bases, integration of rational functions, and the Risch algorithm. Pascal-like pseudocode. *Essential — the one algorithms reference to own if you buy only one.*

**Bronstein, Manuel.** *Symbolic Integration I: Transcendental Functions.* 2nd ed. Algorithms and Computation in Mathematics vol. 1. Springer, 2005.
> The standard integration reference: Hermite reduction, Rothstein–Trager, Lazard–Rioboo–Trager, and the Risch algorithm proper. 2nd ed. adds a chapter on parallel/Risch–Norman integration. Ready-to-implement pseudocode. **Volume II (algebraic functions) was never completed — Bronstein died before finishing it**, so the algebraic case remains scattered across research papers. *Essential at Stage 3.*

**Petkovšek, Marko, Herbert S. Wilf, and Doron Zeilberger.** *A=B.* A K Peters, 1996. Foreword by Donald E. Knuth.
> Algorithmic hypergeometric summation: Gosper's algorithm, Zeilberger's creative telescoping, the WZ method, Petkovšek's `Hyper`. **Freely and legally available as a PDF from Herbert Wilf's University of Pennsylvania page** — the authors released it. Does *not* cover Karr's algorithm. *Essential for summation; free.*

**Zippel, Richard.** *Effective Polynomial Computation.* Kluwer Academic Publishers, 1993. ISBN 0-7923-9375-9. ~363 pp.
> Practical vs. theoretical tradeoffs in polynomial algorithms, by the originator of sparse modular ("Zippel") interpolation for multivariate GCD. Strong on where asymptotically optimal algorithms are the wrong practical choice. Out of print but findable. *Optional; valuable at Stage 2.*

**Davenport, James H., Yvon Siret, and Évelyne Tournier.** *Computer Algebra: Systems and Algorithms for Algebraic Computation.* 2nd ed. Academic Press, 1993. Preface by Daniel Lazard.
> Gentler, systems-oriented survey. Good conceptual overview; less of an implementation cookbook. *Optional.*

**Jenks, Richard D., and Robert S. Sutor.** *AXIOM: The Scientific Computation System.* Springer, 1992. ISBN 3-540-97855-0.
> The design document for the strongly-typed CAS — categories and domains (Ring, Field, …) as first-class types. Now Volume 0 of the open Axiom literate-program series. *Essential reading for a Haskell implementer* because Axiom's typed algebra hierarchy is the closest existing analogue to a type-driven Haskell CAS. See §5 for the free literate volumes.

---

## 2. Textbooks — Term Rewriting

**Baader, Franz, and Tobias Nipkow.** *Term Rewriting and All That.* Cambridge University Press, 1998. ISBN 0-521-77920-0 (pbk).
> The book for the evaluator layer. Abstract reduction systems, termination, confluence, critical pairs, Knuth–Bendix completion, universal algebra, unification theory; also covers Gröbner bases / Buchberger as an instance of completion. Main algorithms given informally *and* as Standard ML programs; unification and congruence closure developed with efficient code. 170+ exercises. *Essential — read in parallel with Cohen.*

**Terese** (Marc Bezem, Jan Willem Klop, Roel de Vrijer, eds.). *Term Rewriting Systems.* Cambridge Tracts in Theoretical Computer Science 55. Cambridge University Press, 2003.
> The comprehensive advanced reference. *Optional — only if you need confluence/termination theory beyond Baader & Nipkow.* **[unverified]**

**Klop, Jan Willem.** *Term Rewriting Systems* (lecture notes). Circulated free online; also published in *Handbook of Logic in Computer Science*, Vol. 2 (Oxford, 1992).
> Classic free lecture notes on rewriting theory. *Optional.* **[unverified]**

---

## 3. Foundational Papers

**Richardson, Daniel.** "Some Unsolvable Problems Involving Elementary Functions of a Real Variable." *Journal of Symbolic Logic* 33, no. 4 (1968): 514–520.
> Richardson's theorem: for expressions built from the rationals, π, ln 2, a variable *x*, addition/subtraction/multiplication/composition, and `sin`, `exp`, `abs`, the predicate "E = 0?" is recursively undecidable. **The reason no CAS simplifier can be complete.** Read the statement even if you skip the proof.

**Swierstra, Wouter.** "Data types à la carte." *Journal of Functional Programming* 18, no. 4 (2008): 423–436. DOI: 10.1017/S0956796808006758.
> ASTs as coproducts of functors (`data (f :+: g) e = Inl (f e) | Inr (g e)`) with `Fix` and a subtyping class `(:<:)`. The reference solution to the expression problem in Haskell — Wadler called it the best he'd seen. *Read for context; likely unnecessary if your core `Expr` is untyped and uniform.*

**Bahr, Patrick, and Tom Hvitved.** "Compositional Data Types." (Workshop on Generic Programming, 2011) and Matthew Pickering's closed-type-family reimplementation.
> Productionized descendants of "Data types à la carte." *Optional.* **[unverified]**

**Cole, Christopher A., and Stephen Wolfram.** "SMP: A Symbolic Manipulation Program." *Proceedings of the 1981 ACM Symposium on Symbolic and Algebraic Computation (SYMSAC '81)*.
> The earliest primary source on the symbolic-expression + transformation-rule architecture that became Mathematica. Archived as PDF on Wolfram's content servers.

**Greif, Jerry.** "The SMP Pattern-Matcher." *EUROCAL '85*, Springer LNCS 204.
> The earliest published description of how this family of pattern matchers was designed. Archived on Wolfram's content servers.

**Bachmair, Leo, Ta Chen, I. V. Ramakrishnan, et al.** Work on associative-commutative discrimination nets and term indexing, ~1993, Springer LNCS.
> Primary research on generalizing discrimination nets to AC symbols and on term indexing for Knuth–Bendix completion. Read before optimizing your matcher. **[unverified — exact titles/volumes need checking]**

---

## 4. Pattern Matching — The Hard Engineering

**Krebber, Manuel.** "Non-linear Associative-Commutative Many-to-One Pattern Matching with Sequence Variables." Master's thesis, RWTH Aachen. arXiv:1705.00907.
> The most complete single document on the combined feature set you need: AC matching + sequence variables + non-linear patterns + many-to-one via discrimination nets. *Essential for Stage 1 matcher design.* Free.

**Krebber, Manuel, Henrik Barthels, and Paolo Bientinesi.** "MatchPy: A Pattern Matching Library." arXiv:1710.06915. See also arXiv:1710.00077.
> The readable modern treatment of Mathematica-style matching: syntactic plus associative and/or commutative functions, sequence variables (the `BlankSequence`/`BlankNullSequence` analogue), constraints, many-to-one discrimination nets. Open-source Python implementation. Key facts: general AC matching is **NP-hard** (worst-case exponential); *linear* AC matching (no repeated variables) is polynomial — hence the standard two-stage strategy of matching the linearized pattern then checking non-linear constraints. Free.

---

## 5. Open-Source Systems to Study

Ordered roughly by relevance to a Wolfram-style Haskell build.

**Expreduce** (Cory Walker). Go. `github.com/corywalker/expreduce`
> **The single most relevant codebase.** From-scratch Wolfram Language term-rewriter/CAS with Blank/BlankSequence, Orderless/Flat matching, conditional rules, attributes, and the fixed-point evaluator. The README describes it as "experimental quality and… not currently intended for serious use" — which makes it small and readable. *Lesson: how to structure evaluator + matcher in a statically typed host language.*

**Mathics / Mathics3.** Python, GPL v3. `github.com/Mathics3/mathics-core`
> A fuller open Wolfram Language kernel: parser building Expressions, evaluator, WL built-ins, delegating heavy math to SymPy and mpmath. *Lesson: realistic module layout for a batteries-included WL kernel.*

**Symja.** Java. (formerly MathEclipse)
> Oldest actively maintained WL reimplementation; mature parser, large function library. One of only two complete ports of the Rubi integration ruleset (targeting Rubi 4.16). *Lesson: grep for specific algorithm implementations.*

**MockMMA** (Richard Fateman, 1991). Lisp.
> The first WL reimplementation; famously received a cease-and-desist from Wolfram. Fateman's accompanying implementation notes are instructive. *Historical, but short and pointed.*

**SymPy.** Python, BSD. `sympy.org`
> The most approachable *full* CAS to read. Pure Python with no invented language — the reference paper notes that Python itself is used for both internal implementation and end-user interaction. *Lesson: how to organize a large CAS — assumptions system, `Basic`/`Expr` core, `polys` module — and how automatic-simplification decisions get made.*
> - **Meurer, Aaron, et al.** "SymPy: symbolic computing in Python." *PeerJ Computer Science* 3 (2017): e103. DOI: 10.7717/peerj-cs.103. (28 authors.) Free.

**GiNaC** ("GiNaC is Not a CAS"). C++. `ginac.de`
> *Lessons:* (1) deliberately abolishes the low-level/high-level language split — relevant to a Haskell-native ambition; (2) reference counting with copy-on-write for structure sharing; (3) numeric tower built on CLN over GMP; (4) clean polymorphic `ex`/`basic` design with automatic normalization.
> - **Bauer, Christian, Alexander Frink, and Richard Kreckel.** "Introduction to the GiNaC Framework for Symbolic Computation within the C++ Programming Language." *Journal of Symbolic Computation* 33, no. 1 (2002): 1–12.

**SymEngine.** C++ core with bindings in many languages, including a thin Haskell FFI package (`symengine` on Hackage).
> The fast C++ rewrite of SymPy's core. *Lesson: the "fast typed core + scripting frontend" architecture.* Also a candidate to FFI into if you'd rather not write your own numeric/polynomial backend.

**Maxima.** Common Lisp. The open descendant of MIT Macsyma.
> *Lesson: the untyped-expression paradigm in its native habitat* — why homoiconic s-expressions map so naturally onto expression trees, and how a 50-year-old general simplifier and rule system (`tellsimp`, `defrule`) is structured. Large and old; grep, don't read cover to cover. Macsyma is the ancestor of this whole lineage — Wolfram was a Macsyma user, and also studied Schoonschip's code.

**Reduce.** Lisp. Open source.
> The other long-lived Lisp CAS. Same lesson as Maxima, different design choices.

**Axiom / FriCAS.** Lisp core + SPAD algebra language. `axiom-developer.org`, `nongnu.org/axiom`
> Distributed as a **literate program in ~15 numbered volumes, freely downloadable**: Vol. 0 (Jenks & Sutor), Vol. 10.x covering algebra implementation, theory, categories, domains, and packages. The volumes explain the *why* of a rigorous typed algebra hierarchy. *Essential background for the typed-vs-untyped decision.*

**Symbolica.** Rust, with Python/C++ bindings. `symbolica.io`
> Modern, source-available, high-performance CAS "built for large expressions." Pattern matcher supports commutative/associative matching and wildcards (`x_`). Per Symbolica's own writeup it provides "the only complete port of the latest Rubi 4.17 integration system outside the Wolfram Language, preserving its 7,000+ ordered rules and passing the complete 72,944-problem Rubi corpus" (MIT-licensed `symbolica-integrate` crate), processing that corpus "in 18 minutes of wall time, on a Ryzen 9 5900X parallelized over 8 cores" (57 ms median per problem). **These are vendor-reported figures.** *Lesson: rule-based integration as a pragmatic complement to Risch, and how to make AC matching fast.*
> **License caveat:** source-available but commercially licensed — free only for personal/non-commercial single-instance use. Fine to read; check the license before depending on it.

**Rubi** (Albert Rich). `rulebasedintegration.org`
> The rule-based integration ruleset. Rubi's own site and Rich's "Vision" page describe it as "over 6600–6700 integration rules" — note the discrepancy with Symbolica's "7,000+" count of its port.

**Singular, CoCoA, Macaulay2.** Specialized: Gröbner bases, commutative algebra, algebraic geometry.
> Consult selectively at Stage 3 for specific algorithms done fast and correctly.

**PARI/GP.** C. Number theory.

**FLINT.** C. Fast Library for Number Theory.
> The modern high-performance substrate under Sage and others; the reference for state-of-the-art polynomial and bignum performance.

---

## 6. Wolfram Language Primary Sources

**Wolfram Research.** "Evaluation of Expressions" and "Evaluation." Wolfram Language & System Documentation Center, `reference.wolfram.com`. Free.
> **The authoritative behavioral spec.** The standard evaluation procedure step by step: evaluate the head; apply Hold attributes (HoldFirst / HoldRest / HoldAll / HoldAllComplete); strip `Unevaluated` (unless HoldAllComplete); flatten `Sequence` (unless SequenceHold); apply **Flat**, **Listable**, **Orderless** immediately after element evaluation; apply upvalues from the arguments, then downvalues/built-ins from the head; re-evaluate to a **fixed point**.

**Wolfram Research.** Documentation on **Attributes**: `HoldAll`, `HoldFirst`, `HoldRest`, `HoldAllComplete`, `Flat`, `Orderless`, `Listable`, `OneIdentity`, `SequenceHold`, `Protected`, `Constant`. Free.
> `OneIdentity` in particular affects pattern matching (treating `f[a]` as `a`) and is easy to get wrong.

**Wolfram Research.** Documentation on **UpValues, DownValues, SubValues**. Free.
> The rule storage model: DownValues attach rules to a symbol as head (`f[...] := ...`); UpValues attach to a symbol appearing as an *argument*; SubValues handle curried heads `f[x][y]`. Model these as separate rule tables keyed by symbol.

**riptutorial.** "Wolfram Language — Evaluation Order."
> A concise pseudo-algorithm of the whole evaluation loop. Correctly notes that `Hold`, `ReleaseHold`, `ReplacePart` etc. are *not* evaluator special cases but fall out of attributes plus ordinary definitions. Free.

**Wolfram, Stephen.** "There Was a Time before Mathematica…" (2013). `writings.stephenwolfram.com`. Free.
> SMP's design and the origin of the symbolic-expression + transformation-rule paradigm. Notes that some early SMP pattern-matcher/evaluator code still runs in Mathematica.

**Wolfram, Stephen.** "Celebrating a Third of a Century of Mathematica…" (2021). `writings.stephenwolfram.com`. Free.
> The clearest statement of the core design decision: represent everything as a symbolic expression, represent all operations as transformations, and apply the first transformation that applies until nothing changes.

**wltools.** "Wolfram Language Specification" community project. `wltools.github.io`.
> Community reverse-engineering of WL semantics. **Informed inference, not authoritative** — the kernel is closed source.

---

## 7. Haskell — Papers, Libraries, and Design

### Papers

**Ishii, Hiromi.** "A Purely Functional Computer Algebra System Embedded in Haskell." arXiv:1807.01456. Published in *Computer Algebra in Scientific Computing (CASC 2018)*, Springer LNCS 11077, pp. 288–303. DOI: 10.1007/978-3-319-99639-4_20.
> **The reference for typed algebra in Haskell.** Encodes polynomial arity, monomial ordering, and coefficient ring as type-level parameters so elements of ℚ[x,y,z] and ℚ[w,x,y] can't be added by mistake. Implements Gröbner bases with F4, F5, and Hilbert-driven algorithms. Positioned explicitly against DoCon "with more emphasis on safety and correctness." *Caveat: the type system checks arity and identity, not ring axioms — those are verified by QuickCheck property tests, not proof.* Free on arXiv.

**Zhu, Bowen.** "Efficient Symbolic Computation via Hash Consing." arXiv:2509.20534 (MIT).
> Surveys the structure-sharing landscape: GiNaC's reference counting, Symbolica's interning, JuliaSymbolics' weak-reference hash-consing. Notes that Wolfram-internals blog descriptions "suggest hash-consing is used internally" while cautioning this is unconfirmed. **Key implementation point for you: hash-consing works best with immutable expressions and a tracing GC — precisely Haskell's model.** Free.

### Libraries

**`computational-algebra`** (Hiromi Ishii). `github.com/konn/computational-algebra`
> The implementation accompanying the paper above. Depends on his `type-natural` and `ghc-typelits-presburger` (a Presburger arithmetic type-checker plugin) packages.

**`algebra`** (Edward Kmett). Hackage / `github.com/ekmett/algebra`
> Fine-grained algebraic hierarchy: magmas → semigroups → groups → rings → modules → algebras, with additive/multiplicative distinctions. What Ishii's CAS builds on. *Recommended as your coefficient tower.*

**`numeric-prelude`** (Henning Thielemann et al.). Hackage. See also the HaskellWiki "Numeric Prelude" page.
> The canonical statement of **why the standard `Num` class is wrong for a CAS**: it "defines no semantics for the fundamental operations" (nothing asserts associativity of addition); it forces `Eq` and `Show` as superclasses, which is impossible to satisfy non-trivially for e.g. a function-valued ring (`data IntegerFunction a = IF (a -> Integer)`); and it lumps semantic operations together with representation-specific ones (`toInteger`, `decodeFloat`) while being "not fine-grained enough." Splits `Num` into `Additive`, `Ring`, `Field`, `Algebraic`, `Transcendental`, etc. (`Num → Additive, Ring, Absolute`; `Fractional → Field`; `Floating → Algebraic, Transcendental`). Uses MPTCs; has a QuickCheck test suite; candidly documents gaps (linear algebra, residue classes, fixed-point numbers). **[unverified — primary Hackage page not directly fetched during research]**

**`numhask`** (Tony Day). Hackage.
> Cleaner modern alternative hierarchy using `RebindableSyntax`.

**`poly`** (Andrew Lelechenko / Bodigrim). Hackage.
> Fast `Vector`-backed uni- and multivariate polynomials with Karatsuba multiplication, integrating with the `semirings` `GcdDomain`/`Euclidean` classes. Maintainer benchmarks it "at least 20x–40x faster than the `polynomial` library" — a self-reported figure.

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

**`dumb-cas`.** Hackage.
> A small Haskell take on untyped symbolic rewriting with user-defined rules — described by its author as aiming for Lisp-like flexibility with regex-like conciseness. Minimal, but worth reading as a starting point, since **no Haskell library offers Mathematica-grade pattern matching off the shelf.**

**DoCon** (Sergei D. Mechveliani).
> The pioneering Haskell CAS. Used runtime "sample arguments" for ring identity — the design Ishii explicitly improves on. Historical reference.

**HaskSymb** (Christopher Olah, 2012). `github.com/colah/HaskSymb`, plus his accompanying blog post.
> Small, readable illustration of untyped symbolic rewriting with QuasiQuoters and ViewPatterns. **Read for the author's conclusion as much as the code:** he found no clean way to put variables into types — "The big issue I'm facing is appropriate types for symbolic expressions. In particular, how do I handle variables in types?" — and treats the typed approach as the unresolved crux. Take the hint and keep the core untyped.

---

## 8. Rewriting-Based Language Design

**Maude** (SRI International). Rewriting logic and membership equational logic.
> **The system to study for efficient, correct matching modulo associativity/commutativity/identity.** High-performance C++ engine with powerful reflection and metaprogramming.

**OBJ / OBJ3** (Joseph Goguen et al.). Order-sorted equational logic.
> Maude's ancestor; foundational for "programming = equational specification + rewriting."

**ELAN, Stratego, Tom.** Strategy languages.
> Separate rewrite *rules* from the *strategies* controlling their application. The key practical lesson (as the Rascal paper observes): in practice the strategies, not the rules, do the heavy lifting. Maps onto the distinction between your rule tables and your evaluation control (`ReplaceRepeated`, `//.`, evaluation order, holding).

**Rascal** (CWI). Meta-programming / language workbench, descendant of ASF+SDF.
> How to package rewriting into a usable language.

**Pure** (Albert Gräf).
> A modern, practical, dynamically typed functional language *based on term rewriting*, with ML-style syntax. Arguably the closest existing "small language built on term rewriting" to what you're building. Readable.

---

## 9. Blog Posts, Theses, and Course Materials

**Johansson, Fredrik.** "Things I would like to see in a computer algebra system." Blog post.
> A practitioner's list from the FLINT/Arb author. Central point for your Stage 0: "the core datatype in computer algebra is the arbitrary-size integer," while "hardware, compilers, programming languages are not at all designed for" it — a direct argument for getting the bignum substrate right first.

**"Constructing a Computer Algebra System Capable of…"** MSc thesis, available via DiVA portal.
> Extends SymPy; a worked example of scoping a CAS project and of how automatic-simplification decisions get made. **[unverified — exact title/author need checking]**

**Brun, Victor.** "Building a Computer Algebra System in Go." Blog series.
> Worked build-log of a from-scratch CAS; useful for scoping intuition.

**von zur Gathen & Gerhard.** *Modern Computer Algebra* companion site: `cosec.bit.uni-bonn.de`.
> Course materials and errata from the authors.

**Olah, Christopher.** Blog post accompanying HaskSymb (2012).
> See §7.

---

## Availability at a Glance

**Free PDFs / online, start here at zero cost:**
- *A=B* (Wilf's UPenn page)
- Wolfram evaluation & attributes documentation (`reference.wolfram.com`)
- Ishii, arXiv:1807.01456
- Krebber MatchPy papers, arXiv:1710.06915 / 1710.00077 / 1705.00907
- Zhu hash-consing survey, arXiv:2509.20534
- Axiom literate volumes (`axiom-developer.org`)
- SymPy architecture paper (PeerJ CS, open access)
- Wolfram's historical essays
- Klop's lecture notes

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

**Two-book minimum if budget-constrained:** Cohen Vol. 1 + Baader & Nipkow.

---

## Verification Notes

The following were not fetched directly during research and rest on secondary references — check the primary source before relying on exact editions, page numbers, or ISBNs: Terese (2003); Klop's lecture notes; the `numeric-prelude` Hackage/wiki pages; the Bachmair/Chen/Ramakrishnan AC-discrimination-net papers; the Bahr & Hvitved compositional data types paper; and the DiVA SymPy thesis.

Two figures in this bibliography are **vendor- or maintainer-reported benchmarks**, not independently verified: Symbolica's Rubi corpus timings and rule count, and the `poly` package's speedup claim. The Rubi rule count discrepancy (6600–6700 per Rubi's own site vs. 7,000+ per Symbolica) is noted where it appears.

The claim that the Wolfram kernel uses hash-consing internally is **inferred, not confirmed** — the kernel is closed source, and reverse-engineering writeups (including the wltools specification project) should be treated as informed inference.
