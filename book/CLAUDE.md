# book/

The LaTeX source of *Integration of Algebraic Functions: a reconstruction of the unwritten second
volume of "Symbolic Integration"*.

[`../references/bronstein-volume-2/volume-2-outline-and-plan.md`](../references/bronstein-volume-2/volume-2-outline-and-plan.md)
is the outline, the conventions (§4) and the phased plan (§5); read it before writing anything
here. Its evidence is `what-volume-2-would-have-covered.md` beside it, and the sources, with their
per-file defects, are indexed in that directory's `CLAUDE.md`.

**State: the book is complete in first draft (phases 0 to 6, 2026-11-13 to 2026-11-15).** All 17
chapters and four appendices are written, 148 pages. The project owner waived the plan's reading
gate on 2026-11-13 and has not yet read any of it; nothing here has had a second reader. What
the book leaves undone is listed in its own §17.4, and that list is the agenda for a revision.

**Part III is not on the footing of Part II.** Chapters 13–16 prove what follows from Lemma 7.2.1
(the generalised residue, the residue criterion, the order bounds at normal places, the diagonal
cases for a simple radical) and cite the rest: the residues at special places, the general
`(S_log)`/`(S_exp)` systems, and the solution of the Risch equation by expansions are stated from
Bronstein 1990 and Risch's revised report and not reproduced. Chapter 16 is mostly a statement of
what has no source. Do not let a later edit make these chapters sound more complete than they are.

| Path | What it is |
| :--- | :--- |
| `volume2.tex` | The main file: title, parts, one `\include` per chapter. |
| `v2book.sty` | The whole preamble: page, theorem environments, the algorithm environment, the standing and dagger marks, notation macros. |
| `front/` | Preface (a draft, from *WV2* §1) and the notation page. |
| `chapters/chNN-slug.tex` | One file per chapter, labelled `ch:slug`. |
| `appendices/app-X-slug.tex` | Appendices A–D. D is generated from the `\standing` marks. |
| `references.bib` | The book's bibliography. |
| `data/test-integrals.tsv` | Appendix A's integrals in Wolfram Language syntax, one per line. Keep it and the appendix's table in step. |
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
| `\LL` | `\LL(A)`, the Riemann–Roch space of a divisor. |
| `\index{term}` | Placed by hand after the defining occurrence of a term. Algorithms index themselves. |
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
5. **A new closed form goes into `data/test-integrals.tsv` and Appendix A in the same change**, after
   it has been checked by differentiation.
6. **A worked example is computed, not transcribed.** Every number in chapter 7's examples was
   produced or re-checked in the Wolfram evaluator, including the ones that also appear in
   Bronstein's tutorial. The first draft had two errors that only running the computation found: a
   reduction step narrated as failing in fact succeeds, and an exercise called a basis unsuitable
   that is suitable. Trace the algorithm; do not narrate what it ought to do.
7. **The preface and title page say this is a reconstruction and not Bronstein's book.** No edit
   may weaken that.
