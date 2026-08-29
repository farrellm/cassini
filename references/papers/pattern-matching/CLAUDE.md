# pattern-matching/

The hard engineering (bibliography §4) plus the two historical SMP papers (§3) that are the earliest
primary sources on this family of matcher. The theory that tells you whether a rule set terminates or
is confluent lives in `../term-rewriting/`.

This is the layer where a Wolfram-like engine lives or dies, and the CAS textbooks barely cover it.

| File | Read it for |
| :--- | :--- |
| `krebber2017_ac_matching_thesis.pdf` | **The single most important document for Stage 1.** The only place the full combined feature set is worked out in one document: associative-commutative matching + sequence variables + non-linear patterns + many-to-one via discrimination nets. 67 pages, free on arXiv. |
| `krebber2017_matchpy.pdf` | The short, readable version — Mathematica-style matching with `BlankSequence`/`BlankNullSequence` analogues, constraints, and discrimination nets, with a working Python implementation to compare against. |
| `krebber2017_efficient_pattern_matching_python.pdf` | arXiv:1710.00077 — the other MatchPy paper, on the algorithms and their performance. (Previously misfiled here as a Barthels linear-algebra paper; see the summary's corrections table.) |
| `bachmair1995_ac_discrimination_nets.pdf` | IJCAI '95, pp. 348–354 — measurements for AC discrimination nets. **Read before optimizing the matcher**, not before writing it. 7 pages. The 1993 TAPSOFT paper that *introduces* the data structure is not held (paywalled). |
| `cole_wolfram1981_smp.pdf` | The earliest primary source on the symbolic-expression + transformation-rule architecture that became Mathematica. 3 pages. |
| `greif1985_smp_pattern_matcher.pdf` | The earliest published description of how this family of pattern matcher was designed. |

## Facts to internalize before designing the matcher

- General AC matching is **NP-hard** — worst case exponential. The primary citation is Benanav,
  Kapur & Narendran, "Complexity of Matching Problems," *JSC* 3(1):203–216 (1987), which Krebber
  cites for AC matching being NP-complete. Enumerating *all* matches is separately exponential.
- *Linear* AC matching (no repeated pattern variables) is **polynomial**, by reduction to bipartite
  matching — Eker, *The Computer Journal* 38(5):381–399 (1995), the technique Maude uses. That
  result is **not** in the MatchPy papers; cite Eker for it.
- Discrimination nets conventionally handle repeated variables in two stages: treat the patterns as
  linear, then check variable-replacement equivalence in an extra step. **MatchPy departs from
  this**, performing "the full non-linear matching directly at a commutative symbol state instead of
  just using it as a filter."
- Discrimination nets amortize a fixed pattern set across many subject terms — the CAS situation.
  But Krebber's measurements show the win arriving only with large pattern sets, and warn a net's
  state count "can grow exponentially with the number of patterns." Write a correct one-to-one
  matcher first, behind an interface that can be swapped for a net later.
- No Haskell library offers Mathematica-grade matching off the shelf. This will be written by hand.
