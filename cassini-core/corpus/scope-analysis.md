# What the out-of-scope Wolfram corpus cases are missing

A measurement, taken 2026-11-11, of which features the Wolfram documentation corpus
(`corpus/wolfram-docs/`, `DESIGN.md` §7.9, D27) asks for that cassini does not have. It is a
snapshot, not a ratchet: nothing reads this file, and the figures go stale as builtins land. It
records no decision. Where a figure bears on one, the decision is in `DESIGN.md` §11.2 under the
D-number given.

**Almost all of the corpus is out of scope because it exercises parts of the language the design
never set out to cover.** Of 111,806 cases, 882 are in scope today, and everything the design
specifies through Stage 3 brings in about 2,500.

## Method and limits

- **Scope rule.** §7.8's: a case is in scope when its status is `ok` or `partial`, it holds no
  inexact number (D9), and every `System` symbol it mentions is in `Cassini.Builtins.systemNames`.
  The analysis reads `corpus/wolfram-docs/index.tsv` (columns `status`, `inexact`, `symbols`) and
  the 95 names the registry held at commit `e3a40eed9`, dumped through `cabal repl`
  (`corpus/tools/scope_report.py`). It reproduces
  the corpus runner's 882 exactly.
- **In scope is not passing.** A case is in scope when every symbol has *a* definition. Whether
  cassini's answer matches is the ratchet's question (`corpus/passing/wolfram.txt`).
- **A case needs every symbol it mentions**, so most cases are blocked by several areas at once.
  The tables give two counts for that reason, and the cumulative table depends on its order.
- **The feature areas are name patterns written for this analysis**, one regular expression per
  area, first match wins. Area figures are approximate. 1,927 less common symbols matched no
  pattern; they touch 18,983 cases and are the sole blocker of 3,199.
- **The stages are a reading of `DESIGN.md` §10**, listed under [Symbols assumed per
  stage](#symbols-assumed-per-stage). A stage that ships a different set moves its figure.
- **`corpus/tools/scope_report.py` produces every figure here.** Its header says how to dump the
  registry's names and run it; its `STAGES` and `AREAS` tables are the stage sets and the area
  patterns.
- **Wolfram corpus only.** The Expreduce corpus (400 of 2,193 in scope) and the Mathics3 corpus
  (103 of 1,727) were not broken down.

## Where the 111,806 cases go

| Bucket | Cases |
| :--- | ---: |
| Unusable as extracted (status `unusable`: mostly graphics outputs) | 21,669 |
| Usable (`ok` 38,160, `partial` 51,977) | 90,137 |
| — holding an inexact number, excluded while D9 stands | 24,529 |
| — exact | 65,608 |

Of the 65,608 usable exact cases:

| Point in the design | In scope | With inexact cases allowed |
| :--- | ---: | ---: |
| Today | 882 | 1,024 |
| After the fidelity track and the control-flow, logic, numbers and lists track (D30, D42, D44) | 1,705 | 1,954 |
| After the elementary-functions track | 2,041 | 2,398 |
| After Stage 2 | 2,209 | 2,568 |
| After Stage 3 | 2,511 | 2,873 |
| Still out of scope with everything designed built | 63,097 | |

The second row is six above `DESIGN.md` §10's 1,699 for the control-flow track because it also
counts the fidelity track's `TerminatedEvaluation` (D30); every later row carries the same six.

Inexact numbers alone would bring little: 142 of the 24,529 inexact cases have every symbol
defined today.

## What the remaining 63,097 are missing

They mention 5,728 distinct symbols the design does not define. *Touches* counts the cases
mentioning at least one symbol of the area, and is an upper bound on what the area matters to.
*Sole blocker* counts the cases where that area, plus plain option names such as `Automatic` and
`None`, is the only thing missing, and is a lower bound on what the area alone would bring.

| Feature area | Deferred as | Touches | Sole blocker | Most frequent symbols |
| :--- | :--- | ---: | ---: | :--- |
| Graphics and plotting | | 23,773 | 4,976 | `Plot`, `Red`, `Graphics`, `PlotRange`, `Blue`, `PlotLegends`, `Mesh`, `Graphics3D` |
| Data, entities, units, dates, cloud, I/O | | 11,944 | 2,989 | `BlockchainBase`, `GraphData`, `ExampleData`, `CloudObject`, `Quantity`, `Import`, `DateObject` |
| Special functions | D21 | 8,951 | 2,367 | `Gamma`, `EllipticK`, the Bessel, hypergeometric and orthogonal-polynomial families, the inverse hyperbolics |
| Assumptions, stronger simplification, solving | D17, D18, D22 | 7,733 | 1,376 | `FullSimplify`, `Assumptions`, `FunctionExpand`, `Reduce`, `Root`, the `Function…` property tests, `Element`, `Refine` |
| Option names and values | | 6,275 | | `Automatic`, `None`, `Method` |
| Probability and statistics | | 6,142 | 797 | `RandomReal`, `RandomVariate`, `NormalDistribution`, `PDF`, `RandomInteger`, `Mean` |
| Graphs and networks | | 5,176 | 1,693 | `UndirectedEdge`, `Graph`, `VertexSize`, `GraphLayout`, `CompleteGraph`, `HighlightGraph` |
| Output forms and typesetting | | 4,912 | 460 | `MatrixForm`, `Style`, `TraditionalForm`, `Grid`, `Framed`, `Short`, `Row` |
| Linear algebra and arrays | | 4,695 | 1,044 | `Dot`, `Transpose`, `SparseArray`, `Total`, `IdentityMatrix`, `MatrixFunction`, `Det`, `Norm`, `Inverse` |
| Core language not yet designed | | 4,227 | 970 | `Span`, `Failure`, `Identity`, `Sow`, `Reap`, `Increment`, `Union`, `Tally`, `Composition`, `SortBy`, `MemberQ`, `Count`, `DeleteCases`, `AppendTo` |
| Complex numbers | D20 | 3,667 | 190 | `I`, `Re`, `Im`, `Complexes`, `Arg`, `Conjugate`, `ComplexExpand` |
| Associations and datasets | | 3,637 | 268 | `Association`, `Dataset`, `Missing` |
| Calculus beyond the design | | 3,593 | 1,078 | `DSolve`, `SeriesCoefficient`, `LaplaceTransform`, `DSolveValue`, `RSolve`, `DifferenceRoot`, `DiscreteLimit` |
| Strings and text | D34 | 3,189 | 822 | `ByteArray`, `StringJoin`, `StringExpression`, `ToString`, `ToExpression`, `StringMatchQ`, `Characters` |
| Geometry and regions | | 2,983 | 388 | `Region`, `MeshRegion` |
| Number theory and combinatorics | | 2,545 | 636 | `Prime`, `Tuples`, `PermutationGroup`, `IntegerDigits`, `EvenQ`, `FromDigits`, `PrimePi`, `EulerPhi`, `Subsets`, `Divisors` |
| Dynamic and interface | | 1,445 | 187 | `Dynamic`, `Manipulate` |
| Functions of inexact numbers | D9 | 1,400 | 92 | `N`, `Reals` |
| Images, audio, video | | 1,146 | 140 | |
| Control systems and signal processing | | 902 | 278 | `TransferFunctionModel` |
| Machine learning and optimisation | | 447 | 75 | |
| No area matched | | 18,983 | 3,199 | `BioSequence`, `LabelingFunction`, `Molecule`, `FiniteField`, `VectorPoints`, `UpTo` |

The D-numbers name the deferred decision that covers the area's centre, not all of it: D34 is
string patterns only, and D17, D18 and D22 cover assumptions and solving, not the `Function…`
property tests.

### Single symbols

The twenty most frequent missing symbols, by cases mentioning them: `Plot` 3,739, `Automatic`
3,202, `Association` 2,820, `I` 2,774, `None` 2,669, `Red` 2,526, `FullSimplify` 1,766, `Graphics`
1,759, `PlotRange` 1,519, `Blue` 1,340, `PlotLegends` 1,233, `RandomReal` 1,225, `RandomVariate`
1,222, `Mesh` 1,213, `PlotLabel` 1,088, `Graphics3D` 1,083, `NormalDistribution` 1,060,
`UndirectedEdge` 1,032, `Frame` 1,000, `BlockchainBase` 934.

The symbols that are most often the *only* one missing, which is what defining that one symbol
would bring: `GraphData` 301, `TransferFunctionModel` 178, `DSolve` 108, `Association` 98, `Plot`
92, `ExampleData` 82, `GeoPosition` 75, `ResourceData` 74, `PolyhedronData` 74, `I` 72,
`FullSimplify` 64, `Reduce` 62, `RSolve` 49, `FullForm` 48, `Definition` 43, `TraditionalForm` 42,
`CountryData` 40, `RSolveValue` 38, `WordData` 37, `FunctionSign` 36, `Trig` 36,
`SeriesCoefficient` 34, `Gamma` 29, `Span` 28.

The two lists differ because frequent symbols travel together. `I` is in 2,774 cases and is the
sole blocker of 72.

## Adding whole areas in turn

Starting from the 2,511 the design reaches, and adding every symbol of an area at once. Each row
counts only the cases whose other needs are already met, so the order matters; this one puts what
a computer algebra system would take on first.

| Add | New cases | Running total |
| :--- | ---: | ---: |
| Option names and values | 56 | 2,567 |
| Core language not yet designed | 970 | 3,537 |
| Complex numbers (D20) | 204 | 3,741 |
| Number theory and combinatorics | 733 | 4,474 |
| Linear algebra and arrays | 1,267 | 5,741 |
| Special functions (D21) | 2,770 | 8,511 |
| Assumptions, stronger simplification, solving | 4,226 | 12,737 |
| Calculus beyond the design | 1,912 | 14,649 |
| Strings and text | 968 | 15,617 |
| Associations and datasets | 473 | 16,090 |
| Output forms and typesetting | 1,069 | 17,159 |
| Probability and statistics | 1,596 | 18,755 |
| Graphs and networks | 2,631 | 21,386 |
| Graphics and plotting | 12,435 | 33,821 |
| Data, entities, units, dates, cloud, I/O | 7,292 | 41,113 |

The 24,495 exact cases left after the last row need a symbol from an area not in the list
(geometry, interface, images, control systems, machine learning, the inexact-number functions) or
one that matched no area.

Graphics and curated data, the two largest areas, are outside what a term-rewriting kernel takes
on.

## What would pay, for a CAS

A reading of the figures above, not a decision; nothing here is scheduled. It takes the eight areas
a computer algebra system would take on and sets, for each, what it brings alone against what it
brings in the order of the last table.

| Area | Alone, on top of the design | In turn | What it is |
| :--- | ---: | ---: | :--- |
| Core language not yet designed | 970 | 970 | Builtins of kinds the kernel already has: `Span`, `Sow`/`Reap`, `Increment`, `Union`, `Tally`, `MemberQ`, `Count`, `SortBy`, `DeleteCases`, `AppendTo` |
| Complex numbers (D20) | 190 | 204 | A number representation, then `Re`, `Im`, `Arg`, `Conjugate` |
| Number theory and combinatorics | 636 | 733 | Integer functions over the existing substrate: `Prime`, `IntegerDigits`, `EulerPhi`, `Divisors`, `Tuples`, `Subsets` |
| Linear algebra and arrays | 1,044 | 1,267 | `Dot`, `Transpose`, `Det`, `Inverse`, `IdentityMatrix`; `MatrixForm` is in 778 cases and is output only |
| Special functions (D21) | 2,367 | 2,770 | Many families, each with its own special values and identities |
| Assumptions, stronger simplification, solving | 1,376 | 4,226 | `FullSimplify`, `Assumptions`, `Reduce`, `Root`, `Refine` |
| Calculus beyond the design | 1,078 | 1,912 | `DSolve`, `RSolve`, the integral transforms |
| Strings and text | 822 | 968 | String functions and string patterns (D34) |

*Alone* is the area's sole-blocker count from the area table, so it allows the option names too.

- **The core-language builtins are the cheapest cases in the corpus.** They need no new
  mathematics and no new representation, and they bring 970 cases, more than the elementary
  track (336) or Stages 2 and 3 together (470) add to scope.
- **Special functions bring the most alone**, 2,367, but are the widest area: the cases spread
  over dozens of families, and `Gamma`, the most frequent, is the sole blocker of 29.
- **Assumptions and stronger simplification depend most on the rest.** Alone they bring 1,376;
  after complex numbers, linear algebra and special functions they bring 4,226, the largest step
  in the table. `FullSimplify` is in 1,766 cases and the only thing missing in 64, because the
  documentation uses it to tidy answers about something else.
- **Complex numbers are an enabler, not a source of cases.** `I` is in 2,774 cases, yet the whole
  area brings about 200, because a case with `I` usually also wants a special function or
  `FullSimplify`. Its worth is in the two rows after it.
- **Inexact numbers pay little by themselves** (D9): 142 cases today, and 362 with everything
  through Stage 3 built.
- **Together the first seven areas take scope from 2,511 to 14,649**, about a fifth of the corpus's
  usable exact cases, and strings to 15,617. The rest is graphics, curated data, and areas with a
  library's worth of their own content (statistics, graphs, geometry).

Two cautions on reading this as a plan. Scope is not passing: a case in scope still has to print
WL's form of the answer, and the areas that bring the most scope here (`FullSimplify`, special
functions, `DSolve`) are the ones where matching that form is hardest. And the corpus is
documentation examples, so it measures what Wolfram chose to illustrate, not what users of a CAS
ask for.

## Symbols assumed per stage

The sets added to the registry's 95 names for the "point in the design" table.

- **Fidelity track, and the control-flow, logic, numbers and lists track:** `If`, `Which`, `Switch`, `Module`, `Block`,
  `With`, `Catch`, `Throw`, `Do`, `While`, `For`, `Until`, `Scan`, `Table`, `Nest`, `NestList`,
  `Fold`, `FoldList`, `FixedPoint`, `Break`, `Continue`, `Return`, `Abort`, `Sum`, `Product`,
  `Print`, `Clear`, `ClearAll`, `Equal`, `Unequal`, `Less`, `Greater`, `LessEqual`,
  `GreaterEqual`, `SameQ`, `UnsameQ`, `TrueQ`, `And`, `Or`, `Not`, `Abs`, `Sign`, `Floor`,
  `Ceiling`, `Round`, `Mod`, `Quotient`, `GCD`, `LCM`, `Binomial`, `Factorial`, `Max`, `Min`,
  `PrimeQ`, `FactorInteger`, `Numerator`, `Denominator`, `Flatten`, `Partition`, `Array`,
  `ReplacePart`, `Range`, `MapAt`, `Extract`, `Take`, `Drop`, `Thread`, `MapThread`, `Position`,
  `MapIndexed`, `Riffle`, `Select`, `Sort`, `First`, `Last`, `Rest`, `Most`, `Join`, `Append`,
  `Prepend`, `Reverse`, `Message`, `MessageName`, `Quiet`, `Check`, `Off`, `On`, `General`,
  `TerminatedEvaluation`.
- **Elementary-functions track:** `Sin`, `Cos`, `Tan`, `Cot`, `Sec`, `Csc`, `Sinh`, `Cosh`,
  `Tanh`, `Coth`, `Sech`, `Csch`, `ArcSin`, `ArcCos`, `ArcTan`, `ArcCot`, `ArcSec`, `ArcCsc`,
  `Exp`, `Log`, `Pi`, `E`, `TrigExpand`, `TrigReduce`, `Simplify`, `Expand`.
- **Stage 2:** `ExpandAll`, `Collect`, `Cancel`, `Factor`, `Together`, `Apart`, `PolynomialGCD`,
  `Coefficient`, `Exponent`, `Variables`, `Resultant`, `Discriminant`, `FactorSquareFree`,
  `Modulus`.
- **Stage 3:** `GroebnerBasis`, `PolynomialReduce`, `Solve`, `Integrate`, `Series`, `Normal`,
  `Limit`, `RootSum`, `SeriesData`, `O`.
