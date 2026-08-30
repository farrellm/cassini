# foundations/

The theoretical results that bound what the system can do, and the papers on how to compose the
expression type (bibliography §3).

| File | Read it for |
| :--- | :--- |
| `richardson1968_some_undecidable_problems.pdf` | **The ceiling on `Simplify`.** For expressions over ℚ, π, ln 2, a variable, `+ − ×`, composition, and `sin`/`exp`/`abs`, the predicate "E = 0?" is unsolvable. The `abs` matters: the identity result needs condition (1) — the class contains log 2, π, eˣ, sin x — **and** condition (2), that it contains some μ with μ(x) = \|x\| for x ≠ 0 (√x² will do). The paper's title is "Some **Undecidable** Problems…"; it is very widely miscited as "Unsolvable". Read the statement even if you skip the proof: it is why every real simplifier is a bundle of heuristics with a best-effort contract, and why canonical forms exist only for restricted classes (rationals, polynomials). 8 pages. |
| `swierstra2008_data_types_a_la_carte.pdf` | ASTs as coproducts of functors with `Fix` and a `(:<:)` subtyping class — the reference answer to the expression problem in Haskell. **Read for context, not for adoption:** the project decided the core `Expr` stays untyped and uniform (everything is `f[args]`), which sidesteps the expression problem entirely. |
| `bahr_hvitved2011_compositional_data_types.pdf` | The productionized descendant of à la carte. Same caveat. |

## Scope

This is the landing spot for decidability and zero-testing material as the project needs it.

The summation gap once tracked here is **closed**: Karr's two papers and Schneider's Sigma article
are held, and live with the rest of the summation material in `../textbooks/` alongside *A=B*. The
remaining gaps for the whole corpus are listed in `../../missing-documents.md`.
