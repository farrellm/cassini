# Missing Documents

Sources cited in [`../notes/cas-haskell-bibliography.md`](../notes/cas-haskell-bibliography.md) that
are **not** held in this corpus, with what was tried and why the gap stands.

[`downloaded-references-summary.md`](./downloaded-references-summary.md) is the authority on what
*exists* here; its "Not obtained" table is the short version. This file adds the routes attempted and
whether the gap actually costs anything.

Status checked **2026-08-30** (third validation round).

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

A **third round** re-ran the whole sweep from scratch instead of trusting the first two, and closed
four more gaps of a kind the earlier passes had not been looking for — claims resting on a document
nobody had opened, rather than quotes resting on a document nobody had fetched:

| Source | § | Why it was missing | Now |
| :--- | :--- | :--- | :--- |
| Symbolica home page | §5 | The notes quoted it as "built for large expressions" | Held — and the quote was **wrong**: that is nobody's wording, here or in the 2023 snapshot (also held), which says "a blazing fast symbolic manipulation toolkit". The phrase was the notes' own paraphrase and has been unquoted. |
| Wikipedia, *Wolfram Language* | §5 | The MockMMA cease-and-desist treatment is an assertion about what that page says **and does not cite** | Held; the assertion checks out — the sentence carries no inline reference. |
| `numhask` package page | §7 | §7 compared numhask against numeric-prelude on upkeep and hierarchy size with only one side held | Held; the comparison is now dated (2026-07-10 vs 2022-05-28) rather than asserted. |
| SymPy, *PeerJ CS* 3:e103 | §5 | Not missing so much as **substituted**: the file held under this citation was the PeerJ Preprints review manuscript, 19 pp. and 24 authors | The published article (27 pp., 27 authors) is now held. The two texts differ by a stray apostrophe in the sentence most often quoted, so a quotation has to name which text it came from; the manuscript is deliberately not held, and nothing quotes it any more. |

The lesson generalises, and is now `../references/CLAUDE.md` rule 2: the "pointers only" waiver covers
*citing* a system, not quoting its page — and not making a claim about what its page says either.

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
| `term-rewriting/klop1992_term_rewriting_systems.pdf` | 112 pp | Has a text layer, but it **drops `fi`/`ffi` ligatures**: "uni cation", "speci cations", "classi cation". Search `uni cation`, or either side of the ligature. |
| `textbooks/geddes_czapor_labahn1992_…pdf` | 593 pp | Body text is sound; the **table-of-contents pages are OCR noise** ("In od ion", "Algo i hm"). Grep the body for chapter titles. |

**A trap worth knowing about.** Eker's PDF reports extractable text on *every* page, so a naive
text-layer check passes it — but the only text is the download watermark repeated, 860 characters
across 19 pages. When auditing the corpus, check the *variety* of extracted text, not just its
presence.

**A quality caveat, not a gap.** `textbooks/karr1985_theory_of_summation_in_finite_terms.pdf` has a
text layer, but its OCR systematically drops the letter `h` — "Teory of Summation", "matematical",
"algoritm", "te" for "the". Searches for `the` or `theorem` silently fail. The 1981 Karr paper is
clean. Klop 1992 fails the same way on `fi`/`ffi`, and it was found only because a structural claim
about the survey's contents was being checked and `grep unification` came back empty on a survey with
a section titled *Unification*.

**The rule that catches this class.** A **failed** grep is a question about the file, not an answer
about the text. Before recording that a source does not say something, confirm the file can say it:
extract a page and read it. Every silent-failure entry in this table was found that way, and the
Eker trap is the same rule from the other side — extractable text is not readable text.

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
`../notes/cas-haskell.md` and the bibliography resolves to a document held here, with **two deliberate
exceptions**, both of them phrases quoted in order to say they are *not* the source's:

- Symbolica's "built for large expressions", which is nobody's wording — the current home page and the
  2023 snapshot that establish this are both held.
- "the strategies rather than the rewrite rules doing the heavy lifting", widely attributed to the
  Rascal paper and not in it — the paper is held, which is how the absence was established.

A third such quotation existed until the fourth round: the bibliography reproduced the SymPy
*preprint's* wording to contrast it with the published article, after the preprint itself had been
deleted from the corpus in round three. The quotation is gone; the contrast is now drawn on the
metadata that is checkable without it (27 pp./27 authors against 19 pp./24 authors).

The live risks are no longer *missing* documents but *unreadable* and *misidentified* ones. Terese has
no text layer and no sidecar; Karr 1985 and Klop 1992 have text layers that fail silently; and the
SymPy entry was, until the third round, a different document from the one it was cited as — which no
amount of grepping would have caught, because the preprint contains the passages the notes quote.
Checking a file's *identity*, not just its searchability, belongs in every audit.
