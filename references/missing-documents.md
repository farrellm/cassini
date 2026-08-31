# Missing Documents

Sources cited in [`../notes/cas-haskell-bibliography.md`](../notes/cas-haskell-bibliography.md) that
are **not** held in this corpus, with what was tried and why the gap stands.

[`downloaded-references-summary.md`](./downloaded-references-summary.md) is the authority on what
*exists* here; its "Not obtained" table is the short version. This file adds the routes attempted and
whether the gap actually costs anything.

Status checked **2026-08-30**.

---

## Nothing paywalled is missing any more

An earlier version of this file listed nine gaps, six of them paywalled papers. **All six have since
been supplied and are now held**: Klop's *Term Rewriting Systems* survey, Karr's two summation papers,
Benanav/Kapur/Narendran, Eker, Bachmair et al. (TAPSOFT '93), and the genuine Springer edition of
Jenks & Sutor.

A second pass on 2026-08-30 closed a different class of gap: eight pages that the notes quoted
*verbatim* but that were never captured — the Expreduce, Symja and HaskSymb READMEs, the `poly` and
`dumb-cas` package pages, Wadler's blog post, Symbolica's licence, and the `OwnValues` reference
page. Six of them sat behind the summary's "pointers only, by design" waiver, which covers citing a
software system but not quoting its README; Wadler's post and the `OwnValues` page were never
covered by anything. All eight are now held.

A follow-up sweep then tested **every** quoted phrase of five words or more in both notes against a
plain-text index of the whole corpus. It found two more citations that resolved to nothing —
Pickering's closed-type-family reimplementation (§3) and the unspecific "SymPy internals docs" (§5).
Both are now held, the latter pinned to the specific page meant (*Advanced Expression Manipulation*).
It also found two phrases in quotation marks that were the notes' own wording rather than anyone's:
a compression of the `dumb-cas` description, and the OBJ slogan "programming = equational
specification + rewriting". Those were unquoted rather than sourced.

That leaves three gaps, none of which is a paywall — the material is gone from the web or was never
written. **None of them costs anything**, because each is fully superseded by something held here.

| Source | § | Status | Superseded by |
| :--- | :--- | :--- | :--- |
| riptutorial, *Wolfram Language — Evaluation Order* | §6 | Site content gone; no Wayback snapshot | `wolfram_ref_evaluation.html` + `wolfram_ref_evaluation_of_expressions.html` |
| Axiom numbered volumes as PDFs | §5 | `axiom-developer.org` does not resolve (curl: `000`); no prebuilt PDFs found | The `.pamphlet` literate sources (held, and greppable — arguably better) |
| Brun, *Building a CAS in Go*, parts 2+ | §9 | Only Part 1 is discoverable; appears abandoned | Nothing to supersede — the parts do not exist |

### Detail

**riptutorial.** `riptutorial.com/wolfram-language` still resolves (200) but serves a generic landing
page; `/topic/2549/evaluation-order` serves unrelated iOS content; the Wayback Machine holds no
snapshot of either URL. The bibliography marks it **"Dead — do not cite."** Everything it summarised
is in the two Wolfram tech notes, including the point that `Hold`, `HoldComplete`, `HoldForm`,
`ReleaseHold` and `Unevaluated` fall out of attributes plus ordinary definitions rather than being
evaluator special cases.

**Axiom volume PDFs.** For a Haskell implementer the `.pamphlet` sources are the better artefact
anyway: plain LaTeX + SPAD, so you can grep the category and domain definitions directly rather than
reading a rendered PDF.

**Brun parts 2+.** Not a gap so much as a series that stopped after Part 1. Part 1 is held as a
Wayback capture, the live URL being Cloudflare-gated.

---

## A different kind of missing: present but unreadable

Files that are held and correctly indexed, but that a grep-based workflow cannot see.

| File | Extent | Status |
| :--- | :--- | :--- |
| `term-rewriting/terese2003_term_rewriting_systems.pdf` | 908 pp, 181 MB | **Image-only, no mitigation.** Open in a viewer. Optional/advanced material, so tolerable. |
| `term-rewriting/abramsky1992_handbook_of_logic_in_computer_science_vol2.pdf` | 582 pp, 71 MB | **Image-only.** Solved for the chapter that mattered: Klop's *Term Rewriting Systems* (pp. 1–116) is held separately with a full text layer at 700 KB. Keep the Handbook only for its other chapters. |
| `pattern-matching/bachmair1993_ac_discrimination_nets.pdf` | 14 pp | Image-only, **OCR sidecar `.txt` alongside** (40 KB, good quality). |
| `pattern-matching/eker1995_associative_commutative_matching.pdf` | 19 pp | Image-only apart from an Oxford download watermark, **OCR sidecar `.txt` alongside** (77 KB, good quality). |

**A trap worth knowing about.** Eker's PDF reports extractable text on *every* page, so a naive
text-layer check passes it — but the only text is the download watermark repeated, 860 characters
across 19 pages. When auditing the corpus, check the *variety* of extracted text, not just its
presence.

**A quality caveat, not a gap.** `textbooks/karr1985_theory_of_summation_in_finite_terms.pdf` has a
text layer, but its OCR systematically drops the letter `h` — "Teory of Summation", "matematical",
"algoritm", "te" for "the". Searches for `the` or `theorem` silently fail. The 1981 Karr paper is
clean.

### Regenerating the sidecars

They are derived from gitignored PDFs and are themselves gitignored, so a fresh clone has neither:

```sh
pdftoppm -r 300 -gray -png FILE.pdf /tmp/p
for i in $(ls /tmp/p-*.png | sort -V); do tesseract "$i" - --psm 1 -l eng; printf '\n\f\n'; done > FILE.txt
```

---

## Summary

Nothing in this corpus is missing because it was overlooked — every gap has a recorded reason, and
the three that remain are unobtainable rather than unpursued. Every quotation in
`../notes/cas-haskell.md` and the bibliography now resolves to a document held here; the eight
live-only sources listed above were the last exceptions. The live risks are no longer *missing*
documents but *unreadable* ones: Terese has no text layer and no sidecar, and the Karr 1985 OCR is
lossy in a way that fails silently.
