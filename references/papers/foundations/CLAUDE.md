# foundations/

The theoretical results that bound what the system can do, and the papers on how to compose the
expression type (bibliography §3).

| File | Read it for |
| :--- | :--- |
| `richardson1968_some_unsolvable_problems.pdf` | **The ceiling on `Simplify`.** For expressions over ℚ, π, ln 2, a variable, `+ − ×`, composition, and `sin`/`exp`/`abs`, the predicate "E = 0?" is recursively undecidable. Read the statement even if you skip the proof: it is why every real simplifier is a bundle of heuristics with a best-effort contract, and why canonical forms exist only for restricted classes (rationals, polynomials). 8 pages. |
| `swierstra2008_data_types_a_la_carte.pdf` | ASTs as coproducts of functors with `Fix` and a `(:<:)` subtyping class — the reference answer to the expression problem in Haskell. **Read for context, not for adoption:** the project decided the core `Expr` stays untyped and uniform (everything is `f[args]`), which sidesteps the expression problem entirely. |
| `bahr_hvitved2011_compositional_data_types.pdf` | The productionized descendant of à la carte. Same caveat. |

## Gap tracked here

This is the landing spot for decidability and zero-testing material as the project needs it. Known
missing, per `../../../notes/cas-haskell.md`: **Karr's algorithm** for symbolic summation in
difference fields (not covered by *A=B*) and Schneider's Sigma work. Fetch those when summation
beyond Gosper/Zeilberger becomes real, and add them to
`../../downloaded-references-summary.md`.
