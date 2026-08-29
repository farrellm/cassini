# term-rewriting/

Rewriting theory for the evaluator layer (bibliography §2) plus the one cited paper from the
rewriting-based language design section (§8).

Matching *algorithms* and their engineering live next door in `../pattern-matching/`; this directory
is the theory that tells you whether your rule set behaves.

| File | Read it for |
| :--- | :--- |
| `baader_nipkow1998_term_rewriting_and_all_that.pdf` | **The primary read — chs. 1–2 and 5–7 first**, in parallel with Cohen. Chs. 1–4 are motivating examples, abstract reduction systems, universal algebra and equational problems; **termination is ch. 5, confluence and critical pairs ch. 6, Knuth–Bendix completion ch. 7** — chs. 1–4 alone will not give you those. Ch. 8 is Gröbner bases/Buchberger; chs. 10–11 (AC unification, rewriting modulo equational theories) matter once the AC matcher lands. Algorithms informally *and* as Standard ML; the efficient unification and congruence-closure programs are Pascal. 170+ exercises. |
| `terese2003_term_rewriting_systems.pdf` | The comprehensive advanced reference. **908 pages, 181 MB, and an image-only scan with no text layer** — `pdftotext` returns nothing, so it cannot be grepped or excerpted. Open it in a viewer, and only for confluence/termination theory beyond Baader & Nipkow. |
| `klop1990_church_rosser_to_knuth_bendix.pdf` | Klop's ICALP '90 survey (20 pp., free from CWI): abstract rewriting, Combinatory Logic, orthogonal systems, strategies, critical pair completion, extended rewriting formats. The cheap way into the same material as the handbook chapter below. **(Replaces a file previously misfiled here under `klop1992_…` that was in fact a 1982 stochastic-filtering preprint — see the summary's corrections table.)** |
| `abramsky1992_handbook_of_logic_in_computer_science_vol2.pdf` | Contains Klop's full *Term Rewriting Systems* lecture notes at **pp. 1–116**. **582 pages, 71 MB** — extract that range, don't open the whole scan. |
| `klint_vanderstorm_vinju2009_rascal.pdf` | SCAM '09. Cited for one lesson: separating rewrite *rules* from the *strategies* that apply them — concretely, Rascal's `visit` construct carries explicit `top-down`/`bottom-up` strategy annotations. Maps onto the split between rule tables and evaluation control (`ReplaceRepeated`, `//.`, holding, evaluation order). **The often-quoted line about "the strategies rather than the rewrite rules doing the heavy lifting" is not in this paper** — don't cite it here. |

## What is deliberately not here

The bibliography §8 also names Maude, OBJ/OBJ3, ELAN, Stratego, Tom, and Pure. Those are systems to
study, not documents it cites; no papers for them were collected. Maude in particular is the system
to read if efficient matching modulo associativity/commutativity/identity becomes the bottleneck —
fetch its manual then, and record it in the summary.
