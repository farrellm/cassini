# web-articles/

Blog posts, essays, and course sites (bibliography §9, plus Wolfram's historical essays from §6).

**These are opinion and build-logs, not specifications.** Treat every claim as the author's own.
The normative Wolfram documentation is in `../wolfram-language/`; vendor writeups are in
`../cas-architecture/`.

All files are `curl` captures fetched 2026-08-29, with no CSS. Strip tags to read them.

| File | Read it for |
| :--- | :--- |
| `johansson2022_cas_wishes.html` | A practitioner's list from the FLINT/Arb author. The point that matters for Stage 0: "the core datatype in computer algebra is the arbitrary-size integer," while hardware, compilers and languages are not designed for it — the argument for getting the bignum substrate right before anything else. |
| `wolfram2013_before_mathematica.html` | SMP's design and the origin of the symbolic-expression + transformation-rule paradigm. **Read the famous line carefully:** "quite a bit of that code is still running in Mathematica today, especially in the pattern matcher and evaluator" refers to the *Mathematica* code Wolfram wrote in 1986–88, **not** to SMP code — the essay is explicit that SMP's surface design was reworked, not carried over. The claim that early SMP code still runs in Mathematica is a misreading of this sentence. |
| `wolfram2021_third_of_a_century.html` | The clearest statement of the core design decision: represent everything as a symbolic expression, represent every operation as a transformation, and apply the first transformation that applies until nothing changes. |
| `brun2022_building_a_cas_in_go_part1.html` | A from-scratch build log — multivariate expressions and differentiation. Useful for scoping intuition. **Part 1 only**; no later installments were found. Captured via the Wayback Machine because the live Medium URL is Cloudflare-gated. |
| `vonzurgathen_gerhard_cosec_companion.html` | The *Modern Computer Algebra* book page: "Addenda and corrigenda" (per-edition errata), reviews, downloads, MCA gallery. A pointer page, ~280 words — follow the links live. Small but load-bearing: it is the citable source for the book's extent (808 pages, 40 tables, 560 exercises) and its edition ISBNs (1st 1999 `0521641764`, 2nd **2003** `978-0521826464`), which is what settles the commonly miscited "2002 second edition". |
