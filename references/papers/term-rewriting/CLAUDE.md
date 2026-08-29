# term-rewriting/

Rewriting theory for the evaluator layer (bibliography §2) plus the one cited paper from the
rewriting-based language design section (§8).

Matching *algorithms* and their engineering live next door in `../pattern-matching/`; this directory
is the theory that tells you whether your rule set behaves.

| File | Read it for |
| :--- | :--- |
| `baader_nipkow1998_term_rewriting_and_all_that.pdf` | **The primary read — chs. 1–4 first, in parallel with Cohen Vol. 1.** Abstract reduction systems, termination, confluence, critical pairs, Knuth–Bendix completion, unification, congruence closure. Algorithms given informally *and* as Standard ML. Also derives Gröbner bases/Buchberger as an instance of completion. 170+ exercises. |
| `terese2003_term_rewriting_systems.pdf` | The comprehensive advanced reference. **908 pages, 181 MB** — lookup only, and extract page ranges (`pdftotext -f N -l M`) rather than opening it. Go here only for confluence/termination theory beyond Baader & Nipkow. |
| `klop1992_term_rewriting_systems.pdf` | Klop's short CWI report `CS-R9053` (10 pp.) — a compact survey. |
| `abramsky1992_handbook_of_logic_in_computer_science_vol2.pdf` | Contains Klop's full *Term Rewriting Systems* lecture notes at **pp. 1–116**. **582 pages, 71 MB** — extract that range, don't open the whole scan. |
| `klint_vanderstorm_vinju2009_rascal.pdf` | SCAM '09. Cited for one lesson: separating rewrite *rules* from the *strategies* that apply them, and the observation that in practice the strategies do the heavy lifting. Maps onto the split between rule tables and evaluation control (`ReplaceRepeated`, `//.`, holding, evaluation order). |

## What is deliberately not here

The bibliography §8 also names Maude, OBJ/OBJ3, ELAN, Stratego, Tom, and Pure. Those are systems to
study, not documents it cites; no papers for them were collected. Maude in particular is the system
to read if efficient matching modulo associativity/commutativity/identity becomes the bottleneck —
fetch its manual then, and record it in the summary.
