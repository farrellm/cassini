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
| `wolfram_ref_downvalues.html` / `_upvalues.html` / `_subvalues.html` | The three symbol reference pages for the rule-storage model. **Thin captures** — roughly 13 KB of text each, almost all navigation chrome; only the one-line definitions survived and the "Details" sections did not. Use `wolfram_ref_evaluation_of_expressions.html` for anything substantive. (`OwnValues` has no capture here; it is a "See Also" sibling on all three.) |
| `wltools_language_spec.html` | Community reverse-engineering index. **Informed inference, not authoritative** — the kernel is closed source. Never cite it against the official pages. |

## The evaluation procedure these pages specify

**The documentation's own canonical list**, verbatim from *Evaluation of Expressions*: evaluate the
head → evaluate each element in turn → apply the transformations associated with **`Orderless`,
`Listable`, and `Flat`** → apply *any definitions you have given* → apply *any built-in definitions*
→ evaluate the result. That last step is the **fixed point**.

Two precedence rules are stated explicitly, and they are orthogonal — don't collapse them into one
list. **Upvalues before downvalues** ("the Wolfram System always tries upvalue definitions before
downvalue ones"), and **user definitions before built-in ones**. For `f[g[x]]` the full order is:
your definitions on `g` → built-in definitions on `g` → your definitions on `f` → built-in
definitions on `f`.

Everything else an implementer needs — holding arguments under the `Hold*` attributes, stripping
`Unevaluated`, splicing `Sequence` unless `SequenceHold`, and whether `Flat` runs before `Orderless`
sorting — is documented **piecewise** under Attributes and Non-Standard Evaluation and is never
given as an ordered algorithm. Any linearization of it is reconstruction; validate it against a real
kernel before trusting it.

Model OwnValues, DownValues, UpValues, and SubValues as four separate rule tables keyed by symbol:
OwnValues is the symbol's own value (`x = 5`), DownValues attach to a symbol as head
(`f[...] := ...`), UpValues to a symbol appearing as an *argument*, SubValues to curried heads —
"values for `f[…][…]…`". Don't skip OwnValues; it is what makes plain assignment fall out of the
same machinery.

`OneIdentity` affects pattern matching (treating `f[a]` as `a`) and is easy to get wrong.

`Hold`, `HoldComplete`, `HoldForm`, `ReleaseHold` and `Unevaluated` are **not** evaluator special
cases — they fall out of attributes plus ordinary definitions (`Unevaluated[expr]` "effectively
works by temporarily giving a function an attribute like `HoldFirst`"). Do not special-case them in
the evaluator loop.

## Not obtained

The riptutorial "Evaluation Order" page cited in §6 no longer exists and has no Wayback snapshot;
`wolfram_ref_evaluation_of_expressions.html` covers the same ground in full. See the "Not obtained"
table in `../../downloaded-references-summary.md`.
