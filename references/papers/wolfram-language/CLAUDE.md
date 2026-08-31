# wolfram-language/

Wolfram's own documentation (bibliography §6). **This is the authoritative behavioral specification
the evaluator is being written against** — when the implementation and these pages disagree, the
implementation is wrong.

All files are `curl` captures of `reference.wolfram.com`, fetched 2026-08-29. They carry no CSS;
strip tags to read them (`sed -e 's/<[^>]*>/ /g' FILE | tr -s ' \n' ' \n'`).

| File | Read it for |
| :--- | :--- |
| `wolfram_ref_evaluation.html` | **The algorithm.** Its section "The Standard Evaluation Sequence" is the complete ordered procedure — 12 numbered steps on the page, transcribed below as 13 (see the numbering note).  Short page, but it is the spec; start here. |
| `wolfram_ref_evaluation_of_expressions.html` | **The explanations (~26k words).** A coarser six-step summary of the same procedure, the full attribute table, worked evaluation traces, and the prose precedence rules. The companion read, not the algorithm. |
| `wolfram_ref_associating_definitions.html` | Transformation rules and definitions: where DownValues, UpValues, and SubValues attach, in context and with examples. |
| `wolfram_ref_ownvalues.html` / `_downvalues.html` / `_upvalues.html` / `_subvalues.html` | The four symbol reference pages for the rule-storage model. **Thin captures** — roughly 13 KB of text each, almost all navigation chrome; only the one-line definitions survived and the "Details" sections did not. Use `wolfram_ref_associating_definitions.html` (55 KB of real text) for the model in context, and `wolfram_ref_evaluation_of_expressions.html` for precedence. |
| `wolfram_ref_attributes.html` / `wolfram_guide_attributes.html` | **Do not go here for the attribute list.** Both are thin captures: the ref page has only the `Attributes[symbol]` signatures plus bare section labels (its "Details" did not capture), and the guide page is a list of links. **The full attribute table — `Orderless`, `Flat`, `OneIdentity`, `Listable`, `Constant`, `Protected`, `SequenceHold`, the `Hold*` and `NHold*` families, each with its one-line meaning — is in `wolfram_ref_evaluation_of_expressions.html`.** |
| `wltools_language_spec.html` | Community reverse-engineering index. **Informed inference, not authoritative** — the kernel is closed source. Never cite it against the official pages. |

## The evaluation procedure these pages specify

**`wolfram_ref_evaluation.html` carries the whole algorithm in order**, under the heading "The
Standard Evaluation Sequence". Implement it literally. For `h[e1, e2, …]`:

**Numbering.** The page numbers *twelve* steps. The transcription below splits its step 3
("Evaluate each element `eᵢ` in turn. If `h` is a symbol with attributes HoldFirst, …, then skip
evaluation of certain elements") into two, because the hold check is a separate thing to implement.
Steps 1–3 below are the page's 1–3; from step 4 on, **the page's number is one lower than ours**.
Every step reference in this repo uses our numbering.

1. If the expression is a raw object (`Integer`, `String`, …), leave it unchanged.
2. Evaluate the head `h`.
3. Evaluate each element `eᵢ` in turn.
4. If `h` has `HoldFirst` / `HoldRest` / `HoldAll` / `HoldAllComplete`, skip evaluation of certain
   elements.
5. Unless `h` has `SequenceHold` or `HoldAllComplete`, flatten out all `Sequence` objects among the
   `eᵢ`.
6. Unless `h` has `HoldAllComplete`, strip the outermost of any `Unevaluated` wrappers among the `eᵢ`.
7. If `h` has `Flat`, flatten out all nested expressions with head `h`.
8. If `h` has `Listable`, thread through any `eᵢ` that are lists.
9. If `h` has `Orderless`, sort the `eᵢ` into order.
10. Unless `h` has `HoldAllComplete`, use any applicable rules **you have defined** for `h[f[e1,…],…]`.
11. Use any **built-in** rules associated with `f` for `h[f[e1,…],…]`.
12. Use any applicable rules **you have defined** for `h[e1,e2,…]` or `h[…][…]`.
13. Use any **built-in** rules for `h[e1,e2,…]` or `h[…][…]`.

Then the **fixed point**: "every time the expression changes, the Wolfram Language effectively starts
the evaluation sequence over again."

Three easy mistakes the sequence rules out. Attribute order is **`Flat` → `Listable` → `Orderless`**
(steps 7–9) — flattening must precede the canonical sort, and the coarser bullet list in
*Evaluation of Expressions* that names them in a different order is a summary, not the order.
`Sequence` splicing precedes `Unevaluated` stripping (steps 5–6). And rule application is a
**four-way ladder** (steps 10–13), not two independent axes: user upvalues → built-in upvalues →
user downvalues → built-in downvalues, so **built-in upvalues beat *user* downvalues**. `SubValues`
ride along with downvalues in steps 12–13, which is why `h[…][…]` appears there.

One inconsistency in the source worth knowing: its step 11 (our 12) reads `h[f[e1,e2,…],…]` where
its step 12 (our 13) reads `h[e1,e2,…]`. That is an error on Wolfram's page — the downvalue form
`h[e1,e2,…]` transcribed above is the semantically right one.

Model OwnValues, DownValues, UpValues, and SubValues as four separate rule tables keyed by symbol:
OwnValues is the symbol's own value (`x = 5`), DownValues attach to a symbol as head
(`f[...] := ...`), UpValues to a symbol appearing as an *argument*, SubValues to curried heads —
"values for `f[…][…]…`". Don't skip OwnValues; it is what makes plain assignment fall out of the
same machinery.

`OneIdentity` affects pattern matching — "`f[f[a]]`, etc. are equivalent to `a` for pattern matching" — and is easy to get wrong.

`Hold`, `HoldComplete`, `HoldForm`, `ReleaseHold` and `Unevaluated` are **not** evaluator special
cases — they fall out of attributes plus ordinary definitions (`Unevaluated[expr]` "effectively
works by temporarily giving a function an attribute like `HoldFirst`"). Do not special-case them in
the evaluator loop.

## Not obtained

The riptutorial "Evaluation Order" page cited in §6 no longer exists and has no Wayback snapshot;
`wolfram_ref_evaluation_of_expressions.html` covers the same ground in full. See the "Not obtained"
table in `../../downloaded-references-summary.md`.
