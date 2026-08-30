# cas-architecture/

How existing computer algebra systems are actually built (bibliography §5). **Read these for
structure — module layout, expression representation, memory strategy — not for algorithms.** The
algorithms are in `../textbooks/`.

| File | The lesson it carries |
| :--- | :--- |
| `meurer2017_sympy.pdf` | How to organize a large CAS: the assumptions system, the `Basic`/`Expr` core, the `polys` module, and how automatic-simplification decisions get made. SymPy invents no language of its own — Python is both the implementation and the user interface. |
| `bauer2002_ginac_framework.pdf` | Four things: (1) deliberately abolishing the low-level/high-level language split — directly relevant to a Haskell-native ambition; (2) reference counting with copy-on-write for structure sharing; (3) a numeric tower built on CLN (the paper does not mention GMP); (4) the polymorphic `ex`/`basic` design with automatic normalization. |
| `fateman1992_review_of_mathematica.pdf` | Fateman built MockMMA, the earliest Wolfram Language reimplementation. This is his critique of Mathematica's design and implementation from the perspective of someone who had already built Macsyma — short, pointed, and unusually candid about what the evaluation model costs. **It is not implementation notes for MockMMA**, and it mentions neither MockMMA nor the widely repeated cease-and-desist story (which appears in Wikipedia without a citation — treat it as folklore). |
| `lioubartsev2016_pedagogical_cas_thesis.pdf` | A worked example of scoping a CAS project (extending SymPy) and of how automatic-simplification decisions get made in practice. |
| `rich_rubi_vision.html` | Rubi's own statement of rule-based integration as a decision tree — the pragmatic complement to Risch. The page says "over 6600 integration rules" and that "Rubi 4.15 has 6,662 rules"; the "6600–6700" range sometimes quoted is a paraphrase, not its wording. |
| `symbolica_2_2_symbolic_integration.html` | The source of the Rubi-port and corpus-timing figures quoted in the bibliography (7,000+ rules, 72,944 problems, 18 minutes). **These are vendor-reported benchmarks** — note the rule-count discrepancy with Rubi's own site. |
| `symbolica_pattern_matching.html` | Symbolica's worked examples of wildcard matching (`x_`), including graph isomorphism via `is_symmetric=True` on a symbol. **Note: this capture never uses the word "commutative"** — the sentence "supports commutative and associative matching, and has wildcards (variables ending in underscores)" is in `symbolica_2_2_symbolic_integration.html`. Cite that one for the AC claim. |

## Caveats

- Symbolica is **source-available but commercially licensed**, and the trigger is *employment*, not
  commerce: "Symbolica is free for hobbyist use. If you use Symbolica as part of your employment,
  whether in academia or in a commercial or non-commercial organization, a license is required." The
  free tier is one core and instance per device; redistribution needs written permission. So the
  common "free for non-commercial use" gloss is wrong — a non-commercial employer still needs a
  licence. Fine to read; check the licence before depending on it.
- The systems the bibliography names without citing a paper — Expreduce, Mathics3, Symja, SymEngine,
  Maxima, Reduce, Singular, PARI/GP, FLINT — are source repositories, not documents. Clone and grep
  them. (Axiom/FriCAS is the exception: its book is held in `../textbooks/`, in both the Springer
  1992 edition and the FriCAS regeneration.) Expreduce (Go) is the closest architectural blueprint for a Wolfram-style rewriter
  in a statically typed host language, and it is small enough to read.
