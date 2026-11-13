# Recommended sources for the remaining gaps

What to obtain so that each chapter of the reconstructed Volume II
([`volume-2-outline-and-plan.md`](./volume-2-outline-and-plan.md)) has a source to be written from.
[`missing-resources.md`](./missing-resources.md) lists what held documents cite and is not held;
this file is narrower and more opinionated: what the *book* lacks, and what to get for it.

Written 2026-11-13, and rewritten the same day after everything on its first version that could be
fetched freely was fetched: twelve documents, listed in §1. What remains, §2–§3, is paywalled, in
print, unpublished, or was not found.

## How far to trust each entry

| Tag | Meaning |
| :--- | :--- |
| **[cited]** | The citation was read in a held document's reference list, which is named. Reliable as a citation; says nothing about content. |
| **[web]** | A web search on 2026-11-13 confirmed that the work exists under this citation. The document was not downloaded or read; search-result summaries are the only basis for any remark about content. |
| **[memory]** | Recalled. Unverified. |

"R&S" is the held `raab_singer2022_…` volume; "Trager's commentary" is its last chapter and "Trager
(typeset)" its seventh. Citation numbers into the thesis are the typeset version's, which differ
from the scan's.

## 1. Obtained on 2026-11-13

Held and indexed; [`CLAUDE.md`](./CLAUDE.md) has the annotation for each, including which are
authors' versions and which need their OCR sidecars. Most were opened only as far as the abstract.

| For | Now held |
| :--- | :--- |
| Chs. 7–10, a check on the reading of Trager | Schultz, *Trager's Algorithm … Revisited* |
| Ch. 4, absolute factorisation | Kaltofen 1985; Chèze & Lecerf 2007 |
| Ch. 5, hyperelliptic Jacobians | Cantor 1987 |
| Ch. 6 and ch. 11, the binomial theorem | Chebyshev 1853 |
| Ch. 11, genus zero | van Hoeij 1997 and its ISSAC '94 predecessor |
| Chs. 12 and 14, radicals in mixed towers | Blake 2026, parts I and II (arXiv preprints) |
| Ch. 15, reading Risch's revised 1968 report | Risch 1969 (*Trans. AMS*); Duval 1989 on rational Puiseux expansions |
| Ch. 16, parametric problems | Raab's 2012 thesis |

**Two of these did less than hoped.**

- *Raab's thesis does not close ch. 16.* It is about towers of transcendental monomials; a search
  of it for algebraic extensions found only extensions of the constant field. It supplies the
  modern statement of the parametric problems, not their solution over a curve.
- *Ch. 11 is covered for parametrisation, by one paper in an author's preprint.* A textbook
  treatment is still worth having (§2).

## 2. Still recommended, in order

| # | Source | For | Standing and route |
| :--- | :--- | :--- | :--- |
| 1 | J. Rafael Sendra, Franz Winkler, Sonia Pérez-Díaz. *Rational Algebraic Curves: A Computer Algebra Approach.* Algorithms and Computation in Mathematics 22, Springer, 2008. ISBN 978-3-540-73725-4. | Ch. 11. Deciding genus zero and parametrising, at book length, with proofs — what van Hoeij's paper assumes the reader has. | **[web]** library catalogues. In print; paywalled. |
| 2 | Umberto Zannier. Elementary integration of differentials in families and conjectures of Pink. *Proc. ICM Seoul 2014*, vol. II, pp. 531–555. | Ch. 10, the case of a transcendental parameter. A 25-page survey by an author of the held 87-page Masser & Zannier paper. | **[cited]** Trager's commentary [37]; **[web]** a zbMATH record confirms it. No PDF was found by one search; the IMU hosts ICM proceedings (**[memory]**), which was not tried. |
| 3 | J.-P. Serre and J. Tate. Good reduction of abelian varieties. *Annals of Math.*, pp. 492–517, 1968. | Ch. 10. The statement on good reduction the chapter cites and does not prove. | **[cited]** Trager (typeset) [51]. Paywalled (JSTOR). |
| 4 | Dominique Duval. Absolute Factorization of Polynomials: A Geometric Approach. *SIAM J. Comput.* 20(1):1–21, 1991. | Ch. 4. The published form of the result Trager's thesis cites from her 1983 report: the number of absolutely irreducible factors is the dimension of the space of functions with no poles. It ties ch. 4 to the integral basis of ch. 3. | **[cited]** Trager's commentary [20]. Paywalled (SIAM). |
| 5 | Theo de Jong. An Algorithm for Computing the Integral Closure. *JSC* 26:273–277, 1998. | Ch. 3. Five pages; the standard modern statement of the idealizer method. | **[cited]** Trager's commentary [17]. Elsevier; older *JSC* articles are in an open archive (**[memory]**), not tried. |

## 3. Lower priority, by chapter

All **[cited]** in Trager's commentary unless marked.

- **Ch. 3.** Ford's 1978 Ohio State thesis [21] and Zassenhaus 1972 [38], for the history of the
  Round 2 algorithm; Gianni & Trager, ISSAC '97 [23]; Greuel, Laplagne & Seelisch 2010 [24]; Böhm
  et al. 2013 [3].
- **Ch. 5.** Coates, *Proc. Cambridge Philos. Soc.* 68:105–123, 1970 [11] — Davenport's ch. 3
  presents the algorithm; Volcheck, ANTS-I, 1994 [36].
- **Ch. 6.** Jesper Lützen, *Joseph Liouville 1809–1882*, Springer 1990 — **[cited]** Singer's
  commentary in R&S, for Chebyshev, Zolotarev and the Russian school. History only.
- **Ch. 10.** Shimura & Taniyama 1961 — Trager (typeset) [54]; Deuring, *Math. Zeit.* 47:643–654,
  1941 — [19]; Katz, *Invent. Math.* 62:481–502 [28]; and Dalzotto, Gianni & Trager, *Good
  Reduction of Plane Curves*, "Unpublished, N.D." [14] — the algorithmic treatment the chapter
  wants, obtainable only from its authors.
- **Chs. 13–16.** Bronstein, A Unification of Liouvillian Extensions, *AAECC* 1:5–24, 1990;
  Bronstein's 1987 Berkeley thesis, only if the 1990 paper's formulas prove unreadable; Boettner's
  2010 Tulane thesis, which Blake's part II also cites. All **[cited]** Raab's commentary in R&S.
  Du & Raab, Reduction systems and degree bounds for integration, *JSC* 2025 — **[cited]** Blake
  part II [12].

## 4. No source identified

- **The parametric logarithmic derivative problem, and limited integration, over a curve** (ch.
  16). Not in the held commentaries, not in Raab's thesis. The FriCAS status page calls the first
  "unimplemented in the algebraic case". Blake's part II may bear on it for radical extensions; it
  has not been read.
- **Maple's algebraic integrator** (ch. 17). One sentence in van Hoeij's 1994 abstract is all that
  is held. Maple's help pages would need capturing under `../CLAUDE.md` rule 2 before being quoted.

## 5. Not recommended

Listed in `missing-resources.md` and not worth pursuing for the book: Bertrand's thesis, Risch's
two reports as originally issued, Davenport's RR375, and the 1971 printing of Weil. Each is covered
by something held.

## 6. When one arrives

As `missing-resources.md` says: check that it is the document, open it, and index it in
`../downloaded-references-summary.md` §9 and this directory's `CLAUDE.md` in the same change. Then
move its entry here to §1 and, if the plan graded a chapter on its absence, regrade the chapter.
