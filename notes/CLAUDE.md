# notes/

The reading-and-building guide for the CAS project, and its bibliography.

| File | What it is |
| :--- | :--- |
| [`cas-haskell.md`](./cas-haskell.md) | The opinionated guide: what to read, in what order, and the staged build plan. Prose and judgement. |
| [`cas-haskell-bibliography.md`](./cas-haskell-bibliography.md) | The full reference list behind it. Citations, annotations, availability. |

The documents these cite live in [`../references/`](../references/) — see that directory's
`CLAUDE.md` for the corpus rules, and `downloaded-references-summary.md` for what is actually held.

## Rules

1. **Never cite a document you have not opened — and check that it is the document you think.**
   Most substantive errors these notes have carried came from the first half: the evaluation order
   was "corrected" away from the right answer because `wolfram_ref_evaluation.html` was indexed as a
   mere guide page and went unread; the linear-AC polynomial bound was attributed to Eker because
   neither Eker nor Benanav had been read. If a claim rests on a source, open the source — and if it
   cannot be opened, say so in the annotation rather than asserting the claim.

   The second half is a separate failure, and grepping cannot catch it. `meurer2017_sympy.pdf` was
   the PeerJ Preprints *review manuscript*, cited for three rounds as the published article; it
   contains every passage the notes quote, so every quote check passed. Confirm identity — edition,
   page count, author count, publisher marks — not just that the words are in there.
2. **Changing an entry means checking the derived sections in the same edit** — "Availability at a
   Glance" and "Verification Notes" in the bibliography. They summarise the entries above them, so
   they go stale invisibly; three consecutive commits left each describing the state *before* the
   commit that preceded it. A new entry needs an availability bucket. A verified `[unverified]` tag
   needs removing from Verification Notes, not just from the entry.
3. **Adding a citation means resolving it against the corpus in the same change.** Either the
   document is obtained and indexed in `../references/downloaded-references-summary.md`, or it goes
   in that file's "Not obtained" table with the route tried and the reason
   (`../references/CLAUDE.md` rule 2). Adding a citation and leaving the corpus untouched is how
   five sources ended up cited but unaccounted for.
4. **A corrected claim must be fixed everywhere it appears, in the same change.** Most facts about a
   source are written down three times: in `cas-haskell.md` as prose, in the bibliography as an
   annotation, and again in the `../references/**/CLAUDE.md` file for the directory holding it — and
   sometimes a fourth time in `../references/downloaded-references-summary.md`. Correcting one copy
   and leaving the others is the single most repeated mistake in this repo's history: the
   "early SMP code still runs in Mathematica" misreading and the Symbolica AC-matching
   mis-sourcing were each fixed in the notes and then found again, unchanged, in a directory file
   two commits later. Before considering a correction done, grep the whole repo for a distinctive
   phrase from the *old* claim and confirm it returns nothing:

   ```sh
   grep -rn "the wrong phrasing" --include='*.md' notes/ references/
   ```

   **Grep the fact, not the phrasing.** A phrase search finds the copies that were worded alike and
   misses the one that was paraphrased. The Wolfram "the page numbers twelve steps" error survived a
   correction pass that grepped `numbers \*twelve\*` and `12 numbered steps` and came back clean,
   because a fifth copy read "12 steps as the page numbers them". Search for the load-bearing token —
   a number, a name, a filename — and read the hits:

   ```sh
   grep -rniE "numbers? them|numbered steps|12 steps|twelve" --include='*.md' notes/ references/
   ```

   The same applies in the other direction: every source named in `cas-haskell.md` needs a
   bibliography entry, and shared facts — editions, chapter ranges, attributions, titles — must
   match across all copies.
5. **Record corpus defects on the entry, not only in the index.** If the held copy is an image-only
   scan, has lossy OCR, or is a different edition from the citation, say so in the annotation. A
   reader works from the bibliography, and a defect they discover by grepping and finding nothing
   costs more than one sentence here.

## Editing conventions

- Annotations say what a source is *for* and at which stage, not what it contains in the abstract.
- Quote the source when the exact wording carries the point, and attribute the quote to the specific
  page or file it came from — several errors here were paraphrases that drifted.
- Mark unverifiable details `[unverified]` inline and list them in Verification Notes. Mark
  vendor- or author-reported benchmarks as such; do not launder them into plain assertions.
- Distinguish what a source says from what we infer from it. The notes do this explicitly
  ("our inference, not theirs") and should keep doing it.
