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
| `bachmair1993_ac_discrimination_nets.pdf` | TAPSOFT '93, pp. 61–74 — **introduces** the AC discrimination net, "a natural generalization of the standard discrimination net in the sense that if no AC-symbols are present in the pattern, it specializes to the standard discrimination net." Image-only; read the `.txt` sidecar to grep it. |
| `bachmair1995_ac_discrimination_nets.pdf` | IJCAI '95, pp. 348–354 — the measurement paper for the above. **Read before optimizing the matcher**, not before writing it. 7 pages. |
| `benanav1987_complexity_of_matching_problems.pdf` | **The complexity source — for both claims.** NP-completeness of AC matching, *and* the O(\|s\|·\|t\|³) bound when every variable occurs at most once. Cite this, not Eker, for either. 14 pages. |
| `eker1995_associative_commutative_matching.pdf` | A *practical* AC-matching algorithm for the general non-linear case — a hierarchy of bipartite graph matching problems, with refinements to cut the search space. The lineage Maude's matcher comes from. Not a complexity result. Image-only apart from a download watermark; read the `.txt` sidecar. |
| `cole_wolfram1981_smp.pdf` | The earliest primary source on the symbolic-expression + transformation-rule architecture that became Mathematica. 3 pages. |
| `greif1985_smp_pattern_matcher.pdf` | The earliest published description of how this family of pattern matcher was designed. |

## Facts to internalize before designing the matcher

- General AC matching is **NP-hard** — worst case exponential. Enumerating *all* matches is
  separately exponential.
- *Linear* AC matching (no repeated pattern variables) is **polynomial** — O(|s|·|t|³).
- **Both results are Benanav, Kapur & Narendran (1987), held here.** Their abstract proves the
  NP-completeness *and* the linear bound, and their algorithm already used maximum bipartite graph
  matching. Do not attribute the polynomial bound to Eker — Eker himself credits Benanav, as does
  Bachmair '93. Neither result is in the MatchPy papers.
- Discrimination nets conventionally handle repeated variables in two stages: treat the patterns as
  linear, then check variable-replacement equivalence in an extra step. **MatchPy departs from
  this**, performing "the full non-linear matching directly at a commutative symbol state instead of
  just using it as a filter."
- Discrimination nets amortize a fixed pattern set across many subject terms — the CAS situation.
  But Krebber's measurements show the win arriving only with large pattern sets, and warn a net's
  state count "can grow exponentially with the number of patterns." Write a correct one-to-one
  matcher first, behind an interface that can be swapped for a net later.
- No Haskell library offers Mathematica-grade matching off the shelf. This will be written by hand.
