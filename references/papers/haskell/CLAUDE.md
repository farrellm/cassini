# haskell/

Haskell-specific papers and library documentation (bibliography §7). The datatype-composition papers
that §3 groups as foundational are in `../foundations/`.

| File | Read it for |
| :--- | :--- |
| `ishii2018_purely_functional_cas_haskell.pdf` | **The reference for typed algebra in Haskell.** Encodes polynomial arity, monomial ordering, and coefficient ring as type-level parameters, so ℚ[x,y,z] and ℚ[w,x,y] cannot be added by mistake. Implements Gröbner bases with F4, F5, and Hilbert-driven algorithms; builds on Kmett's `algebra`. Positioned against DoCon "with more emphasis on safety and correctness." **Caveat the paper states plainly: the types check arity and identity, not the ring axioms — those are QuickCheck properties, not proofs.** |
| `zhu2025_hash_consing.pdf` | The structure-sharing landscape — GiNaC's reference counting, Symbolica's interning, JuliaSymbolics' weak-reference hash-consing. **The key point for this project: hash-consing works best with immutable expressions and a tracing GC, which is exactly Haskell's model.** Read before fixing the `Expr` representation. Also note its own caution that the claim Wolfram hash-conses internally is inferred from blog posts, not confirmed. |
| `numeric_prelude_haskellwiki.html` | The canonical statement of **why the standard `Num` class is wrong for a CAS**: no semantics for its operations, forced `Eq`/`Show` superclasses that a function-valued ring cannot satisfy, and representation-specific operations (`toInteger`, `decodeFloat`) mixed in with semantic ones. |
| `numeric_prelude_hackage.html` | The resulting hierarchy: `Num → Additive, Ring, Absolute`; `Fractional → Field`; `Floating → Algebraic, Transcendental`. |
| `olah2012_hasksymb.html` | **Read for the conclusion as much as the code.** A small untyped rewriting experiment using QuasiQuoters and ViewPatterns, whose author found no clean way to put variables into types and called that the unresolved crux. It is the direct evidence behind this project's decision to keep the core `Expr` untyped. Dated June 2012 (the bibliography says November). |

## The decision these documents support

Untyped uniform `Expr` for the rewriting core — free `Eq`/`Ord` for canonical ordering under
`Orderless` and for memoization, uniform traversal via `uniplate` or `recursion-schemes`, immutable
and hash-consed. Type-level machinery is reserved for the polynomial/ring sub-libraries, where Ishii
shows it buys real safety.

The libraries themselves (`algebra`, `numhask`, `poly`, `constructive-algebra`,
`recursion-schemes`, `uniplate`, `sbv`, `symengine`, `dumb-cas`, `computational-algebra`) are Hackage
packages, not documents; browse them on Hackage rather than archiving them here.
