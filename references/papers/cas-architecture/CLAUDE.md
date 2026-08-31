# cas-architecture/

How existing computer algebra systems are actually built (bibliography §5). **Read these for
structure — module layout, expression representation, memory strategy — not for algorithms.** The
algorithms are in `../textbooks/`.

| File | The lesson it carries |
| :--- | :--- |
| `meurer2017_sympy.pdf` | How to organize a large CAS: the assumptions system, the `Basic`/`Expr` core, the `polys` module, and how automatic-simplification decisions get made. SymPy invents no language of its own — Python is both the implementation and the user interface. **This is the published *PeerJ CS* 3:e103 (27 pp., 27 authors), swapped in 2026-08-30** for what had been stored and cited as it: the PeerJ Preprints review manuscript (19 pp., 24 authors). Quote it as "Unlike many CAS's" — the apostrophe is the published text's, and is the quickest way to tell a quotation of this file from a quotation of the manuscript. |
| `bauer2002_ginac_framework.pdf` | Four things: (1) deliberately abolishing the low-level/high-level language split — directly relevant to a Haskell-native ambition; (2) reference counting with copy-on-write for structure sharing; (3) a numeric tower built on CLN (the paper does not mention GMP); (4) the polymorphic `ex`/`basic` design with automatic normalization. |
| `fateman1992_review_of_mathematica.pdf` | Fateman built MockMMA, the earliest Wolfram Language reimplementation. This is his critique of Mathematica's design and implementation from the perspective of someone who had already built Macsyma — short, pointed, and unusually candid about what the evaluation model costs. **It is not implementation notes for MockMMA**, and it mentions neither MockMMA nor the widely repeated cease-and-desist story (for which see `wikipedia_wolfram_language.html` below — treat it as folklore). Author copy: it carries no journal metadata, only "Received 16 November 1990, revised 16 September 1991", so the *JSC* 13(5), 1992 citation cannot be confirmed from the file. |
| `lioubartsev2016_pedagogical_cas_thesis.pdf` | A worked example of scoping a CAS project (extending SymPy) and of how automatic-simplification decisions get made in practice. |
| `rich_rubi_vision.html` | Rubi's own statement of rule-based integration as a decision tree — the pragmatic complement to Risch. The page says "over 6600 integration rules" and that "Rubi 4.15 has 6,662 rules"; the "6600–6700" range sometimes quoted is a paraphrase, not its wording. |
| `symbolica_2_2_symbolic_integration.html` | The source of the Rubi-port and corpus-timing figures quoted in the bibliography (7,000+ rules, 72,944 problems, 18 minutes). **These are vendor-reported benchmarks** — note the rule-count discrepancy with Rubi's own site. |
| `sympy_docs_advanced_expression_manipulation.html` | SymPy's own page on expression trees, `func`/`args`, and why `Add(x, x)` comes back as `Mul(2, x)` — automatic simplification happening in the constructor, plus `evaluate=False` and `UnevaluatedExpr` to switch it off. The concrete counterpart to Cohen Vol. 2 §3.2, in a system you can run. |
| `expreduce_readme.html` | Expreduce's README, captured so the quote has an anchor: "This software is experimental quality and is not currently intended for serious use." That is what makes it the right codebase to reverse-engineer — small enough to read whole. The code itself is not here; clone it. |
| `symja_readme.html` | Symja's README. Confirms "the Rubi symbolic integration rules are used to implement the `Integrate` function" — and **names no Rubi version**, which is why the notes take the 4.16 figure from Symbolica's writeup rather than from Symja. Also the anchor for the licence, which is easy to state backwards: the whole system is GPL v3, and "starting with Symja version 2.0.0 parts are published under the Lesser GNU General Public License version 3" — the `parser`, `external` and `core` Maven modules. It is the **LGPL carve-out** that begins at 2.0.0. |
| `symbolica_license.html` | Symbolica's pricing/licence page — the source for the employment trigger and for the **Free** tier's "[o]ne core and instance per device", "for academic/non-commercial use". See the caveat below. |
| `symbolica_pattern_matching.html` | Symbolica's worked examples of wildcard matching (`x_`), including graph isomorphism via `is_symmetric=True` on a symbol. **Note: this capture never uses the word "commutative"** — the sentence "supports commutative and associative matching, and has wildcards (variables ending in underscores)" is in `symbolica_2_2_symbolic_integration.html`. Cite that one for the AC claim. |
| `symbolica_home.html` | Symbolica's own one-line self-description, held so §5 stops paraphrasing it inside quotation marks. The page says Symbolica is "a high-performance computer algebra library for Python and Rust" that lets you "Manipulate large expressions, match patterns, and generate optimized numerical code — at unprecedented speed". **"Built for large expressions" is *not* Symbolica's phrasing** — not here and not in any Wayback snapshot (see the 2023 capture below; 2025 snapshots say "an easy-to-use library for Python and Rust"). Do not quote it. |
| `symbolica_home_2023_wayback.html` | The same page on 2023-11-10, held so that "not in any snapshot either" is a checkable claim and not an assertion. The tagline then: "Symbolica is a blazing fast symbolic manipulation toolkit". |
| `wikipedia_wolfram_language.html` | Held for one sentence, and for what is *missing* from it: "Richard Fateman's MockMMA from 1991 is of historical note, both for being the earliest reimplementation and for having received a cease-and-desist from Wolfram." **No inline citation on that sentence** — the nearby `[24]` belongs to the following sentence, about implementations still maintained. That is the whole basis of the cease-and-desist story, which is why the notes call it folklore. Wikipedia changes; this capture is dated 2026-08-30. |

## Caveats

- Symbolica is **source-available but commercially licensed**, and the trigger is *employment*, not
  commerce: "Symbolica is free for hobbyist use. If you use Symbolica as part of your employment,
  whether in academia or in a commercial or non-commercial organization, a license is required." The
  separate **Free** tier — not the Hobbyist one — is what is capped at "[o]ne core and instance per
  device", "for academic/non-commercial use"; redistribution, "modified or unmodified, requires
  prior written permission". So the common "free for non-commercial use" gloss is wrong — a
  non-commercial employer still needs a licence. Fine to read; check the licence before depending on
  it. Source: `symbolica_license.html`.
- The systems the bibliography names without citing a paper — Expreduce, Mathics3, Symja, SymEngine,
  Maxima, Reduce, Singular, PARI/GP, FLINT — are source repositories, not documents. Clone and grep
  them. (Axiom/FriCAS is the exception: its book is held in `../textbooks/`, in both the Springer
  1992 edition and the FriCAS regeneration.) Expreduce (Go) is the closest architectural blueprint for a Wolfram-style rewriter
  in a statically typed host language, and it is small enough to read.
