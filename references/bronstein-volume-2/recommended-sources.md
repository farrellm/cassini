# Recommended sources for the remaining gaps

What to obtain so that each chapter of the reconstructed Volume II
([`volume-2-outline-and-plan.md`](./volume-2-outline-and-plan.md)) has a source to be written from.
[`missing-resources.md`](./missing-resources.md) lists what held documents cite and is not held;
this file is narrower and more opinionated: what the *book* lacks, and what to get for it.

Written 2026-11-13. **Nothing listed here is held, and none of it has been opened.**

## How far to trust each entry

| Tag | Meaning |
| :--- | :--- |
| **[cited]** | The citation was read in a held document's reference list, which is named. Reliable as a citation; says nothing about content. |
| **[web]** | A web search or a URL check on 2026-11-13 confirmed that the work exists under this citation, or that the URL answered. The document was not downloaded or read. Search-result summaries are the only basis for any remark about content. |
| **[memory]** | Recalled. Unverified. |

"R&S" is the held `raab_singer2022_…` volume; "Trager's commentary" and "Raab's commentary" are its
last and sixth chapters, and "Trager (typeset)" its seventh. Citation numbers into the thesis are
the typeset version's, which differ from the scan's.

## 1. Get these first

Five items, in order. Together they close the gaps that change what a chapter can say.

| # | Source | For | Standing and route |
| :--- | :--- | :--- | :--- |
| 1 | Daniel Schultz. *Trager's Algorithm for Integration of Algebraic Functions Revisited.* Unpublished note. | Chs. 7–10. A modern re-exposition of the whole algorithm; by a search summary it "fills in the 'gaps' in Trager's algorithm" and gives "a remedy to several of the possible points of failure". The best single check on the book's reading of Trager. | **[cited]** Trager's commentary [31]. The URL printed there (`sites.psu.edu/dpsmath/…/IntegrationOnCurves-2hhuby8.pdf`) answered **404**. **[web]** a copy with matching title and author is at `tthsqe12.github.io/algebraic_integration.pdf`; whether it is the same version is not known. |
| 2 | Clemens G. Raab. *Definite Integration in Differential Fields.* PhD thesis, Johannes Kepler Univ. Linz, 2012. | Ch. 16, and the parametric side of chs. 13–15. The one modern thesis on parametric elementary integration; by a search summary it also generalises Czichowski's algorithm for the logarithmic part. | **[cited]** Raab's commentary [Raa12a], which prints `www.risc.jku.at/publications/download/risc_4583/PhD_CGR.pdf`. **[web]** that URL answered 200 with a 1.2 MB PDF. `missing-resources.md` recorded a different path (`risc_4597`) as dead; this one is not. |
| 3 | J. Rafael Sendra, Franz Winkler, Sonia Pérez-Díaz. *Rational Algebraic Curves: A Computer Algebra Approach.* Algorithms and Computation in Mathematics 22, Springer, 2008. ISBN 978-3-540-73725-4. | Ch. 11. Deciding genus zero and computing a rational parametrisation, at book length. Ch. 11 has no source without it. | **[web]** library catalogues. In print; paywalled. |
| 4 | Mark van Hoeij. Rational parametrizations of algebraic curves using a canonical divisor. *J. Symbolic Computation* 23 (1997). DOI `10.1006/jsco.1996.0084`. | Ch. 11. The parametrisation algorithm that works through `L(D)` and an integral basis — the same machinery as chs. 3 and 5, so it fits the book better than the adjoint-curve method. | **[web]** DOI and the author's page (`math.fsu.edu/~hoeij/papers/comments/jsc1997a.html`). Volume and pages beyond the DOI are **[memory]**. |
| 5 | Umberto Zannier. Elementary integration of differentials in families and conjectures of Pink. *Proc. ICM Seoul 2014*, vol. II, pp. 531–555. | Ch. 10, the case of a transcendental parameter. A survey by one of the authors of the held Masser & Zannier paper, and far shorter than its 87 pages. | **[cited]** Trager's commentary [37]. ICM proceedings are normally open access **[memory]**. |

## 2. By chapter

### Ch. 3 — integral bases

Held sources suffice for Trager's and van Hoeij's algorithms. These bring the chapter up to date;
all **[cited]** in Trager's commentary.

- David J. Ford. *On the computation of the maximal order in a Dedekind domain.* PhD thesis, Ohio
  State, 1978 — [21]. With Hans Zassenhaus, "On the Second Round of the Maximal Order Program", in
  *Applications of Number Theory to Numerical Analysis*, pp. 389–431, 1972 — [38]. The number-field
  algorithm Trager adapted. Only for the history.
- Theo de Jong. An Algorithm for Computing the Integral Closure. *JSC* 26:273–277, 1998 — [17].
  Five pages; the standard modern statement.
- Patrizia Gianni and Barry M. Trager. Integral Closure of Noetherian Rings. *Proc. ISSAC '97*,
  pp. 212–216 — [23].
- Greuel, Laplagne and Seelisch. Normalization of rings. *JSC* 45(9):887–901, 2010 — [24]; and
  Böhm et al., Parallel algorithms for normalization, *JSC* 51:99–114, 2013 — [3]. Optional.

**Recommended:** de Jong. The rest only if the chapter grows a section on later methods.

### Ch. 4 — absolute irreducibility

Trager's ch. 3 is the only held account.

- Erich Kaltofen. Fast Parallel Absolute Irreducibility Testing. *JSC* 1(1):57–67, 1985 —
  **[cited]** Trager's commentary [27].
- Dominique Duval. Absolute Factorization of Polynomials: A Geometric Approach. *SIAM J. Comput.*
  20(1):1–21, 1991 — **[cited]** Trager's commentary [20]. The thesis itself cites her 1983 Grenoble
  report for the fact that the number of absolutely irreducible factors is the dimension of the
  space of functions with no poles; this is the published form.
- Guillaume Chèze and Grégoire Lecerf. Lifting and recombination techniques for absolute
  factorization. *J. Complexity* 23(3):380–420, 2007. DOI `10.1016/j.jco.2007.01.008` — **[web]**.
  The current algorithm of record, as far as recalled (**[memory]**).

**Recommended:** Duval 1991, because it connects to the integral basis the book already has; then
Chèze & Lecerf for a pointer to the state of the art.

### Ch. 5 — divisors

Davenport ch. 3, Hess and Bertrand cover the chapter. Worth having as primary sources:

- David G. Cantor. Computing in the Jacobian of a Hyperelliptic Curve. *Math. Comput.*
  48(177):95–101, 1987 — **[cited]** Trager's commentary [6]. Seven pages, and the book prints the
  algorithm, so it should be read at the source.
- John Coates. Construction of rational functions on a curve. *Proc. Cambridge Philos. Soc.*
  68:105–123, 1970 — **[cited]** Trager's commentary [11] and Trager (typeset) [14].
- Emil J. Volcheck. Computing in the Jacobian of a plane algebraic curve. *Algorithmic Number
  Theory* (ANTS-I), pp. 221–233, Springer, 1994 — **[cited]** Trager's commentary [36].

**Recommended:** Cantor.

### Ch. 6 — the classical theory

Hardy and Ritt's 1948 book (in R&S) are held. Two additions:

- P. Tchebichef. Sur l'intégration des différentielles irrationnelles. *J. Math. Pures Appl.* (1)
  18:87–111, 1853 — **[web]**; NUMDAM has the scan (`JMPA_1853_1_18__87_0`), open access. The
  source of the theorem on binomial differentials used in ch. 11.
- Jesper Lützen. *Joseph Liouville 1809–1882: Master of Pure and Applied Mathematics.* Springer,
  1990 — **[cited]** Singer's commentary in R&S, which sends the reader to it for Chebyshev,
  Zolotarev and the Russian school. For the history section only.

**Recommended:** the Chebyshev paper; it is free and short.

### Ch. 10 — points of finite order

The theorems on good reduction are stated in the held sources and proved in none. Trager's thesis
cites them to the following (all **[cited]**, Trager (typeset)):

- J.-P. Serre and J. Tate. Good reduction of abelian varieties. *Annals of Math.*, pp. 492–517,
  1968 — [51].
- G. Shimura and Y. Taniyama. *Complex Multiplication of Abelian Varieties and its Applications to
  Number Theory.* Math. Soc. Japan, 1961 — [54].
- Max Deuring. Reduktion algebraischer Funktionenkörper nach Primdivisoren des Konstantenkörpers.
  *Math. Zeit.* 47:643–654, 1941 — [19] (one of the seven entries absent from the 1984 scan).

And from Trager's commentary:

- Giorgio Dalzotto, Patrizia Gianni and Barry M. Trager. *Good Reduction of Plane Curves.* Listed
  as "Unpublished, N.D." — [14]. If it can be had from the authors, it is the algorithmic treatment
  the chapter wants; it cannot be relied on.
- Nicholas M. Katz. Galois properties of torsion points on abelian varieties. *Invent. Math.*
  62:481–502 — [28].
- Zannier's ICM survey, §1 item 5.

**Recommended:** Serre & Tate for the statement the chapter cites, and Zannier. The book cites
these theorems and does not prove them, so one clean statement is enough.

### Ch. 11 — genus zero

The largest gap; §1 items 3 and 4, and Chebyshev under ch. 6. Also:

- Mark van Hoeij. Computing parametrizations of rational algebraic curves. *Proc. ISSAC '94* —
  **[web]**, the author's page. The predecessor of the 1997 paper.

### Chs. 13–16 — the mixed case

- **Raab's thesis**, §1 item 2.
- Manuel Bronstein. A Unification of Liouvillian Extensions. *AAECC* 1:5–24, 1990 — **[cited]**
  Raab's commentary [Bro90a]. Monomial extensions as Volume I uses them; background for ch. 13.
- Manuel Bronstein. *Integration of Elementary Functions.* PhD thesis, U.C. Berkeley, 1987 —
  **[cited]** Raab's commentary [Bro87]. The held 1990 paper is its revision; the thesis is worth
  having only if the paper's formulas prove unreadable, since a typewritten original may scan
  better than the journal's OCR (**our guess**).
- Stefan T. Boettner. *Mixed Transcendental and Algebraic Extensions for the Risch–Norman
  Algorithm.* PhD thesis, Tulane, 2010 — **[cited]** Raab's commentary [Boe10], which says it
  treats "very general differential fields with algebraic relations among their generators"
  heuristically. For ch. 17's account of what is done in practice.
- R. Risch. The problem of integration in finite terms. *Trans. AMS* 139:167–189, 1969 —
  **[cited]** Volume I [75], R&S throughout. The revised 1968 report assumes its definitions ("We
  assume that the reader is familiar with the notion of elementary extension and related concepts
  from [Ris69b]"), so reading that report closely needs this. AMS journals of that age are open
  access (**[memory]**).
- An arXiv preprint surfaced by the Schultz search: "Parallel Integration over Simple Radical
  Extensions II: Mixed Towers", `arXiv:2609.13643` — **[web]**, title only; its authors, and
  whether a part I exists, were not established. Later than anything else here; look before
  writing chs. 12 and 14.

**Recommended:** Raab's thesis and Risch 1969. For the parametric logarithmic derivative problem
over a curve no source has been identified, here or in the held commentaries; ch. 16 should expect
to say so.

### Ch. 17 — implementations

Axiom and FriCAS are documented in the corpus. Nothing held describes Maple's algebraic integrator
beyond one sentence in van Hoeij's abstract, and no source is recommended, because none is known:
the options are Maple's own help pages for `int` and `algcurves` (**[memory]** that they describe
the method), which would need capturing under `../CLAUDE.md` rule 2 before being quoted.

## 3. Not recommended

Listed in `missing-resources.md` and not worth pursuing for the book: Bertrand's thesis, Risch's
two reports as originally issued, Davenport's RR375, and the 1971 printing of Weil. Each is covered
by something held.

## 4. When one arrives

As `missing-resources.md` says: check that it is the document, open it, and index it in
`../downloaded-references-summary.md` §9 and this directory's `CLAUDE.md` in the same change. Then
remove its entry here and, if the plan graded a chapter on its absence, regrade the chapter.
