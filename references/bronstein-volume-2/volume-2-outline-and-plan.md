# A reconstructed Volume II: outline and plan

The goal is a typeset book, with theorems, equations and pseudocode, that covers what the second
volume of Bronstein's *Symbolic Integration* would have covered: the integration of algebraic and
mixed algebraic–transcendental functions. This file is the outline of that book and the plan for
writing it. [`what-volume-2-would-have-covered.md`](./what-volume-2-would-have-covered.md) is the
evidence it rests on, cited below as *WV2*.

Written 2026-11-13, and revised the same day when Raab & Singer's 2022 volume was supplied: it
holds Risch's 1968 report in revised form and Trager's thesis typeset, which changes the sources of
chs. 14–15 and removes the worst of the reading risk in §5. Phase 0 was done the same day: the
skeleton is in [`../../book/`](../../book/CLAUDE.md) and compiles. Phase 1, chapter 7, was drafted
the same day. The project owner then waived the reading gate, and phase 2 (chs. 6, 8, 9, 12) was
drafted on 2026-11-14, phases 3 (chs. 1–5) and 4 (chs. 10–11) after it the same day, and phase 5
(chs. 13–16) and phase 6 on 2026-11-15. The book is complete in first draft, 150 pages, and has not
been read by the owner.

## 1. What this book is, and is not

- **It is not Bronstein's book and must not look like it.** No manuscript, outline or table of
  contents of Volume II is known (*WV2* §1). The title page carries its real author and the word
  *reconstruction*, and the preface says what *WV2* §1 says. Working title: *Integration of
  Algebraic Functions: a reconstruction of the unwritten second volume of "Symbolic Integration"*.
- **It is a companion to Volume I**, written to be read after it: same notation (`k`, `t`, `D`,
  `Const`, monomial extensions, the order function `ν_P`), same shape of chapter (theory, then the
  algorithm as pseudocode, then a worked example, then exercises), and it cites Volume I by section
  for everything Volume I already proves (*WV2* §2.10).
- **It is assembled from the literature, not from new research.** Where the sources contain a
  complete algorithm, the book gives it with a proof or a located citation. Where they contain a
  sketch, the book says so. Where the problem is open (*WV2* §2.9; the FriCAS list in *WV2* §4.3),
  the book states it as open. It does not invent algorithms to fill a gap.

## 2. Review of *WV2*: what the outline takes from it and where it falls short

*WV2* is sound as a record of sources, and its §2 is a good skeleton for the pure algebraic case.
Read as a book outline it has five gaps. The outline in §3 closes each.

| # | Gap in *WV2* §2 | Why it matters | Where the outline puts it |
| :--- | :--- | :--- | :--- |
| 1 | It follows the tutorial's section list, and never asks what **Volume I's own chapter list** implies. Volume I has chapters on parametric problems (7), the coupled system (8) and structure theorems (9); each has an algebraic counterpart. The parametric logarithmic derivative problem appears in *WV2* only inside a FriCAS quotation. | These are what the mixed case calls as subroutines. A book that mirrors Volume I has to say what is known for each. | Ch. 16 |
| 2 | **Genus zero** appears only as a row of the code table (`INTG0`). | It is the case most integrands in practice fall into, and it needs none of the divisor machinery: a rational parametrisation reduces it to Volume I. | Ch. 11 |
| 3 | **The constant field** is reduced to the two words "absolute factorisation". Residues live in an algebraic extension of the constants; the curve must be geometrically irreducible; a transcendental parameter in the constants changes the torsion problem (Davenport chs. 6; Masser & Zannier). | Trager gives it a chapter. It is where a correct-looking implementation is wrong. | Chs. 4 and 10 |
| 4 | **The classical theory** (Abel, Liouville, Chebyshev, Hardy's conjecture) is held, in Hardy, and unused. | Volume I opens with it; so should this. It also supplies the standard test integrals. | Ch. 6 |
| 5 | **Post-2005 work** is listed in §4.1 as sources and not placed in the reconstruction: the polynomial reduction of Chen, Kauers & Koutschan, Hess's Riemann–Roch algorithm, the Gröbner-basis logarithmic part of Kauers and of Miller, Combot. | "Best version" means the book may use what Bronstein could not have. Each must be marked as later than 2005. | Chs. 5, 7, 9, 12 |

Three smaller defects in *WV2* itself were corrected on 2026-11-13, in the change that added this
file: a header that said "four" sources and named five; a reading-order item numbered "3a"; and a
torsion bound in §2.6 that used `q` without saying it is the exponent of the field size `p^q`,
beside a quotation from Weil in which `q` is the field size itself. The tutorial's sentence was
re-read for the last one (its §2.5, the paragraph citing [22]).

## 3. Outline

Seventeen chapters in three parts, and four appendices. For each chapter: its contents, the source
it is written from, and its **standing**, one of

- **A** — a complete account exists in a held source; the work is exposition and unification of notation;
- **B** — held sources give statements or sketches; proofs or details have to be supplied or located;
- **C** — partly open, or dependent on a source not held; the chapter states its own limits.

Post-2005 material is marked †.

### Front matter

Preface (what this is; *WV2* §1 in a page). Notation and conventions carried over from Volume I. A
chapter dependency chart. A reader who wants only square roots can read 1–3, 6–9 in the simple
radical case, 12, and then 10: without the finite-order test of ch. 10 no integral on a curve of
positive genus can be declared non-elementary, square roots included.

### Part I — Algebraic functions

**1. Algebraic preliminaries.** Integral elements and integral closure; finitely generated modules
over `K[x]` and the Hermite normal form; trace, norm, discriminant; resultants in two variables;
algebraic extensions of the constant field and arithmetic in them; primitive elements. The
counterpart of Volume I ch. 1. *Sources:* Trager ch. 2; Stichtenoth; Volume I §1.4–§1.5. **A.**

**2. Algebraic function fields.** `E = K(x)[y]/(F)`; places and valuations; ramification; Puiseux
expansions; divisors and principal divisors; the Riemann–Roch theorem (stated, with a located
proof); genus; differentials and their residues; the residue theorem. The preface's stated
prerequisite, kept to what later chapters use. *Sources:* Chevalley chs. I–II; Stichtenoth chs. 1,
3, 4; Fulton for the geometric picture; Bliss ch. III. **A.**

**3. Integral bases.** Definition and why a mere basis of integral elements is not enough (the
tutorial's Example 1). Trager's algorithm: the radical of the discriminant, the idealizer, the
iteration. van Hoeij's algorithm by Puiseux expansions. Local bases. Integrality at infinity and
bases normal at infinity. Reading the genus off a normal integral basis. *Sources:* Trager §2.1–§2.4;
van Hoeij 1994; tutorial §2, §2.4; Axiom `FFINTBAS`, `WFFINTBS`; Zassenhaus 1972 and Ford 1978 ch. II for the
number-field original; de Jong 1998 and Gianni & Trager 1997 for the general criterion; Greuel et
al. 2010 † and Böhm et al. 2013 † as pointers. **A.**

**4. The constant field and absolute irreducibility.** Exact constant fields and regular
extensions; why the integration algorithm needs `F` absolutely irreducible; absolute factorisation;
binomial polynomials `yⁿ − a`. *Sources:* Trager ch. 3; Kaltofen 1985; Duval 1991; Chèze & Lecerf 2007 †. **B** —
Trager's chapter is the account the integrator uses; the later papers are pointers to better methods.

**5. Divisors and their arithmetic.** Divisors as pairs of fractional ideals (finite and infinite
parts); sum, multiple, and reduction; computing `L(D)`; testing principality and producing the
generator. Coates' algorithm as the Puiseux-series alternative. Hess's algorithm †. Hyperelliptic
curves: Mumford representation and Cantor's arithmetic. *Sources:* Trager §5.3, §6.1, §6.3;
Davenport ch. 3; Coates 1970; Volcheck 1994; Hess 2002; Bertrand 1995; Cantor 1987; Axiom `FDIV`, `HELLFDIV`, `RDIV`. **B.**

### Part II — Integration of algebraic functions

**6. The problem and Liouville's theorem.** The classical theory: Abel, Liouville, Chebyshev,
Hardy's conjecture that no method exists. Derivations on a function field (Volume I §3.2);
differentials of the first, second and third kind. Liouville's theorem for algebraic functions, and
its strong form. The shape of the answer: `∫f = v + Σ cᵢ log uᵢ`. Outline of the algorithm of chs.
7–10. *Sources:* Hardy ch. V; Lützen 1990 ch. IX for the history; Risch 1970; tutorial §2.3;
Volume I §5.5; Trager §5.1. **A.**

**7. The Hermite reduction.** The canonical form `(A₁w₁ + … + Aₙwₙ)/D`. The reduction step as a
linear system; Trager's theorem that over an integral basis it is uniquely solvable. Failure over a
non-integral basis. The lazy Hermite reduction: Theorems 1–3 of the tutorial with the report's
proofs, **proved here once, over a monomial extension `k(t)`**, with Trager's theorem as their
corollary (settled 2026-11-13; ch. 13 cites it). The tutorial's Theorems 1, 2, 3 are the report's
Theorem 2, Theorem 3 and §3; the report's Theorem 1 is the reduction step itself. The polynomial reduction and additive decomposition †. *Sources:* Trager §4.2; tutorial
§2.1; Bronstein RR-3562; Chen, Kauers & Koutschan 2016; Chen, Du & Kauers 2021; Axiom `INTHERAL`.
**A.** *This is the prototype chapter (§5).*

**8. The algebraic part.** After Hermite reduction `v` is integral. Poles at infinity; the change of
variable `x = N + 1/z`; the criterion "`hz²` has a pole at infinity ⟹ not elementary". In-field
integration: deciding whether `∫f ∈ E`. *Sources:* Trager §4.3; tutorial §2.4. **A.**

**9. The logarithmic part.** Properties of logarithmic differentials. Residues and the double
resultant; a ℚ-basis of the residues; constructing the divisors `δⱼ`; branch places. The reduction:
`∫h` is elementary iff a multiple of each `δⱼ` is principal. The Gröbner-basis formulations †.
*Sources:* Trager ch. 5; tutorial §2.5; Axiom `DBLRESP`, `INTALG`; Kauers 2008; Miller 2012 ch. on
the algebraic case. **A** for Trager's algorithm, **B** for the comparison.

**10. Points of finite order.** The problem: is some multiple of a degree-zero divisor principal?
Why it does not arise for rational functions. Good reduction; injectivity of torsion under
reduction; the Hasse–Weil bound and the two-primes argument; Trager's computation of the exact
order. Function fields over finite fields. Constants with transcendental parameters: Davenport's
method, and the Masser–Zannier result as a boundary marker. Elliptic curves. *Sources:* Trager ch.
6; Risch 1970; Davenport chs. 5–8; Weil 1948 part II §IV; Katz 1981, appendix, for injectivity of
reduction on torsion; Deuring 1941 for reduction of a function field, of a prime and of a parameter alike; Serre & Tate
1968 and Shimura & Taniyama 1961 for good reduction of the Jacobian; Zannier
2014 and Masser & Zannier 2020 for the parameter case; Axiom `PFO`, `PFOQ`, `FORDER`. **B** — the
good-reduction theorems are cited, not proved (Katz's two-page lemma may be short enough to
include); the parameter case is **C**.

**11. Genus zero.** Recognising genus 0; rational parametrisation; Euler's substitutions as the
conic case; reduction to Volume I ch. 2. The three integrable cases of the binomial differential
`xᵖ(a + bxʳ)^q dx` as examples (the theorem itself is in ch. 12). *Sources:*
van Hoeij 1997 for parametrisation through `L(D)` and an integral basis; Chebyshev 1853; Axiom
`INTG0`; Hardy; Sendra, Winkler & Pérez-Díaz 2008 chs. 3–5 for the adjoint-curve route and the
field of parametrisation. **B** — van Hoeij's paper fits the book's machinery; the book-length
treatment works by adjoints, so it is a cross-check and a source of examples, not the exposition.

**12. Radical extensions.** `yⁿ = a`: the closed-form integral basis, already normal at infinity;
the diagonal Hermite system. Trager's 1979 generalised Risch algorithm for unnested radicals.
Hyperelliptic integrals by Jacobian arithmetic. Chebyshev's theorem on `∫xᵖ(a + bxʳ)^q dx`: in the
integrable cases a substitution leads to genus zero (ch. 11), but its content is that the others are not elementary,
which is a statement about a simple radical extension and needs chs. 9–10. The theorem is in the
held 1853 paper, §VIII (checked 2026-11-14); the book cites it and does not reproduce the proof. Superelliptic integrals †. Pseudo-elliptic
integrals and what heuristics recover †, including Blake's 2026 preprints on the Risch–Norman
method over a radical extension †. *Sources:* tutorial §2.2; Trager §2.5 and Appendix A;
Trager 1979; Bertrand 1995; Chebyshev 1853; Combot 2021; Blake 2020; Axiom `RADFF`. **A** for the
integral basis, the diagonal system, Trager 1979 and Bertrand; **B** for Chebyshev's theorem and
for the † sections, whose sources (Combot, Blake's three papers) have been read in abstract only.

### Part III — Mixed algebraic–transcendental functions

**13. Algebraic extensions of monomial extensions.** `E` algebraic over `k(t)`, `t` a monomial over
a differential field `k`. Places over normal and special polynomials; the order function on `E`;
the lazy Hermite reduction in this setting, by citation of ch. 7, which proves it there; Liouville's theorem
and the residue criterion over a curve. The counterpart of Volume I chs. 3–4. *Sources:* Bronstein
1990 Part 1; RR-3562; Volume I chs. 3–5; Bronstein's AAECC paper of 1990 for monomial extensions
with algebraic steps. **B.**

**14. Integration of elementary functions.** The algebraic logarithmic case and the algebraic
exponential case. The simple radical case, where the problem decouples into a rational integration
and a family of Risch differential equations over `k(t)`. The general case through expansions at
infinity (and at `t = 0`). Davenport's 1984 case — transcendentals over one curve — as an
instructive special case. *Sources:* Bronstein 1990 Part 2; tutorial §3.8–§3.9; Davenport 1984;
Axiom `INTAF`, `INTPAF`. **B** — the tutorial says twice that "the details are quite technical";
the 1990 paper has them, in a text layer whose formulas are noise. Risch's own treatment, by
Puiseux expansions, is in Raab & Singer pp. 203–220.

**15. The Risch differential equation on a curve.** `y′ + fy = g` over `E`. Risch's method through
local expansions. Bronstein's rational algorithm: bounding the denominator, then the degree. Its
limits: in the mixed case it finds the denominator only. The cancellation case over a nonlinear
monomial, which Volume I §6.6 leaves open. *Sources:* Risch 1968 as revised in Raab & Singer;
Bronstein 1990 Part 3; Bronstein 1991; Volume I ch. 6. **B**, with the nonlinear cancellation case
**C** because it is open. Risch's 1969 report is held only in the parts the revision absorbed.

**16. Parametric problems and structure theorems.** The algebraic counterparts of Volume I chs.
7–9: the parametric Risch equation, limited integration and the parametric logarithmic derivative
problem over a curve; deciding whether a new logarithm or exponential is algebraic over the tower
(the Risch and Rothstein–Caviness structure theorems, Volume I ch. 9, which already allow algebraic
elements). *Sources:* Volume I chs. 7, 9; Bronstein 1990; the FriCAS status page for what has never
been implemented; Raab's thesis for the parametric problems over transcendental towers, which is
as far as it goes. **C** — no source for these problems over a curve has been found; the thinnest chapter; expected to be short and largely a statement of
what is and is not known.

**17. Implementations and open problems.** The architecture of Bronstein's Axiom integrator as a
reading of chs. 3–15; what FriCAS does and does not implement; Maple and Reduce to the extent a held
source supports it. The open problems, collected: a fully rational algorithm for the mixed case, the
nonlinear cancellation case, the logarithmic derivative problem over a curve. *Sources:* *WV2*
§4.3; Bronstein 1990 Conclusions; Kauers 2008 introduction. **A.**

### Appendices

- **A. Test integrals.** Every worked example in the book and the classical ones, each with its
  answer or its proof of non-elementarity, in machine-readable form.
- **B. From chapter to code.** The Axiom constructors of *WV2* §4.3 against the sections that
  explain them.
- **C. Notation concordance.** Trager, Davenport, Bronstein 1990, the tutorial and Volume I use
  different letters for the same objects; one table.
- **D. Sources and standing.** For each theorem and algorithm: proved here, or proved in a named
  source at a named place, or stated without proof. The book's version of *WV2*'s tags.

**Size.** Volume I is about 325 pages. Estimate for this: Part I 110, Part II 150, Part III 90,
appendices 30 — roughly 380 pages. The estimate is soft for Part III. *As drafted by 2026-11-14:*
Part I is 26 pages and chs. 6–9 and 12 are 50, between a quarter and a half of the estimate for
what they cover.
The chapters cite proofs where the estimate assumed they would be reproduced.

## 4. Conventions for the text

- **Typesetting.** LaTeX, built with `lualatex` (it needs `texlive-luatex` for `luaotfload`,
  installed 2026-11-13; `latexmk` is not installed, so a small build script runs the passes).
  `book` class, `amsthm`, `algpseudocode` — all present. Pseudocode follows
  Volume I's conventions: a named algorithm with a one-line specification of input and output, then
  the body, with `(* … *)` comments. One file per chapter.
- **Every algorithm is followed by a worked example that exercises it**, traced step by step, as in
  Volume I. Where the tutorial has an example it is reused and extended; `∫ x dx/√(1 − x³)` and
  `∫ dx/(x√(1 − x³))` (*WV2* §2.6) run through chs. 7–10 as the running pair.
- **Every closed-form answer is checked by differentiation in a CAS before it is printed.** No CAS
  is installed locally (`fricas`, `maxima`, `sage`, `gp`: none found); the Wolfram evaluator
  available to the session does this. Non-elementarity claims cannot be checked this way and are
  cited or proved.
- **Every theorem has a standing** (Appendix D). A proof read from OCR is re-derived or read from
  the page image or a born-digital copy, never transcribed from an OCR layer: Trager's sidecar, the
  1990 paper and RR-3562 all have unusable formulas (`CLAUDE.md` in this directory).
- **Exercises** at the end of each chapter, as in Volume I. Lowest priority; added last.

## 5. Plan

| Phase | Work | Output | Done when |
| :--- | :--- | :--- | :--- |
| 0 | Set up the LaTeX skeleton: class, macros shared with Volume I's notation, theorem and algorithm environments, build script. | An empty book that compiles, with front matter. | `./build.sh` builds it clean. **Done 2026-11-13.** |
| 1 | **Prototype: ch. 7, the Hermite reduction.** Self-contained, best-sourced (tutorial, Trager §4.2, RR-3562), and it uses every element of the format — theorem with proof, pseudocode, a failing example, a worked example. | One finished chapter, about 20 pages. | The owner has read it and the conventions of §4 are confirmed or changed. Nothing else is written before this. **Drafted 2026-11-13, 17 pages; not yet read.** |
| 2 | **The core of Part II:** chs. 6, 8, 9, in that order, then ch. 12 for the simple radical case, which makes chs. 7–9 concrete. | A readable account of Trager's algorithm less the torsion test. | The running examples go through end to end, in this sense: ch. 9 finds a principal multiple of a divisor by trying multiples in turn, which settles `∫ dx/(x√(1 − x³))`, and `∫ x dx/√(1 − x³)` is settled without any divisor. What phase 2 cannot do is stop the search when no multiple is principal; that bound is ch. 10. **Drafted 2026-11-14: both running examples go through, and a third (`∫ dx/√(1 − x³)`) is settled in ch. 6.** |
| 3 | **Part I, back-filled.** Chs. 1–5 written to supply exactly what chs. 6–9 and 12 used, no more. Writing them first would produce a textbook on function fields that the later chapters do not need. | Part I. | Every forward reference from Part II resolves. **Drafted 2026-11-14, 26 pages against the 110 estimated: the rule held. Chs. 6–9 and 12 now cite numbered results of chs. 1–5.** |
| 4 | Chs. 10 and 11. Ch. 10 needs a close reading of Trager ch. 6 and Davenport chs. 5–8 from page images. | Part II complete. | — **Drafted 2026-11-14. Ch. 10 cites the good-reduction theorems and does not prove them; its parameter case is a summary.** |
| 5 | **Part III**, chs. 13–16 in order. Begins with a full read of Risch's revised report and of Bronstein 1990 from page images, with a notation concordance (Appendix C) made as it is read. | Part III. | Each **C** chapter states its limits explicitly. **Drafted 2026-11-15. Risch's revised report was read in full from its text; of Bronstein 1990, eighteen of 57 pages were read from page images, the ones carrying the definitions and propositions used. The notation concordance (Appendix C) was not made as the reading went and is owed to phase 6.** |
| 6 | Ch. 17, appendices, preface, index, exercises. A pass for notation consistency and a rebuild-and-recheck of every worked example. | The book. | — **Drafted 2026-11-15.** Ch. 17; appendices A–D, A with a machine-readable copy in `book/data/`; the dependency chart, as a table on the notation page; an index of algorithms and about forty-five terms; a section in ch. 9 on the Gröbner-basis methods, which the outline had placed there and phase 2 had skipped. Appendix A has thirteen entries, eight of them closed forms; those eight and the two reduction identities (T02, T04) were re-checked by differentiation in one run. The consistency pass was limited to building clean and replacing chapter-level references; it was not a line-by-line reading. **A second pass was made on 2026-11-15:** the preface and chs. 1–3, 6 and 8 were re-read in full; chs. 4, 5, 7, 9 and 12 in the parts where definitions, algorithms and cross-chapter facts sit, between a third and two thirds of each; chs. 10, 11 and 13–17 and the appendices were not re-read, and were checked only by script (every reference names the right kind of object, every numbered part cited exists and says what is claimed of it, every algorithm named is defined) and against the facts they restate from other chapters. **A third pass, the same day,** read chs. 4, 5, 7, 10, 11, 12 and 13 to the end and the first 140 lines of ch. 14, and fixed: a basis called `ν` beside the order function `ν_P` in §7.8; two meanings of `n` in one paragraph of ch. 10; a letter clash in Proposition 12.4.1 and in the residue criterion; a wrong statement in ch. 12 that the integrable binomial cases are those of genus zero (the running example is integrable on a curve of genus one); an unsupported remark on cost. **A fourth pass, 2026-11-16,** read the rest of ch. 14 and chs. 15 and 16 in full, and fixed: an undefined `b_i^{(0)}` in §14.3; two glosses on Davenport 1984 and Bronstein 1991 that went beyond what was read; `h_i` meaning two things in §15.3; a claim in ch. 16 that Volume I's treatment of the parametric problems is complete, three lines after quoting Volume I to the contrary; a claim that Bronstein 1991 covers the parametric equation, which its abstract does not say. Ch. 17 was then read in full and three assertions of our own in it were either sourced or removed. The rest of ch. 9 was read afterwards: its proof of the residue polynomial spoke of the embeddings of `E` over `K(x)` where the theorem it uses is about the algebraically closed case, and used `c` for two things; both fixed. Every chapter has now been read line by line. The appendices were not re-read: they were checked against the chapters when written, and Appendix C's row on the Hermite reduction was simplified during the second pass. It found and fixed: a letter used for two things in Theorem 7.3.1; "normal part" used in two senses in ch. 7; the definition of normality at infinity used in chs. 3 and 5 before it is given in ch. 8 (now restated in ch. 3 and noted in the dependency table); primes used for derivatives without saying so in ch. 12; `τ_i` and `τ_P` unremarked; a transposed Vandermonde product in ch. 1; ch. 9's main theorem stated without its number-field hypothesis; the letter `f` for a denominator in `ExtendBasis`, which also called for a Hermite normal form where the text had been changed to `RowReduce`; `LogarithmicPart` without its step on branch places; the letter `v` meaning two things inside the proof of Theorem 8.3.1; American spellings. |

Roughly one chapter per working session for the **A** chapters; chs. 10, 14 and 15 will take more.

**Risks.**

- *Formulas in the primary sources are images.* The 1990 paper's text layer is noise, and RR-3562's
  is unusable. Trager's thesis is no longer in this list: the typeset version in Raab & Singer has
  its formulas as text. It is a revised text, not a reprint (`CLAUDE.md` in this directory): its
  prose was compared with the scan and differs in a few places, its citation numbers all differ,
  and its formulas were compared on one page only. The book cites Trager by section, quotes the
  scan, and checks any formula it depends on against the scan's page image. Reading
  the rest is slow and transcription errors are likely; hence the rule that results are re-derived
  or machine-checked, not copied.
- *Risch's reports are held only as the 2022 revision* of the 1968 one, with parts of the 1969 one.
  Only its first two pages have been read so far; how much of ch. 15 it carries is not yet known.
  Bronstein 1990, which presents "Risch's solution of the associated equation problem" itself,
  remains the main source for Part III.
- *Chs. 15–16 may turn out to be mostly negative results.* That is an accurate picture of the
  subject, and the book says so rather than padding.
- *Scope creep in Part I.* Controlled by phase 3's rule.

## 6. Decisions, settled 2026-11-13

| # | Decision | Settled as |
| :--- | :--- | :--- |
| 1 | **Where the book's sources live.** `references/` holds source documents and their index; a 380-page LaTeX book is neither, and the root `CLAUDE.md` rule 1 names four documentation surfaces with no place for it. | A new top-level `book/` directory with its own `CLAUDE.md`, and a line in the root table. Built PDFs gitignored. |
| 2 | **Author line and title.** | The working title of §1, with the project owner as author and a preface stating that it is a reconstruction. |
| 3 | **Whether post-2005 material goes in** (†), or the book stays at what could have been written in 2005. | In, and marked. Hess, Chen–Kauers–Koutschan and Combot are improvements a reader today needs. |

The project owner accepted all three as recommended. `book/` and the root `CLAUDE.md` line were
created in phase 0.

`DESIGN.md` §6.2 keeps the algebraic case out of scope for the code. This book does not change
that, and no decision here touches `DESIGN.md`.
