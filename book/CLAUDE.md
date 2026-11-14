# book/

The LaTeX source of *Integration of Algebraic Functions: a reconstruction of the unwritten second
volume of "Symbolic Integration"*.

[`../references/bronstein-volume-2/volume-2-outline-and-plan.md`](../references/bronstein-volume-2/volume-2-outline-and-plan.md)
is the outline, the conventions (§4) and the phased plan (§5); read it before writing anything
here. Its evidence is `what-volume-2-would-have-covered.md` beside it, and the sources, with their
per-file defects, are indexed in that directory's `CLAUDE.md`.

**State: phases 1, 2 and 3 are drafted.** Chapters 1–9 and 12 are written; the project owner
waived the plan's reading gate on 2026-11-13 and has read none of them yet. Chapters 10, 11 and
13–17 and the appendices are a heading and the words "not yet written". Next is phase 4: chapters
10 and 11.

**What chapter 10 owes.** `LogarithmicPart` (ch. 9) calls `PrincipalMultiple` (ch. 5) with a bound
`B` that only chapter 10 can supply. Until then the integration algorithm is complete except for
that one number.

| Path | What it is |
| :--- | :--- |
| `volume2.tex` | The main file: title, parts, one `\include` per chapter. |
| `v2book.sty` | The whole preamble: page, theorem environments, the algorithm environment, the standing and dagger marks, notation macros. |
| `front/` | Preface (a draft, from *WV2* §1) and the notation page. |
| `chapters/chNN-slug.tex` | One file per chapter, labelled `ch:slug`. |
| `appendices/app-X-slug.tex` | Appendices A–D. D is generated from the `\standing` marks. |
| `references.bib` | The book's bibliography. |
| `build.sh` | The build. Output goes to `build/`, which is gitignored. |

## Build

`./build.sh` from anywhere; `./build.sh clean` removes `build/`. It runs `lualatex`, `bibtex`,
`makeindex`, then `lualatex` until references settle, and **fails on an undefined reference or
citation or a duplicate label**. Overfull boxes are printed and do not fail it.

`lualatex` needs `luaotfload`, which on Arch is the separate package `texlive-luatex`; without it
the binary exists and stops at `\documentclass`, unable to load a font. Fonts are Latin Modern
through `unicode-math`, so Unicode mathematics in the source (`ν`, `∈`, `≥`) typesets, and the
macros of the table below are still preferred for anything with a meaning.

## Macros

| Macro | Use |
| :--- | :--- |
| `theorem`, `lemma`, `proposition`, `corollary`, `definition`, `example`, `remark` | Each has its own counter within the section, as in Volume I, where Theorem 3.4.1 and Definition 3.4.1 both exist. `exercise` is numbered within the chapter. `openproblem` is unnumbered. |
| `\standing{proved}{}`, `\standing{cited}{Trager, \S4.2}`, `\standing{stated}{}` | Inside a theorem-like environment, after its `\label`. Prints nothing there; adds the row to Appendix D. |
| `\begin{algo}{Name}{args}{title}` … `\end{algo}` | An algorithm in Volume I's form. `\Spec{…}` first, then `algpseudocode` commands (`\State`, `\For`, `\If`, `\While`, `\Return`; `\Comment{…}` prints `(* … *)`). No line numbers, no `end` keywords. Defines the label `alg:Name` and an index entry. |
| `\alg{Name}`, `\seealg{Name}` | An algorithm's name in the text; the second is a link. |
| `\later` | The dagger for post-2005 material, on a heading or in text. |
| `\VolI{\S3.2}` | A citation of Volume I by place. |
| `\unwritten` | The placeholder body. Remove it when a chapter gets its first paragraph. |
| `\OO` | The integral closure of `k[t]` in `E`; `\OO_w` is the module a basis `w` generates. |
| `\Const`, `\ord{P}`, `\lc`, `\resultant`, `\residue`, `\Tr`, `\Norm`, `\disc`, `\kbar`, `\Kbar`, `\Z`, `\Q`, `\C` | Notation carried over from Volume I. |

## Rules

1. **The book follows the plan's §4**, and a convention that changes changes there in the same
   commit. In short: every algorithm has a traced worked example; every closed-form answer is
   checked by differentiation in a CAS before it is printed; every theorem-like result carries a
   `\standing`; nothing is transcribed from an OCR layer.
2. **A macro is added to `v2book.sty` when a chapter first needs it**, with its row in the table
   above. Chapter files define no macros.
3. **A source enters `references.bib` when the text first cites it**, with fields taken from
   `../references/bronstein-volume-2/CLAUDE.md`, not from memory. Keys are `firstauthorYEAR`, with a word added when two collide (`bronstein1998lazy`).
4. **Chapter labels are stable.** Later chapters are written before earlier ones (plan §5, phase
   3), so forward references to `ch:slug` exist from the start. Renaming one means grepping for it.
5. **A worked example is computed, not transcribed.** Every number in chapter 7's examples was
   produced or re-checked in the Wolfram evaluator, including the ones that also appear in
   Bronstein's tutorial. The first draft had two errors that only running the computation found: a
   reduction step narrated as failing in fact succeeds, and an exercise called a basis unsuitable
   that is suitable. Trace the algorithm; do not narrate what it ought to do.
6. **The preface and title page say this is a reconstruction and not Bronstein's book.** No edit
   may weaken that.
