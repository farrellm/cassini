# wolfram-language/

Wolfram's own documentation (bibliography §6). **This is the authoritative behavioral specification
the evaluator is being written against** — when the implementation and these pages disagree, the
implementation is wrong.

All files are `curl` captures of `reference.wolfram.com`, fetched 2026-08-29. They carry no CSS;
strip tags to read them (`sed -e 's/<[^>]*>/ /g' FILE | tr -s ' \n' ' \n'`).

| File | Read it for |
| :--- | :--- |
| `wolfram_ref_evaluation_of_expressions.html` | **The main document (~26k words).** The standard evaluation procedure step by step, plus the full Attributes section. Start here. |
| `wolfram_ref_evaluation.html` | The shorter guide-level overview of the same material. |
| `wolfram_ref_attributes.html` | The `Attributes` symbol page — the complete list of attribute values with their exact semantics. |
| `wolfram_guide_attributes.html` | The guide-level index of attribute-related functions. |
| `wolfram_ref_associating_definitions.html` | Transformation rules and definitions: where DownValues, UpValues, and SubValues attach, in context and with examples. |
| `wolfram_ref_downvalues.html` / `_upvalues.html` / `_subvalues.html` | The three symbol reference pages for the rule-storage model. |
| `wltools_language_spec.html` | Community reverse-engineering index. **Informed inference, not authoritative** — the kernel is closed source. Never cite it against the official pages. |

## The evaluation procedure these pages specify

Evaluate the head → apply Hold attributes (`HoldFirst` / `HoldRest` / `HoldAll` / `HoldAllComplete`)
→ strip `Unevaluated` (unless `HoldAllComplete`) → flatten `Sequence` (unless `SequenceHold`) →
apply **`Flat`**, **`Listable`**, **`Orderless`** immediately after element evaluation → apply
upvalues from the arguments, then downvalues and built-ins from the head → re-evaluate to a **fixed
point**.

Model DownValues, UpValues, and SubValues as separate rule tables keyed by symbol: DownValues attach
to a symbol as head (`f[...] := ...`), UpValues to a symbol appearing as an *argument*, SubValues to
curried heads `f[x][y]`.

`OneIdentity` affects pattern matching (treating `f[a]` as `a`) and is easy to get wrong.

`Hold`, `ReleaseHold`, `ReplacePart` and friends are **not** evaluator special cases — they fall out
of attributes plus ordinary definitions. Do not special-case them in the evaluator loop.

## Not obtained

The riptutorial "Evaluation Order" page cited in §6 no longer exists and has no Wayback snapshot;
`wolfram_ref_evaluation_of_expressions.html` covers the same ground in full. See the "Not obtained"
table in `../../downloaded-references-summary.md`.
