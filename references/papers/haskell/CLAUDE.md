# haskell/

Haskell-specific papers and library documentation (bibliography §7). The datatype-composition papers
that §3 groups as foundational are in `../foundations/`.

| File | Read it for |
| :--- | :--- |
| `ishii2018_purely_functional_cas_haskell.pdf` | **The reference for typed algebra in Haskell.** Encodes polynomial arity, monomial ordering, and coefficient ring as type-level parameters, so ℚ[x,y,z] and ℚ[w,x,y] cannot be added by mistake. Implements Gröbner bases with F4, F5, and Hilbert-driven algorithms; builds on Kmett's `algebra`. Positioned against DoCon "with more emphasis on safety and correctness." **Caveat the paper states plainly: the types check arity and identity, not the ring axioms — those are QuickCheck properties, not proofs.** |
| `zhu2025_hash_consing.pdf` | Zhu, Sabharwal, Tan, Ma, Edelman & Rackauckas (MIT / JuliaHub) — an implementation report on adding hash-consing to JuliaSymbolics via a global **weak-reference** table (up to 3.2× faster, 2× less memory), with a short related-work section that is the useful survey. It is more negative than usually reported: SymPy and SymEngine use a set rather than the DAG; FriCAS and REDUCE get Lisp symbol interning but no proper hash-consing; **GiNaC "does use a form of reference counting," and of GiNaC and Symbolica alike it says "it is trivial to construct programs using either package that demonstrate identical subexpressions with different memory locations" — i.e. neither hash-conses.** Do not cite it as saying Symbolica interns. It also cautions that the claim Wolfram hash-conses internally is inferred from a blog post, not confirmed. **Implication for this project (our inference, not the paper's): the mechanism needs immutable terms plus a GC that collects through weak references — exactly Haskell's model.** Read before fixing the `Expr` representation. |
| `numeric_prelude_haskellwiki.html` | The canonical statement of **why the standard `Num` class is wrong for a CAS**: no semantics for its operations, forced `Eq`/`Show` superclasses that a function-valued ring cannot satisfy, and representation-specific operations (`toInteger`, `decodeFloat`) mixed in with semantic ones. |
| `numeric_prelude_hackage.html` | The resulting hierarchy: `Num → Additive, Ring, Absolute`; `Fractional → Field`; `Floating → Algebraic, Transcendental`. |
| `penner2018_asts_with_fix_and_free.html` | The practical how-to for `Fix` and `Free` over an AST: parameterize the recursive slots, derive `Functor`, fold with `cata`. Read before wiring up `recursion-schemes` over `Expr`. |
| `milewski2017_f_algebras.html` | Part 24 of *Category Theory for Programmers* — initial algebras and catamorphisms, i.e. *why* `Fix`/`cata` are the right shapes. Theory companion to Penner. |
| `olah2012_hasksymb.html` | A small untyped rewriting experiment using QuasiQuoters and ViewPatterns. Dated 1 June 2012. **This capture is only the ~250-word demo post** — the design retrospective everyone quotes ("The *big* issue I'm facing is appropriate types for symbolic expressions. In particular, how do I handle variables in types?", and "My bad solution for now has been to just not have type-level variable representation") is in the **repository README** at `github.com/colah/HaskSymb`, not here. That conclusion is the direct evidence behind this project's decision to keep the core `Expr` untyped. |

## The decision these documents support

Untyped uniform `Expr` for the rewriting core — free `Eq`/`Ord` for canonical ordering under
`Orderless` and for memoization, uniform traversal via `uniplate` or `recursion-schemes`, immutable
and hash-consed. Type-level machinery is reserved for the polynomial/ring sub-libraries, where Ishii
shows it buys real safety.

The libraries themselves (`algebra`, `numhask`, `poly`, `constructive-algebra`,
`recursion-schemes`, `uniplate`, `sbv`, `symengine`, `dumb-cas`, `computational-algebra`) are Hackage
packages, not documents; browse them on Hackage rather than archiving them here.
