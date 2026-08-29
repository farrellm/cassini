# pattern-matching/

The hard engineering (bibliography §4) plus the two historical SMP papers (§3) that are the earliest
primary sources on this family of matcher. The theory that tells you whether a rule set terminates or
is confluent lives in `../term-rewriting/`.

This is the layer where a Wolfram-like engine lives or dies, and the CAS textbooks barely cover it.

| File | Read it for |
| :--- | :--- |
| `krebber2017_ac_matching_thesis.pdf` | **The single most important document for Stage 1.** The only place the full combined feature set is worked out in one document: associative-commutative matching + sequence variables + non-linear patterns + many-to-one via discrimination nets. 67 pages, free on arXiv. |
| `krebber2017_matchpy.pdf` | The short, readable version — Mathematica-style matching with `BlankSequence`/`BlankNullSequence` analogues, constraints, and discrimination nets, with a working Python implementation to compare against. |
| `barthels2017_linear_algebra_rewrite_rules.pdf` | The companion application paper; useful for seeing the matcher driven by a real rule set. |
| `bachmair1995_ac_discrimination_nets.pdf` | Generalizing discrimination nets to AC symbols, with measurements. **Read before optimizing the matcher**, not before writing it. 6 pages. |
| `cole_wolfram1981_smp.pdf` | The earliest primary source on the symbolic-expression + transformation-rule architecture that became Mathematica. 3 pages. |
| `greif1985_smp_pattern_matcher.pdf` | The earliest published description of how this family of pattern matcher was designed. |

## Facts to internalize before designing the matcher

- General AC matching is **NP-hard** — worst case exponential.
- *Linear* AC matching (no repeated pattern variables) is **polynomial**. Hence the standard
  two-stage strategy: match the linearized pattern, then check the non-linear constraints.
- Discrimination nets amortize a fixed pattern set across many subject terms — which is exactly the
  CAS situation, so design many-to-one matching in from Stage 1 rather than retrofitting it.
- No Haskell library offers Mathematica-grade matching off the shelf. This will be written by hand.
