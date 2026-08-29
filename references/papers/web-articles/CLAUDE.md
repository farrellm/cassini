# web-articles/

Blog posts, essays, and course sites (bibliography §9, plus Wolfram's historical essays from §6).

**These are opinion and build-logs, not specifications.** Treat every claim as the author's own.
The normative Wolfram documentation is in `../wolfram-language/`; vendor writeups are in
`../cas-architecture/`.

All files are `curl` captures fetched 2026-08-29, with no CSS. Strip tags to read them.

| File | Read it for |
| :--- | :--- |
| `johansson2022_cas_wishes.html` | A practitioner's list from the FLINT/Arb author. The point that matters for Stage 0: "the core datatype in computer algebra is the arbitrary-size integer," while hardware, compilers and languages are not designed for it — the argument for getting the bignum substrate right before anything else. |
| `wolfram2013_before_mathematica.html` | SMP's design and the origin of the symbolic-expression + transformation-rule paradigm. Notes that some early SMP matcher/evaluator code still runs in Mathematica. |
| `wolfram2021_third_of_a_century.html` | The clearest statement of the core design decision: represent everything as a symbolic expression, represent every operation as a transformation, and apply the first transformation that applies until nothing changes. |
| `brun2022_building_a_cas_in_go_part1.html` | A from-scratch build log — multivariate expressions and differentiation. Useful for scoping intuition. **Part 1 only**; no later installments were found. Captured via the Wayback Machine because the live Medium URL is Cloudflare-gated. |
| `vonzurgathen_gerhard_cosec_companion.html` | The *Modern Computer Algebra* companion site index — errata and course materials. A pointer page, ~340 words; follow the links live rather than relying on this capture. |
