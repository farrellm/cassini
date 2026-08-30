# term-rewriting/

Rewriting theory for the evaluator layer (bibliography §2) plus the one cited paper from the
rewriting-based language design section (§8).

Matching *algorithms* and their engineering live next door in `../pattern-matching/`; this directory
is the theory that tells you whether your rule set behaves.

| File | Read it for |
| :--- | :--- |
| `baader_nipkow1998_term_rewriting_and_all_that.pdf` | **The primary read — chs. 1–2 and 5–7 first**, in parallel with Cohen. Chs. 1–4 are motivating examples, abstract reduction systems, universal algebra and equational problems; **termination is ch. 5, confluence and critical pairs ch. 6, Knuth–Bendix completion ch. 7** — chs. 1–4 alone will not give you those. Ch. 8 is Gröbner bases/Buchberger; chs. 10–11 (AC unification, rewriting modulo equational theories) matter once the AC matcher lands. Algorithms informally *and* as Standard ML; the efficient unification and congruence-closure programs are Pascal. 170+ exercises. |
| `terese2003_term_rewriting_systems.pdf` | The comprehensive advanced reference. **908 pages, 181 MB, and an image-only scan with no text layer** — `pdftotext` returns nothing, so it cannot be grepped or excerpted. Open it in a viewer, and only for confluence/termination theory beyond Baader & Nipkow. |
| `klop1992_term_rewriting_systems.pdf` | **Klop's full survey (112 pp.)** — the *Handbook of Logic in Computer Science* Vol. 2 chapter, circulated by CWI as `CS-R9053`. Abstract reduction systems (with Knuth–Bendix completion and (E-)unification), orthogonal TRSs and reduction strategies, strong sequentiality, conditional TRSs. **Read the chapter here, not from the Handbook scan** — same text, but this one has a text layer and is 1/100th the size. |
| `klop1990_church_rosser_to_knuth_bendix.pdf` | Klop's ICALP '90 survey (20 pp., free from CWI): abstract rewriting, Combinatory Logic, orthogonal systems, strategies, critical pair completion, extended rewriting formats. A separate, shorter paper — the quick way in. |
| `abramsky1992_handbook_of_logic_in_computer_science_vol2.pdf` | The volume containing Klop's *Term Rewriting Systems* at pp. 1–116. **582 pages, 71 MB, and image-only — no text layer**, so `pdftotext` returns nothing and extracting a page range will silently give you an empty file. Use `klop1992_term_rewriting_systems.pdf` for that chapter; keep this only for the volume's other chapters, and open it in a viewer. |
| `klint_vanderstorm_vinju2009_rascal.pdf` | SCAM '09. Cited for one lesson: separating rewrite *rules* from the *strategies* that apply them — concretely, Rascal's `visit` construct carries explicit `top-down`/`bottom-up` strategy annotations. Maps onto the split between rule tables and evaluation control (`ReplaceRepeated`, `//.`, holding, evaluation order). **The often-quoted line about "the strategies rather than the rewrite rules doing the heavy lifting" is not in this paper** — don't cite it here. |

## What is deliberately not here

The bibliography §8 also names Maude, OBJ/OBJ3, ELAN, Stratego, Tom, and Pure. Those are systems to
study, not documents it cites; no papers for them were collected. Maude in particular is the system
to read if efficient matching modulo associativity/commutativity/identity becomes the bottleneck —
fetch its manual then, and record it in the summary.
