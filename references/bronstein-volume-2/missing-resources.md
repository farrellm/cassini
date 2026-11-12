# Missing resources for the algebraic case

What is cited for the integration of algebraic functions and **not held** in this directory, with
what each is for, what its absence costs, and where it might be found.

Written 2026-11-11; revised 2026-11-12, when seven of the works first listed here were supplied and
moved to [`CLAUDE.md`](./CLAUDE.md) and to §4.1 of
[`what-volume-2-would-have-covered.md`](./what-volume-2-would-have-covered.md): Bronstein's ISSAC'91
paper, Bertrand's paper, van Hoeij, the two EUROSAM'79 papers, Hardy, and Abramov's obituary; and
later the same day four more, replacing files that had first arrived broken: Davenport's 1984 paper,
Chevalley, Bliss and Stichtenoth; and then eight more — Miller's thesis, the FriCAS status page,
Hess, Combot, Masser & Zannier, Fulton, the second Chen et al. paper, and Weil's 1948 book.

That last delivery came with an `INDEX.md` recording where each file was found and what was tried
for the ones that were not. Its search notes are reproduced below **as reported**; they were not
re-run here.

**None of what remains is cited in the bibliography**, so none needs a row in
`../downloaded-references-summary.md`'s "Not obtained" table.

## How far to trust this file

| Tag | Meaning |
| :--- | :--- |
| **[cited]** | The citation was read in a held document's reference list. The work itself was **not opened**, so anything said about its *content* is taken from what the citing document says, or is inference, and is marked. |
| **[memory]** | Recalled without a document in hand. Not verified. A lead, not a fact. |

Every availability note below is **[memory]** unless it says otherwise.

---

## 1. A caution from 2026-11-12

Four files first arrived with the right names and the wrong contents: an nginx "500 Internal Server
Error" page saved as `.pdf`, a Wayback Machine bot-block notice saved as `.pdf`, a DjVu truncated at
page 25 of 204, and a PDF cut off before its cross-reference table. Good copies replaced all four
the same day. Nothing was lost, because each was checked before it was indexed — which is why the
last section of this file says to check first.

---

## 2. Remaining from Bronstein's nine

The first-edition preface of *Symbolic Integration I* sends the reader to nine references for the
algebraic case. Six are now held. These three are not. Citations are as the book's reference list
prints them **[cited]**.

### [8] Bertrand, *Calcul Symbolique des Intégrales Hyperelliptiques*

L. Bertrand. Thèse de doctorat, Université de Limoges, Mathématiques, 1995.

- **For:** the hyperelliptic case at thesis length (from the title).
- **Cost of its absence: little.** His paper on the same subject, [9], is held.
- **Where:** not online, as far as anyone has found. Reported search: `theses.fr` has the record
  (`1995LIMO0036`, Limoges, 1995) with no digitised file, and no scan was found elsewhere.

### [73] Risch, "On the integration of elementary functions which are built up using algebraic operations"

R. Risch. Research Report SP-2801/002/00, System Development Corporation, Santa Monica, CA, USA,
1968.

- **For:** Risch's original treatment of the algebraic case. The tutorial defers to it, with
  Bronstein 1990, for the general algebraic logarithmic and exponential cases.
- **Cost of its absence: low in practice.** Bronstein 1990, held, reworks it — its Part 3 "contains
  Risch's solution of the associated equation problem" — and says of Risch's approach that it "has
  yet to yield a practical algorithm". Risch's 1970 announcement, held, sketches the argument.
- **Where:** a corporate research report, never published. The book's introduction says of Risch's
  reports "unfortunately not all of them published". Reported search: no record on DTIC or the Internet
  Archive. A library with a technical-reports collection is the likely
  route.

### [74] Risch, "Further results on elementary functions"

R. Risch. Research Report RC-2402, IBM Research, Yorktown Heights, NY, USA, 1969.

- **For:** the continuation of [73].
- **Cost of its absence:** as [73].
- **Where:** an IBM research report, never published. Reported search: as for [73], nothing found.
  IBM Research's archive, if it answers requests, or a technical-reports collection.

---

## 3. Cited by a held document, not opened

All **[cited]**. The "cited by" column is where the citation was read.

| Work | Cited by | For | Where to look |
| :--- | :--- | :--- | :--- |
| J.H. Davenport. *Intégration formelle.* Rapport de Recherche RR375, IMAG, Grenoble, 1983. | Book ref. [32] | Unknown beyond the title. | An institutional report. Reported search: not in HAL; no scan found. |
| A. Weil. *Courbes algébriques et variétés abéliennes.* Hermann, Paris, 1971. | Tutorial ref. [22] | The bound behind the finite-order test. | **The 1971 printing is still not held, but its content now is, as far as the citation needs it.** Both 1948 volumes are held: *Variétés abéliennes et courbes algébriques* as a scan, and *Sur les courbes algébriques et les variétés qui s'en déduisent* as a 2022 retranscription, whose part II §IV has the Riemann hypothesis the bound follows from. That the 1971 book is those two reprinted together is **[memory]** and unchecked. Low priority: only a page reference into the 1971 edition is missing. |
| D.G. Cantor's technique "for computing in the Jacobian of a hyperelliptic curve". | Bertrand 1995, abstract (the full citation is in its reference list, not yet read) | What Bertrand's efficient hyperelliptic method is built on. | Not looked for. |
| Ford and Zassenhaus, 1978, on computing the ring of integers of an algebraic number field. | van Hoeij 1994, abstract, as "[Ford,1978]"; Trager's thesis credits "Ford [20]" for the same algorithm | The number-field algorithm Trager adapted for integral bases. | Not looked for. |

---

## 4. From memory only

One item, **[memory]**: Raab's thesis *Definite Integration in Differential Fields* (RISC Linz,
2012). Reported search: the old RISC download path (`risc.jku.at/publications/download/risc_4597/`)
now returns 404 and was never archived; JKU's `epub.jku.at` put up a bot wall.

The other five leads this section once held — Fulton, Hess, Masser & Zannier, Combot, and the
second Chen et al. paper — are held.

---

## 5. What to get first

**Our ranking**, by what each would settle. The first version of this list was headed by Bronstein's
ISSAC'91 paper and Abramov's obituary, the second by Chevalley and Davenport's 1984 paper, and the
third by Miller's thesis and the FriCAS status page; all six are now held.

1. **Cantor's paper**, if the hyperelliptic case is ever built on Bertrand's method.
2. **Raab's thesis**, as a modern survey.
3. **Weil 1971**, only to cite the bound by the edition the tutorial names; the mathematics is held
   in the 1948 volumes.

Nothing on this list blocks anything. With Trager, Bronstein 1990 and 1991, the lazy-Hermite report
and the FriCAS status page all held, the algorithmic record is complete enough to work from.

Not worth chasing unless the history itself is the goal: Risch's two reports ([73], [74]) and
Bertrand's thesis ([8]). Each is hard to obtain and each is covered, for an implementer's purposes,
by something held.

## When one of these is obtained

**Check that it is the document before anything else** — §1 is why: `file`,
`pdfinfo` and a look at the first page. Then open it, and in one change: index the file in
`../downloaded-references-summary.md` §9 and in this directory's `CLAUDE.md`; move its entry out of
this file; promote the claims that rested on its citation in `what-volume-2-would-have-covered.md`
from **[cited]** to **[held]**; and update the corpus totals in `../CLAUDE.md`.
