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
| `cole_wolfram1981_smp.pdf` | The earliest primary source on the symbolic-expression + transformation-rule architecture that became Mathematica. 3 pages. **Paywalled (ACM), obtained from Sci-Hub** — it is *not* on Wolfram's content servers, whatever the notes used to say; what is there is the manual, held below. |
| `greif1985_smp_pattern_matcher.pdf` | The earliest published description of how this family of pattern matcher was designed. |
| `wolfram1981_smp_summary.pdf` | **SMP's own documentation, 1981** — "an essentially complete but concise description of the standard facilities available in SMP". What the language looked like seven years before Mathematica: read it beside Wolfram's 2013 essay, which describes reworking exactly this. 73 pp., free from Wolfram. |
| `wolfram1981_smp_primer.pdf` | The pedagogical companion. **§3 is *Patterns*** — the primary source on the matcher this project is modelled on, from before the `_`/name separation Wolfram says he had not yet arrived at. 88 pp. |
| `wolfram1981_smp_reference_manual.pdf` | Function-by-function reference, for checking an SMP primitive against its Wolfram Language descendant. Reference pages carry thin but real text (~100–300 chars). 238 pp. |

## Facts to internalize before designing the matcher

- General AC matching is **NP-hard** — worst case exponential. Enumerating *all* matches is
  separately exponential.
- *Linear* AC matching (no repeated pattern variables) is **polynomial** — O(|s|·|t|³).
- **Both results are Benanav, Kapur & Narendran (1987), held here.** Their abstract proves the
  NP-completeness *and* the linear bound, and their algorithm already used maximum bipartite graph
  matching. Do not attribute the polynomial bound to Eker — Eker himself credits Benanav, as does
  Bachmair '93. Neither result *originates* in the MatchPy papers — they cite Benanav ([BKN87]/[22])
  for NP-completeness and do not give the polynomial bound at all.
- Discrimination nets conventionally handle repeated variables in two stages: treat the patterns as
  linear, then check variable-replacement equivalence in an extra step. **MatchPy departs from
  this**, performing "the full non-linear matching directly at a commutative symbol state instead of
  just using it as a filter."
- Discrimination nets amortize a fixed pattern set across many subject terms — the CAS situation.
  **Read Krebber's measurements carefully: the break-even is in the number of *subjects*, not the
  size of the pattern set.** On the linear-algebra pattern set many-to-one beat one-to-one "with a
  factor between five and 20" — "in every case", at every size tested *there* — and on the much
  larger AST set the speedup reaches roughly 60×. What has to be amortized is the net's one-time
  construction cost, so the win arrives "for applications that match more than a few hundred
  subjects." Write a correct one-to-one matcher first, behind an interface that can be swapped for a
  net later.
- **His "can grow exponentially with the number of patterns" warning is about the wrong net.** In the
  thesis it is said of *VSDNs*, in the MatchPy paper of the plain *syntactic* discrimination net —
  both of which he benchmarks **against** the many-to-one net he builds and recommends, and of that
  one he reports "the growth of the net seems to be sublinear in practice" (~300 states for the full
  linear-algebra pattern set, ~5,000 for the far larger AST one). Do not quote it as a reason not to
  build a many-to-one net.
- No Haskell library offers Mathematica-grade matching off the shelf. This will be written by hand.
