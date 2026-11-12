# Bronstein's Volume II: what it would have covered, and where that material lives

Manuel Bronstein's *Symbolic Integration I: Transcendental Functions* stops at the transcendental
case and promises a second volume on algebraic functions. That volume never appeared. This file
collects what can be established about it, a reconstruction of its likely contents, and every source
we know of that carries the material it would have carried.

Written 2026-11-11, and revised the same day when four of the missing sources were supplied —
Trager's thesis, Bronstein's lazy-Hermite report, his 1990 paper, Risch's 1970 announcement and
Davenport's monograph — and opened. Revised again on 2026-11-12 with seven more, one of which,
Abramov's obituary, changed §1, and then with four more (Davenport 1984, Chevalley, Bliss,
Stichtenoth), and then eight more (Miller, the FriCAS status page, Hess, Combot, Masser & Zannier,
Fulton, Chen et al. 2016b, Weil 1948). The per-file annotations for this directory are in [`CLAUDE.md`](./CLAUDE.md).

## How far to trust each statement here

Every claim carries one of three standings, and they are not interchangeable:

| Tag | Meaning |
| :--- | :--- |
| **[held]** | Checked on 2026-11-11 against a document held in this corpus, which is named. |
| **[cited]** | The *citation* was read in a held document's reference list, so the work exists and is relevant by that document's own account. The work itself was **not opened**. |
| **[memory]** | Recalled without a document in hand. Not verified in this session. Treat as a lead to check, not a fact. |

Anything about *what Volume II would have contained* is a fourth thing again: **our inference**. No
table of contents, draft or manuscript of Volume II is known to us, and none is held.

---

## 1. What is actually known about Volume II

**It was planned.** **[held]** `../papers/textbooks/bronstein2005_symbolic_integration_1.pdf` says so
three times:

- Preface to the First Edition: "The reader will notice that several topics in symbolic integration
  are missing from this book, the main one being the integration of algebraic functions. Including
  algorithms for integrating algebraic and mixed algebraic-transcendental functions would however
  easily double the size of this book, as well as increase the mathematical prerequisites, since
  those algorithms require prior familiarity with algebraic curves and functions. We have thus
  decided to cover algebraic functions in a second volume, which will hopefully appear in the near
  future. In the meantime, this book is an adequate preparation to the extensive literature on the
  integration of algebraic functions [8, 9, 11, 14, 29, 73, 74, 76, 91]."
- B. F. Caviness's foreword: "The longer and more difficult part involving the integration of
  algebraic functions must await a second volume."
- §5.2, *Outline and Scope of the Integration Algorithm*: "Although the problem of integrating
  elementary functions containing algebraic functions is also decidable, the algorithms used in the
  algebraic function case are beyond the scope of this book", followed by the same nine references.

(The held scan's text layer reads "algebraictranscendental" and "famiharity"; the quotation above
restores the hyphen and the spelling.)

**It was not mentioned again.** **[held]** The Preface to the Second Edition, dated "Sophia
Antipolis, June 2004", describes the new chapter on parallel integration and the added references
and exercises, and says nothing about a second volume. The held copy of his tutorial (§4.2 below; PDF
created January 2005) lists the book in its references as "Symbolic Integration I – Transcendental
Functions. Springer, Heidelberg, 1997. 2nd Ed., 2004" and lists no Volume II.

**Bronstein died on 6 June 2005, and the second volume was left uncompleted.** **[held]**
`abramov2006_in_memory_of_manuel_bronstein.pdf`, the obituary by his collaborator S. A. Abramov
(received by the journal on 9 September 2005; a translation from the Russian):

> "Later, he intended to write a monograph in two volumes devoted to all aspects of symbolic
> integration. The first volume was written and went through two editions at the Springer publishing
> house in 1997 and 2004. The second volume remained uncompleted."

It gives the death as "On June 6, 2005 … of a heart attack. He was only forty-one", in Montpellier.
`abramov_bronstein_petkovsek2020_pi_sigma_difference_equations.pdf` **[held]** agrees on the date and
the age.

**What is still not known.** How far Volume II got. "Remained uncompleted" is the only statement on
it we hold; it implies an intention that outlived the first edition, and stops short of saying that
a manuscript, or any part of one, existed. No draft, outline or table of contents is known to us.
The defensible statement is: *planned, left uncompleted at its author's death in 2005, and never
published.*

**A correction to this file's own first version.** Before the obituary was held, this section said
that "he died before finishing it" asserted "a work in progress that no held document shows". That
was right about what was held and wrong about the world: the phrasing the notes originally carried,
"never completed", is close to Abramov's. What remains unsupported is only the stronger reading —
that he was actively writing it when he died.

---

## 2. What it would have covered — a reconstruction

**Our inference, from five things:** what the preface says the volume was for; the nine references
it sends the reader to; the algebraic sections of Bronstein's own tutorial, which is the nearest
thing to an outline of Volume II in his hand; the contents of Trager's thesis and of Bronstein's 1990
paper, which between them are the pure and the mixed case; and the code he wrote for
Scratchpad/Axiom.

The preface names two subjects — "algebraic and mixed algebraic-transcendental functions" — and one
prerequisite, "algebraic curves and functions". The tutorial's section list **[held]**
(`bronstein1998_symbolic_integration_tutorial.pdf`) fills that in:

| Tutorial section | Subject |
| :--- | :--- |
| 2 *Algebraic Functions* (opening) | Integral elements, the integral closure of `K[x]` in `E`, numerators and denominators relative to a basis |
| 2.1 *The Hermite reduction* | Trager's Hermite reduction over an integral basis; the lazy Hermite reduction |
| 2.2 *Simple radical extensions* | `y^n = a`: an explicit integral basis, and a diagonal system |
| 2.3 *Liouville's Theorem* | The algebraic-function form of the theorem |
| 2.4 *The integral part* | Integrality at infinity, bases normal at infinity, Trager's change of variable |
| 2.5 *The logarithmic part* | Residues, divisors, principality, and the points-of-finite-order problem |
| 3.8 *The algebraic logarithmic case* | `E` algebraic over `K(t)`, `t = log b` |
| 3.9 *The algebraic exponential case* | `E` algebraic over `K(t)`, `t = e^b` |

**Trager's thesis has the same shape at four times the length** **[held]**
(`trager1984_integration_of_algebraic_functions.pdf`, contents page):

| Chapter | Sections |
| :--- | :--- |
| 1 *Introduction* | Review of previous work; Outline of thesis |
| 2 *Integral Bases* | Radical of the Discriminant; Computing the Idealizer; Normalize at infinity; Genus computation; Simple radical extensions |
| 3 *Absolute Irreducibility* | Exact coefficient fields and Regular extensions; Algorithmic considerations; Binomial polynomials |
| 4 *The Rational part of Integral* | Rational function integration; Algebraic functions; Poles at infinity |
| 5 *Log terms and Divisors* | Properties of logarithmic differentials; Computing the residues; Constructing Divisors; Dealing with Branch places |
| 6 *Principal Divisors and Points of Finite Order* | Principal Divisors; Good Reduction; Algorithms for Divisor reduction |
| 7 *Conclusions and Future Research* | |
| Appendix A *Integration of simple radical extensions* | Structure theorems; A Generalized Risch algorithm; Summary and Conclusions |

**And Bronstein's 1990 paper is the mixed case in full** **[held]**
(`bronstein1990_integration_of_elementary_functions.pdf`). A footnote on its first page says it "is a
revised version of the author's dissertation, Dpt. of Mathematics, U.C. Berkeley, CA, May 1987", and
its introduction gives the plan: "Part 1 introduces the problem, and presents the algebraic
preliminary results and subalgorithms required. Part 2 contains the solution of the integration
problem, while Part 3 contains Risch's solution of the associated equation problem." If Volume II
had a second half, this 57-page paper is the best evidence of what was in it.

A book-length treatment would plausibly have run as follows. Each step says what the tutorial
establishes **[held]** and what a full treatment would have had to add (**our inference**).

### 2.1 Background: algebraic curves and function fields

The preface's stated prerequisite. The tutorial introduces, in a page or two each: integrality over
`K[x]`; integral bases; places, the order function at a place, divisors and principal divisors;
ramification indices; Puiseux expansions at infinity; the genus. Geddes, Czapor & Labahn §12.8
**[held]** says of the same material that "the computational algebraic geometry background … could
easily comprise two long chapters". Volume I's "easily double the size of this book" is consistent
with that. Bronstein's 1990 paper **[held]** simply assumes it: "We assume that the reader is familiar
with the contents of (Chevalley 1951, chapter I)". A book could not have.

### 2.2 Canonical form: numerators, denominators, integral bases

An algebraic function has no unique numerator and denominator (`√x / x = x / √x`). Fixing a basis
`w = (w₁,…,wₙ)` of `E` over `K(x)` made of integral elements gives one: `α = (A₁w₁ + … + Aₙwₙ)/D`.
The basis has to be an **integral basis** — one generating the whole integral closure over `K[x]` —
for the reductions below to be guaranteed. Computing one is the first expensive step; the tutorial
names Trager's method and "the local alternative" of van Hoeij (whose abstract **[held]** says
Trager's is "the method used by Maple 5.2 and AXIOM", and that his own "is based on Puiseux
expansions" and can be seen "as a variant on the Coates' algorithm"), and says it "can be in general more
expensive than the rest of the reduction process".

### 2.3 Hermite reduction

Same goal as in the rational case: reduce to an integrand with squarefree denominator. The
reduction step becomes a linear system `f₁S₁ + … + fₙSₙ = A₁w₁ + … + Aₙwₙ` over `K(x)`. The tutorial
credits Trager with proving that over an integral basis this system always has a unique solution
with denominator coprime to `V` when the multiplicity is above 1, and gives a worked example
(`y⁴ + (x² + x)y − x² = 0`, integrand `y³/x²`) where a non-integral basis makes the reduction fail.

**The lazy Hermite reduction** is Bronstein's own contribution and would surely have been in the
book: start from any basis of integral elements, and when the reduction fails, the failure itself
yields a new integral element outside the current module (the tutorial's Theorems 1–3), which
enlarges the basis. The chain must stabilise, so either the reduction succeeds or the denominator is
already squarefree — and an integral that is itself algebraic is found without ever computing a full
integral basis.

The report itself **[held]** (`bronstein1998_lazy_hermite_reduction.pdf`) claims more than the
tutorial repeats. Its abstract: the ordinary reduction "requires the precomputation of an integral
basis, which makes the reduction impractical for either multiple algebraic extensions or complicated
ground fields", and the lazy one needs no "a priori computation of either a primitive element or
integral basis". And it is stated from the first page over a monomial extension `k(t)` of a
differential field, not over `K(x)` — so it is a tool for the mixed case of §2.8 as much as for pure
algebraic functions.

### 2.4 Simple radical extensions

For `y^n = a` the tutorial writes down an integral basis directly from a squarefree factorisation,
notes that it is already normal at infinity, and shows the Hermite system becoming diagonal with an
explicit solution. This is the tractable special case — square roots and `n`-th roots of rational
functions — and it is where the worked examples in the tutorial and in Geddes §12.8 all live.

### 2.5 Liouville's theorem and the integral part

If `f ∈ E` has an elementary integral then `f = v′ + Σ cᵢ uᵢ′/uᵢ` with `v ∈ E`. After Hermite
reduction `v` is integral, the analogue of the polynomial part. Rather than compute it, Trager's
algorithm changes variable (`x = N + 1/z`) so that either `v′ = 0` or the integral is not
elementary; this needs the basis made **normal at infinity**. The tutorial states the six-step first
half of Trager's algorithm in full.

### 2.6 The logarithmic part

The hard half. A double resultant gives a polynomial whose nonzero roots are the residues; a
ℚ-basis of the residues gives candidate divisors `δⱼ`; the integral is elementary only if some
integer multiple of each `δⱼ` is **principal**, and the generator is the argument of a logarithm.

Deciding whether *any* multiple of a divisor is principal is the **points-of-finite-order problem**,
and it is what separates this from the rational case, where every degree-zero divisor is principal.
The tutorial's method: reduce the curve modulo a "good" prime, where a multiple `M ≤ (1 + √(p^q))^{2g}`
is guaranteed principal (it cites Weil), find `M` by trial, and conclude for characteristic 0. The
source of that bound is **[held]**, in `weil1948_sur_les_courbes_algebriques_retranscription.pdf`,
part II §IV: the zeta function's numerator is `∏(1 − αᵢu)` over `2g` roots with `αᵢᾱᵢ = q`. The
bound itself, `(1 + √q)^{2g}`, is that product at `u = 1` with every `|αᵢ| = √q` — a step Weil does
not write out in the passage read, so **our inference**.
Geddes §12.8 **[held]** describes the same step as reducing "modulo two different primes" and calls
it "a significant achievement". The two-prime form is already in Risch's 1970 announcement **[held]**
(`risch1970_solution_of_integration_in_finite_terms.pdf`): "we will have a bound for the torsion if
we can find the class numbers of two good reductions C¹ and C² which are defined over residue class
fields of different characteristics." Risch calls the reduction to "bounding torsion on the Jacobian
variety of an algebraic curve" "the most surprising aspect of the integration problem". Trager's
abstract **[held]** claims the practical step: "a novel algorithm for solving this problem which is
able to compute the exact order of the given divisor by examining its behavior under 'reduction
modulo p'." For hyperelliptic curves the tutorial points to Bertrand's Jacobian
arithmetic as the efficient special case.

Two of the tutorial's worked examples are worth keeping as test cases:

- `∫ x dx / √(1 − x³)` — the resultant's only root is 0, so the integral is **not elementary**.
- `∫ dx / (x√(1 − x³)) = ⅓ log((√(1 − x³) − 1)/(√(1 − x³) + 1))` — `δ` and `2δ` are not principal,
  `3δ` is.

### 2.7 Supporting algorithms the tutorial assumes

Named in the tutorial as preconditions, and each a chapter's worth in a book: computing a primitive
element; **absolute factorisation** (the minimal polynomial must be absolutely irreducible); divisor arithmetic through
fractional ideals; arithmetic in function fields over finite fields.

### 2.8 Mixed algebraic–transcendental towers

The second subject the preface names, and the part with the least written down anywhere. The
tutorial's §3.8 and §3.9 treat `E` algebraic over `K(t)` with `t` a logarithm or an exponential. In
the simple radical case the problem decouples into a rational integration problem and a family of
Risch differential equations over `K(t)`. In general the polynomial part is replaced by Puiseux
expansions at infinity (and at `t = 0` in the exponential case), and the tutorial says twice that
"the details are quite technical" and defers to Bronstein's 1990 paper and Risch's 1968 and 1969
reports. Solving the Risch differential equation when the base field is itself an algebraic curve is
the subject of the preface's reference [14] **[held]**
(`bronstein1991_risch_differential_equation_algebraic_curve.pdf`). Its introduction states the
position in 1991: the published algorithms for algebraic `f` and `g` "require computing with the
local series expansions of f and g at their poles", and "no implementation of an algorithm that
solves equation (R) over an algebraic curve has been reported". The paper's algorithm "uses only
rational operations" and "has been implemented in the Maple and Scratchpad computer algebra
systems".

The 1990 paper **[held]** says what was still unsatisfactory, and so what a book written after it
would have had to face. From its conclusions:

- "Implementing the algorithms presented here clearly requires the prior implementation of the
  algorithms of Trager (1984)", with a footnote that such an implementation had recently been
  completed in Scratchpad II — the code of §4.3.
- Puiseux expansions are still needed for Risch's equation, and "this remains the major obstacle to
  an efficient implementation of a complete algorithm."
- "Completing this work requires finding an entirely rational algorithm", with three named
  obstacles, the third being "a rational algorithm for solving the Risch equation". The ISSAC'91
  paper [14] answers that one for algebraic curves, in its own words; that the lazy Hermite
  reduction belongs on the same list is **our inference**.

Risch's own announcement **[held]** ends its introduction with a sentence that now reads oddly
beside Volume II: "A complete account is planned for a future publication."

**Davenport's monograph is the other route to the same place** **[held]**
(`davenport1981_on_the_integration_of_algebraic_functions.pdf`), and the route Trager's replaced. Its
own outline: chapter 2 is the representation of algebraic functions, places and Puiseux expansions;
chapter 3 is Coates' algorithm, "which finds a function with poles and zeros as specified"; chapter 4
"states and proves Risch's Theorem, which … reduces the problem of integrating algebraic functions
to the torsion divisor problem"; and chapters 5–8 are that problem — the general theory, the case of
a transcendental parameter (by Gauss–Manin operators), elliptic curves over number fields, and a
torsion bound for the rest. Half the book is the points-of-finite-order problem of §2.6. Of its
implementation it says: "The most important remark is that the program deals only with square
roots".

Davenport, Siret & Tournier §5.1.7 **[held]** gives the history in a paragraph: Davenport's 1981
algorithm handled algebraic functions over ℚ(x); a 1984 theorem of his allowed transcendental
extensions *on top of* an algebraic one (the paper is **[held]**,
`davenport1984_integration_algorithmique_courbe_algebrique.pdf`: it works over `K(x, y, θ₁, …, θₙ)`
with `y` algebraic over `K(x)`, and says of the general problem that it "me semble être non
résolu"); and algebraic extensions that depend on logarithms or
exponentials were "unsolved when the first edition of this book was published, but ha[ve] now been
solved by Bronstein [1990]".

### 2.9 What Volume I leaves open on its own account

**[held]** §6.6, *The Cancellation Cases*, on solving the Risch differential equation when
cancellation leads to an equation "in a nonconstant algebraic extension of `k(t)`": "no algorithms
are known for such curves when `t` is a nonlinear monomial. Although the techniques of [11, 73] are
probably generalizable to such curves, they would not yield a practical algorithm in their current
form." Whether Volume II would have closed this is unknowable; it is the one place Volume I says
outright that the algebraic machinery is needed and missing.

### 2.10 What Volume I already supplies

Not everything algebraic was deferred. **[held]** §3.2, *Differential Extensions*, proves that a
derivation extends uniquely to a separable algebraic extension, that it commutes with conjugation,
and what that implies for the trace; and the proof of Liouville's theorem in §5.5 carries a case for
`t` algebraic over `K`. Volume II would have started from these.

---

## 3. The nine references the book sends the reader to

Resolved **[held]** against the reference list of `bronstein2005_symbolic_integration_1.pdf`
(pp. 317–321). Citations are as the book prints them. The *role* column is from the tutorial
**[held]** where it says so, otherwise **[memory]**, marked.

| # | Citation, as printed | Role | Held? |
| :--- | :--- | :--- | :--- |
| 8 | L. Bertrand. *Calcul Symbolique des Intégrales Hyperelliptiques.* Thèse de doctorat, Université de Limoges, Mathématiques, 1995. | The hyperelliptic case in full. **[memory]** | No |
| 9 | L. Bertrand. Computing a hyperelliptic integral using arithmetic in the jacobian of the curve. *AAECC* 6:275–298, 1995. | "a simpler representation of divisors for which the arithmetic and principality tests are more efficient than the general methods" — tutorial §2.5. Its own abstract: it "combines B.M. Trager's integration algorithm and a technique for computing in the Jacobian of a hyperelliptic curve introduced by D. G. Cantor", and was "implemented and successfully compared to Trager's general algorithm" | **Yes** |
| 11 | M. Bronstein. On the integration of elementary functions. *J. Symbolic Computation* 9(2):117–173, February 1990. | The mixed algebraic–transcendental case. Its abstract: "We extend a recent algorithm of Trager to a decision procedure for the indefinite integration of elementary functions." A revision of his 1987 Berkeley dissertation | **Yes** |
| 14 | M. Bronstein. The Risch differential equation on an algebraic curve. In *Proceedings of ISSAC'91*, pp. 241–246. ACM Press, 1991. | "a new rational algorithm for solving Risch differential equations over algebraic curves" (abstract) — the third obstacle the 1990 paper names. In the mixed case it "finds the denominator of any solution" only | **Yes** |
| 29 | J.H. Davenport. *On the integration of algebraic functions.* Lecture Notes in Computer Science 102. Springer, Heidelberg, 1981. | **A monograph, not a paper**: Puiseux expansions, Coates' algorithm for a function with prescribed zeros and poles, Risch's theorem, and four chapters on the torsion-divisor problem. Implemented for square roots only | **Yes** |
| 73 | R. Risch. On the integration of elementary functions which are built up using algebraic operations. Research Report SP-2801/002/00, System Development Corporation, Santa Monica, 1968. | Risch's algebraic case; an unpublished report | No |
| 74 | R. Risch. Further results on elementary functions. Research Report RC-2402, IBM Research, Yorktown Heights, 1969. | Continuation of [73]; an unpublished report | No |
| 76 | R. Risch. The solution of problem of integration in finite terms. *Bulletin of the AMS* 76:605–608, 1970. | The four-page announcement of the complete result, algebraic case included; no proofs | **Yes** |
| 91 | B.M. Trager. *On the integration of algebraic functions.* PhD thesis, MIT, Computer Science, 1984. | **The core algorithm.** Integral bases, Hermite reduction, normality at infinity, the logarithmic part, absolute factorisation — everything in tutorial §2 that is not Bronstein's own. The thesis's own title page reads *Integration of Algebraic Functions*, without "On the", and is dated September 1984 | **Yes** |

Of Risch's reports the book's own introduction says they were "unfortunately not all of them
published". That is the real sense in which the algebraic case was hard to get at in 1997: two of
the nine are corporate research reports and two are theses.

A neighbouring entry the preface does not list but which belongs with these: [90], B.M. Trager,
"Integration of simple radical extensions", *Proceedings of EUROSAM'79*, LNCS 72, pp. 408–414. The
book prints its year as 1984; the Axiom bibliography **[held]** (`Trag79`) gives 1979, which matches
the conference. It is now held (§4.1).

---

## 4. Where the material lives

### 4.1 Held, in this directory

| File | What it gives you |
| :--- | :--- |
| `bronstein1998_symbolic_integration_tutorial.pdf` | **Start here.** Bronstein's *Symbolic Integration Tutorial*, 35 pp. Sections 2 and 3.8–3.9 are the closest thing to a Volume II outline that exists in his own words. Statements and worked examples; proofs are deferred to the references. |
| `trager1984_integration_of_algebraic_functions.pdf` | **The algorithm.** Trager's MIT thesis, 83 leaves; chapter list in §2. **Image-only scan** — grep the `.txt` OCR sidecar beside it, and read formulas from the page images. |
| `davenport1981_on_the_integration_of_algebraic_functions.pdf` | Davenport's monograph, LNCS 102, 199 pp. The Puiseux-expansion route that Trager's "rational" algorithm superseded, but the longest treatment held of the torsion-divisor problem (chs. 5–8), and the only one with timings and worked REDUCE examples. Scanned; the OCR text layer is good, with some letter-spaced runs and a garbled contents page. |
| `bronstein1990_integration_of_elementary_functions.pdf` | **The mixed case.** *JSC* 9(2):117–173, 57 pp. Extends Trager to towers with logarithms and exponentials; its conclusions list what remained open. The text layer is publisher OCR with errors in names and formulas. |
| `bronstein1998_lazy_hermite_reduction.pdf` | INRIA RR-3562, November 1998: 13 pages by its own cover, 17 in the HAL file with HAL's cover sheet and the front matter. The proofs the tutorial omits. **The embedded text layer is unreadable** past the cover sheet — grep the `.txt` OCR sidecar. |
| `risch1970_solution_of_integration_in_finite_terms.pdf` | *Bulletin of the AMS* 76:605–608, 4 pp. The announcement: Liouville's theorem, the induction on monomials, and the reduction to bounding torsion on a Jacobian. A sketch, not an algorithm. |
| `bronstein1991_risch_differential_equation_algebraic_curve.pdf` | ISSAC'91, 6 pp. A rational algorithm for the Risch differential equation over an algebraic curve. Two-column text layer, interleaved: single words grep, phrases do not. |
| `bertrand1995_hyperelliptic_integral_jacobian.pdf` | *AAECC* 6:275–298, 24 pp. The hyperelliptic case done efficiently, by Cantor's Jacobian arithmetic. The paper to read if square roots are the first target. |
| `vanhoeij1994_integral_basis_algebraic_function_field.pdf` | *JSC* 18:353–363, 11 pp. Integral bases by Puiseux expansions, the alternative to Trager's method. **Image-only**; OCR sidecar beside it. |
| `trager1979_integration_of_simple_radical_extensions.pdf` | EUROSAM'79, 7 pp. "How Risch's earlier techniques can be generalized to deal with unnested radicals" — the simple radical case, five years before the thesis. Noisy OCR text layer. |
| `davenport1979_algorithms_integration_algebraic_functions.pdf` | EUROSAM'79, 11 pp. The conference precursor of the 1981 monograph. Its title is "Algorithms for the Integration of Algebraic Functions"; Blake's reference list drops the first two words. |
| `davenport1984_integration_algorithmique_courbe_algebrique.pdf` | *Annales de l'Institut Fourier* 34(2):271–276, in French. Transcendental extensions over one algebraic curve — the step between Davenport 1981 and Bronstein 1990. |
| `chevalley1951_algebraic_functions_of_one_variable.pdf` | **The background the 1990 paper assumes.** Ch. I *Places and Divisors*, ch. II *The Theorem of Riemann-Roch*. Its introduction sets out the algebraic, field-theoretic point of view it takes; only the introduction and contents were read. |
| `bliss1933_algebraic_functions.pdf` | The classical, function-theoretic treatment. Ch. III, which Risch cites for testing principality, covers divisors, their multiples and "Rational functions with prescribed poles". Image-only; text sidecar beside it. |
| `stichtenoth2009_algebraic_function_fields_and_codes.pdf` | The modern textbook, 2nd ed. Probably the easiest of the three background books to learn from (**[memory]**; only its front matter was read). |
| `fricas_wiki_risch_implementation_status_2022_wayback.html` | **What is actually implemented**, from the project that inherited Bronstein's code. See §4.3. |
| `miller2012_integration_logarithmic_part.pdf` | Texas Tech dissertation, 49 pp. A Gröbner-basis algorithm for the logarithmic part, first for algebraic functions, then for "a function lying in a transcendental elementary extension". |
| `hess2002_computing_riemann_roch_spaces.pdf` | *JSC* 33:425–445. Riemann–Roch spaces and divisor class group computation "without … any series expansions" — a modern way to do the divisor arithmetic of §2.6. |
| `combot2021_elementary_integration_superelliptic.pdf` | ISSAC '21, 8 pp. The elementary-integration problem for `∫ P/(Q·S^{1/k}) dx`, solved generically with a complexity bound. The most recent algorithmic paper held. |
| `masser_zannier2020_torsion_points_pell_integration.pdf` | *Acta Mathematica* 225, 87 pp. When members of a family of algebraic integrals are elementary; shows a 1981 conjecture of Davenport's "is false" and proves a modified one. Number theory, not an algorithm. |
| `fulton2008_algebraic_curves.pdf` | The gentlest of the background books, in the author's free 2008 edition. Davenport's monograph cites its 1969 edition. |
| `chen_vanhoeij_kauers2016_telescoping_fuchsian_dfinite.pdf` | arXiv:1611.07421. Trager's Hermite reduction carried from algebraic to fuchsian D-finite functions. Peripheral. |
| `weil1948_sur_les_courbes_algebriques_retranscription.pdf` | Weil's proof of the Riemann hypothesis for curves over finite fields, in a 2022 LaTeX retranscription. Part II §IV is the source of the torsion bound in §2.6. |
| `weil1948_varietes_abeliennes_et_courbes_algebriques.pdf` | Weil's 1948 book — **not** the 1971 volume the tutorial cites for the torsion bound, and the bound does not appear to be in it (searched via its French OCR sidecar). Image-only, 132 MB. |
| `hardy1916_integration_of_functions_of_a_single_variable.pdf` | The classical theory, and the conjecture: "there is reason to suppose that no such method can be given". Second edition (1916) in a 1966 reprint, 84 scanned pages. |
| `abramov2006_in_memory_of_manuel_bronstein.pdf` | The obituary; §1 rests on it. Also a compact account of Bronstein's work from a collaborator. |
| `kauers2008_algebraic_integration_logarithmic_part.pdf` | Kauers, ISSAC 2008, 8 pp. A Gröbner-basis heuristic for the logarithmic part — not a decision procedure, by its own abstract, but "easy to implement". Its introduction is also the plainest statement of the state of practice: "all of today's computer algebra systems only contain a partial implementation of the complete algorithm." |
| `chen_kauers_koutschan2016_reduction_telescoping_algebraic.pdf` | Chen, Kauers & Koutschan, arXiv:1602.00424v1, 8 pp. Trager's Hermite reduction plus a polynomial reduction, used for creative telescoping. A modern, compact restatement of the reduction half of the algorithm. |
| `chen_du_kauers2021_lazy_hermite_reduction.pdf` | Chen, Du & Kauers, arXiv:2102.06538v2, 20 pp. Sharpens Bronstein's lazy Hermite reduction. The lazy reduction a generation on, combined with a polynomial reduction; read it after Bronstein's own report. |
| `blake2020_pseudo_elliptic_integrals.pdf` | Blake, arXiv:2004.04910v3, 12 pp. A substitution-based heuristic for pseudo-elliptic integrals, "less than 200 lines of Mathematica code"; author-reported to solve 73.4% of the integrals solved by the best implementation of the full algorithm in randomised tests. Not a decision procedure. |
| `abramov_bronstein_petkovsek2020_pi_sigma_difference_equations.pdf` | Held for one fact: the date of Bronstein's death. Its subject (difference equations in ΠΣ*-fields) is not integration. |

### 4.2 Held elsewhere in the corpus

| Where | What it gives you |
| :--- | :--- |
| `../papers/textbooks/axiom_bookvol10-1_algebra_theory.pamphlet`, chapter *Integration* (lines 1615–3394) | **The same tutorial, as LaTeX source** — greppable, with every formula as TeX. The chapter opens by citing `Bro98b`, which `axiom_bookvolbib.pamphlet` resolves to Bronstein's *Symbolic Integration Tutorial*; its section titles match the PDF's one for one. The pamphlet does not say in so many words that the chapter is a transcription, and it carries transcription errors, two of which change the meaning — "more expansive" for the PDF's "more expensive", and "absolutely reducible" for "absolutely irreducible" — so **quote the PDF and grep the pamphlet**. |
| `../papers/textbooks/axiom_bookvol10-4_packages.pamphlet` and `-3_domains.pamphlet` | **Bronstein's implementation.** See §4.3. |
| `../papers/textbooks/axiom_bookvolbib.pamphlet` | The Axiom bibliography: resolves the tutorial chapter's citation keys (`Trag84`, `Bron98`, `Bron90c`, `Hoei94`, `Bert95`, …), several with abstracts. |
| `../papers/textbooks/geddes_czapor_labahn1992_algorithms_for_computer_algebra.pdf`, §12.8 *Integration of Algebraic Functions* | A textbook summary of Trager's algorithm with worked square-root examples. By its own account "little more than a summary". The only textbook-form account held. |
| `../papers/textbooks/davenport_siret_tournier1993_computer_algebra_2nd_ed.pdf`, §5.1.7 *Integration of algebraic functions* | One page: who solved what, and when. No algorithm. |
| `../papers/textbooks/bronstein2005_symbolic_integration_1.pdf`, §3.2, §5.2, §5.5, §6.6 | The groundwork and the stated gaps; see §2.9–§2.10 above. |

### 4.3 The code: Bronstein's algebraic integrator in Axiom

**[held]** The Axiom sources carry `++ Author: Manuel Bronstein` on the packages below, dated
1987–1988 where a date is given. This is the algorithm of §2 as running code, and for an implementer
it answers questions the papers leave to the reader. Line numbers are in the held pamphlets.

| Constructor | File, line | Its own description |
| :--- | :--- | :--- |
| `INTHERAL` AlgebraicHermiteIntegration | 10.4, 1289 | "Algebraic Hermite reduction." |
| `INTALG` AlgebraicIntegrate | 10.4, 1477 | "functions for integrating a function on an algebraic curve" |
| `INTAF` AlgebraicIntegration | 10.4, 2105 | "integration of algebraic integrands over transcendental functions" — the mixed case |
| `INTPAF` PureAlgebraicIntegration | 10.4, 218106 | "Integration of pure algebraic functions" |
| `INTG0` GenusZeroIntegration | 10.4, 69727 | "Rationalization of several types of genus 0 integrands" |
| `DBLRESP` DoubleResultantPackage | 10.4, 26089 | "computing the residues of a function on an algebraic curve" — the double resultant of §2.6 |
| `PFO` PointsOfFiniteOrder | 10.4, 205031 | "testing whether a divisor on a curve is a torsion divisor" |
| `PFOQ` PointsOfFiniteOrderRational | 10.4, 205634 | The same description as `PFO`; the rational case, by its name |
| `PFOTOOLS` PointsOfFiniteOrderTools | 10.4, 205831 | "Utilities for PFOQ and PFO" |
| `FORDER` FindOrderFinite | 10.4, 49005 | "Finds the order of a divisor over a finite field" |
| `RDIV` ReducedDivisor | 10.4, 228703 | Carries the same description line as `FORDER` |
| `FFINTBAS` FunctionFieldIntegralBasis | 10.4, 58596 | "Integral bases for function fields of dimension one" |
| `WFFINTBS` WildFunctionFieldIntegralBasis | 10.4, 260070 | Over a finite field: "the integral closure of R in the quotient field of F" and a "local integral basis" at a prime |
| `ALGFF` AlgebraicFunctionField | 10.3, 3199 | "Function field defined by f(x, y) = 0." |
| `RADFF` RadicalFunctionField | 10.3, 166027 | "Function field defined by y**n = f(x)" |
| `FDIV` FiniteDivisor | 10.3, 63748 | Finite rational divisors on a curve |
| `HELLFDIV` HyperellipticFiniteDivisor | 10.3, 90874 | The same on a hyperelliptic curve |

The split into `RADFF` and `ALGFF`, and into `FDIV` and `HELLFDIV`, is the tutorial's distinction
between simple radical extensions and the general case, as types.

**How much of this works today** **[held]**
(`fricas_wiki_risch_implementation_status_2022_wayback.html`, the FriCAS wiki's own status page,
last edited 2022/06/28). FriCAS is the maintained descendant of this code, and its account of the
algebraic case is blunt:

- "The core integrator should be complete for purely transcendental functions."
- When the top kernel is algebraic, "FriCAS can apply Hermite reduction. It can find the logarithmic
  part only in the purely algebraic case. Otherwise, if Hermite reduction does not already yield the
  integral, FriCAS cannot solve it."
- Even then "there are restrictions on the Trager resultant: in general FriCAS can only handle
  resultants having a single nonlinear factor".
- "The solver for the Risch differential equation can only handle the purely algebraic case. The
  logarithmic derivative problem is unimplemented in the algebraic case."
- In sum: "a large part of the Risch algorithm dealing with algebraic extensions remains
  unimplemented."

So in 2022, more than thirty years after the 1990 paper, the mixed case of §2.8 is not fully implemented in the
system its author wrote it for. That is the strongest single piece of evidence for treating the
algebraic case as a project of its own.

Vol. 10.1 also has a short chapter, *Package for Algebraic Function Fields* (line 9862), on Gaétan
Haché's PAFF. It is a different codebase — Brill–Noether, written for algebraic-geometry codes — and
recommends Stichtenoth's *Algebraic Function Fields and Codes* as "a very good introduction to this
theory". Useful for the background of §2.1, not for integration.

### 4.4 Cited in a held document, not held

Each of these is **[cited]**: the citation is verified, the content is not.

| Work | Cited by | Why it matters |
| :--- | :--- | :--- |
| A. Weil. *Courbes algébriques et variétés abéliennes.* Hermann, Paris, 1971. | Tutorial ref. [22] | The bound behind the finite-order test. **Resolved in substance, not in edition:** the two 1948 volumes held (§4.1) carry the mathematics — the bound's source is in *Sur les courbes algébriques*, part II §IV. That the 1971 book reprints those two volumes is **[memory]**, supported by its title joining theirs, and unchecked. |
| J.H. Davenport. *Intégration formelle.* Rapport de Recherche RR375, IMAG, Grenoble, 1983. | Book ref. [32] | — |
| R. Risch. The problem of integration in finite terms. *Transactions of the AMS* 139:167–189, 1969. | Book ref. [75] | The published transcendental case; the tutorial cites it for the strong Liouville theorem |

### 4.5 From memory, unverified

**[memory]**, all of it. These are the leads worth chasing; none has been checked against a document
in this session, and any detail — a year, a venue, a claim about content — may be wrong.

- **Raab**, *Definite Integration in Differential Fields* (PhD thesis, RISC Linz, 2012): the most
  recent thesis-length survey of the Risch machinery, with remarks on the algebraic case. The only
  lead from this list's first version still not held; the others are in §4.1.
- **Implementations other than FriCAS** (for FriCAS see §4.3, which is **[held]**). Maple implements
  Trager's algorithm for algebraic integrands — van Hoeij's abstract **[held]** confirms that
  Trager's integral-basis method is the one "used by Maple 5.2 and AXIOM", which is less than the
  whole claim. Reduce has Davenport's `ALGINT`, limited to square roots — consistent with his
  monograph **[held]**, which describes a REDUCE-2 implementation for square roots only. SymPy's
  Risch code covers the transcendental case only.
- A retyped PDF of **Trager's thesis** has circulated from Patrizia Gianni's pages at Pisa, which is
  the link the Axiom bibliography gives for `Trag84`. The held copy is MIT's scan of the original.

---

## 5. Not obtained, and what was tried

Four sources that plain `curl` did not get on 2026-11-11 **were downloaded in a browser and
supplied the same day**, and are held, as is Davenport's monograph, supplied from the project
owner's own copy: Trager's thesis (MIT DSpace had answered 429), the
lazy-Hermite report (HAL had served a bot challenge), Bronstein's 1990 paper (the DOI was followed
only as far as Elsevier's linking hub) and Risch's 1970 announcement (never tried by `curl`). What
remains:

| Source | Route tried | Result |
| :--- | :--- | :--- |
| Bertrand's thesis [8] | Not attempted | His paper [9], held, covers the subject. |
| Risch's 1968 and 1969 reports [73], [74] | Not attempted | Corporate research reports; the book's introduction says of Risch's reports "unfortunately not all of them published". |

None of these blocks anything. [`missing-resources.md`](./missing-resources.md) has the full list
of what is cited and not held.

---

## 6. If this were ever built — a reading order

**Our inference**, for orientation only. `DESIGN.md` §6.2 holds the decision, which is that the
algebraic case is out of scope.

1. The tutorial, §2, with Geddes §12.8 alongside for a second telling of the same algorithm.
2. Trager's thesis, chs. 2 and 4–6; ch. 3 (absolute irreducibility) when it is needed.
3. Bronstein's RR-3562 for the lazy Hermite reduction, then Chen, Du & Kauers.
3a. Bronstein 1990 only once the pure algebraic case works — its own conclusion is that it "clearly
   requires the prior implementation of the algorithms of Trager (1984)".
4. The Axiom sources of §4.3, read as a worked answer: `RADFF` and `INTHERAL` first.
5. Kauers 2008 and Blake 2020, for what a heuristic gets without the divisor machinery.

The dependency chain an implementation would need, read off the tutorial's preconditions: integral
bases in a function field; Puiseux expansions; absolute factorisation; fractional-ideal arithmetic
for divisors; function fields over finite fields for the finite-order test. The simple radical case
(§2.4) needs only the first, in closed form, and decouples into problems Volume I already solves —
it is the one rung of this ladder that does not require the algebraic geometry.
