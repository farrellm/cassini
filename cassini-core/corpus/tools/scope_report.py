#!/usr/bin/env python3
"""Report what the out-of-scope cases of a corpus are missing (DESIGN.md §7.8).

    scope_report.py NAMES [INDEX]

NAMES is a file of the System symbols the registry defines, one per line.
Cassini.Builtins.systemNames is the source; from the repository root:

    printf '%s\n' 'import qualified Data.HashSet as HS' \
        'import qualified Data.Text.IO as TIO' \
        'import Cassini.Builtins (systemNames)' \
        'mapM_ TIO.putStrLn (HS.toList systemNames)' ':quit' \
      | cabal repl -v0 lib:cassini-core | grep -E '^[$A-Za-z]+$' | sort -u > NAMES

INDEX is an extractor's index.tsv, by default corpus/wolfram-docs/index.tsv
relative to the working directory. Only its status, inexact and symbols
columns are read.

The scope rule is §7.8's, as corpus/Test/Corpus/Case.hs applies it: a case is
in scope when its status is ok or partial, it holds no inexact number (D9),
and every System symbol it mentions is in NAMES. The first figure printed
under "in scope" should equal what cassini-corpus reports for the source.

The report has four parts: the buckets; the cases in scope after each stage
of the design, taking STAGES below as what each stage defines; the cases
still out of scope after the last stage, by feature area and by symbol; and
the cases gained by adding whole areas in ORDER.

A case needs every symbol it mentions. So for an area, "touches" counts the
cases mentioning at least one of its symbols, and "sole" the cases where it,
with the plain option names of NEUTRAL, is the only area missing.

STAGES is a reading of DESIGN.md §10 and wants updating as the milestones
change. AREAS is one regular expression per area, searched in order with the
first match winning; the patterns are heuristics over symbol names, so area
figures are approximate, and a symbol matching none is "uncategorized".

corpus/scope-analysis.md is this script's output of 2026-11-11, written up.
"""

import collections
import csv
import re
import sys

STAGES = [
    (
        "fidelity track; control flow, logic, numbers and lists track",
        """
        If Which Switch Module Block With Catch Throw Do While For Until Scan Table Nest
        NestList Fold FoldList FixedPoint Break Continue Return Abort Sum Product Print Clear
        ClearAll Equal Unequal Less Greater LessEqual GreaterEqual SameQ UnsameQ TrueQ And Or
        Not Abs Sign Floor Ceiling Round Mod Quotient GCD LCM Binomial Factorial Max Min PrimeQ
        FactorInteger Numerator Denominator Flatten Partition Array ReplacePart Range MapAt
        Extract Take Drop Thread MapThread Position MapIndexed Riffle Select Sort First Last
        Rest Most Join Append Prepend Reverse Message MessageName Quiet Check Off On General
        TerminatedEvaluation
        """,
    ),
    (
        "elementary-functions track",
        """
        Sin Cos Tan Cot Sec Csc Sinh Cosh Tanh Coth Sech Csch ArcSin ArcCos ArcTan ArcCot ArcSec
        ArcCsc Exp Log Pi E TrigExpand TrigReduce Simplify Expand
        """,
    ),
    (
        "Stage 2",
        """
        ExpandAll Collect Cancel Factor Together Apart PolynomialGCD Coefficient Exponent
        Variables Resultant Discriminant FactorSquareFree Modulus
        """,
    ),
    (
        "Stage 3",
        """
        GroebnerBasis PolynomialReduce Solve Integrate Series Normal Limit RootSum SeriesData O
        """,
    ),
]

AREAS = [
('graphics & plotting',r'Plot|Chart|Graphics|Legend|^(Red|Blue|Green|Black|White|Gray|Yellow|Orange|Pink|Purple|Brown|Cyan|Magenta|Light\w+|Dark\w+|Hue|RGBColor|GrayLevel|Opacity|Thick|Thin|Dashed|Dotted|DotDashed|Dashing|Thickness|PointSize|AbsolutePointSize|AbsoluteThickness|Directive|Line|Point|Disk|Circle|Rectangle|Polygon|Triangle|Sphere|Ball|Cuboid|Cylinder|Cone|Tube|Arrow|Arrowheads|Text|Inset|Show|Epilog|Prolog|Axes|AxesLabel|AxesOrigin|Axis|Frame|FrameLabel|FrameTicks|Ticks|Filling|FillingStyle|Mesh|MeshFunctions|MeshShading|MeshStyle|Contours|ColorFunction|ColorData|ColorFunctionScaling|Lighting|ViewPoint|Boxed|BoxRatios|AspectRatio|ImageSize|Background|Exclusions|Joined|EdgeForm|FaceForm|Glow|Specularity|Tooltip|Labeled|Callout|Placed|ScalingFunctions|Raster|Texture|GridLines|BaseStyle|LabelStyle|Bottom|Top|Left|Right|Center|Above|Below|Before|After|Tiny|Small|Medium|Large|Full|Scaled|Offset|Rotate|Translate|Scale|GeometricTransformation|Blend|Lighter|Darker|InterpolationOrder|PerformanceGoal|MaxRecursion|ClippingStyle|BoundaryStyle|RegionFunction|Interpolation\w*|Animate|ListAnimate)$'),
('images, audio, video',r'^Image|Audio|Video|Sound|Colorize|Binarize|ColorConvert|Camera'),
('geometry & regions',r'Region|MeshRegion|Mesh\w+|Geometr|ConvexHull|Voronoi|Delaunay|Polyhedron|Simplex|Hyperplane|HalfSpace|InfiniteLine|Annulus|Ellipsoid|Parallelogram|Tetrahedron|Hexahedron|Prism|Pyramid|Area|Volume|ArcLength|Perimeter|Triangulat'),
('graphs & networks',r'Graph|Vertex|Edge|^Cycles$|Tree|Path|Network|Adjacency|Incidence|Clique|Isomorph|Coloring|Flow$|ShortestPath|Neighborhood|Connected'),
('strings & text',r'String|Character|^ToString$|^ToExpression$|Text\w+|Word|Letter|RegularExpression|^Alphabet$|ToUpperCase|ToLowerCase|Capitalize|Hyphenation|Sentence|Language|Transliterate|^Hash$|Encode|Decode|Compress|Uncompress|ByteArray|Base64'),
('associations & datasets',r'Association|^Key|Lookup|Dataset|^Counts|GroupBy|Merge|Tabular|^Missing$|Query|^Values$|AssociateTo|Normal$'),
('data, entities, units, dates, cloud, I/O',r'Data$|Entity|Quantity|Unit|Date|Time|Geo|Cloud|Resource|Import|Export|File|Directory|URL|HTTP|Blockchain|Database|SQL|External|Process|Notebook|Cell|Wolfram|Interpreter|Semantic|Service|Send|Channel|Link|Socket|Device|Stream|^Read|^Write|^Get$|^Put$|Save|Open|Close|Paclet|Kernel|Parallel|Remote|Task|Session|System|Environment|\$\w+'),
('probability & statistics',r'Random|Distribution|^(Mean|Variance|StandardDeviation|Median|Quantile|PDF|CDF|Expectation|Probability|Covariance|Correlation|Moment|Kurtosis|Skewness|Likelihood|Histogram|SeedRandom|BlockRandom|Fit|LinearModelFit|NonlinearModelFit|FindFit|Estimat\w+|Hypothesis\w+|\w+Test|Sample|Process)$|Process$|Estimat|TimeSeries|Survival|Hazard'),
('complex numbers',r'^(I|Re|Im|Complex|Conjugate|Arg|ReIm|AbsArg|ComplexExpand|Complexes|Sign|Abs)$'),
('inexact numerics',r'^(N|NSolve|NIntegrate|FindRoot|NDSolve|NDSolveValue|NMinimize|NMaximize|FindMinimum|FindMaximum|NSum|NProduct|Chop|Rationalize|Precision|Accuracy|MachinePrecision|WorkingPrecision|PrecisionGoal|AccuracyGoal|SetPrecision|SetAccuracy|Real|Reals|Round|RealDigits|Interval|\$MachineEpsilon|NLimit|ND|NSeries|NArgMin|NArgMax|NMinValue|NMaxValue|NExpectation|NProbability|NDEigen\w+|Rescale|Clip)$'),
('linear algebra & arrays',r'Matrix|^(Dot|Transpose|Det|Inverse|Tr|Eigen\w+|LinearSolve|NullSpace|RowReduce|Cross|Norm|Normalize|Outer|Inner|KroneckerProduct|SparseArray|ConstantArray|Dimensions|ArrayDepth|TensorRank|TensorProduct|TensorContract|Total|Accumulate|Differences|ArrayReshape|ArrayFlatten|Diagonal|UpperTriangularize|LowerTriangularize|Symmetrize|LeviCivitaTensor|UnitVector|Projection|Orthogonalize|SingularValue\w+|\w+Decomposition|LeastSquares|PseudoInverse|Minors|Permanent|CharacteristicPolynomial|ConjugateTranspose|ArrayPad|ListConvolve|ListCorrelate|ArrayQ|VectorQ|Vectors|Matrices|Arrays|Rotate\w+|Band|NumericArray|Fourier\w*|InverseFourier\w*)$'),
('special functions (D21)',r'Gamma|Beta|Bessel|Elliptic|Hypergeometric|Zeta|^Erf|Erfc|PolyLog|Legendre|Chebyshev|Hermite|Laguerre|Gegenbauer|Jacobi|Airy|Struve|Mathieu|Spheroidal|Whittaker|Parabolic|Hankel|Kelvin|Lerch|Stieltjes|Polygamma|PolyGamma|Pochhammer|Factorial2|Subfactorial|ExpIntegral|SinIntegral|CosIntegral|LogIntegral|Fresnel|Dawson|ProductLog|LambertW|Sinc|Haversine|Gudermannian|Spherical\w+|MeijerG|FoxH|Heun|Lame|Carlson|Weierstrass|Modular|Dedekind|Klein|Theta|QPochhammer|QGamma|QBinomial|ArcSinh|ArcCosh|ArcTanh|ArcCoth|ArcSech|ArcCsch|Degrees$|Catalan|EulerGamma|GoldenRatio|Glaisher|Khinchin|Degree$|Fibonacci|LucasL|Bernoulli|Euler[EN]|Stirling|Harmonic|Barnes|Riemann|Dirichlet|Ramanujan'),
('assumptions, simplification, logic, solving beyond the design',r'^(FullSimplify|Assumptions|Assuming|\$Assumptions|Refine|Reduce|Element|NotElement|Integers|Rationals|Primes|Algebraics|Booleans|FunctionExpand|PowerExpand|ExpToTrig|TrigToExp|TrigFactor|Trig|Piecewise|PiecewiseExpand|ConditionalExpression|Boole|UnitStep|HeavisideTheta|DiracDelta|KroneckerDelta|DiscreteDelta|Root|RootReduce|ToRadicals|Roots|SolveValues|NSolveValues|FindInstance|Resolve|ForAll|Exists|Implies|Xor|Nand|Nor|Equivalent|BooleanMinimize|BooleanConvert|BooleanFunction|BooleanTable|LogicalExpand|Minimize|Maximize|MinValue|MaxValue|ArgMin|ArgMax|Eliminate|SolveAlways|ComplexityFunction|TransformationFunctions|AlgebraicNumber|MinimalPolynomial|Extension|GaussianIntegers|Function(Sign|Domain|Range|Convexity|Monotonicity|Analytic|Continuous|Singularities|Discontinuities|Poles|Period|Injective|Surjective|Bijective|Meromorphic)|Inactive|Activate|Inactivate|HoldForm|Simplify)$|Inequalit'),
('calculus beyond the design',r'^(DSolve\w*|RSolve\w*|\w*Transform|\w+Coefficient|Residue|Asymptotic\w*|Difference\w+|DiscreteLimit|DiscreteRatio|Dt|Grad|Div|Curl|Laplacian|Hessian|Wronskian|Casoratian|ArcCurvature|FrenetSerret\w*|Variational\w+|EulerEquations|Convolve|DiscreteConvolve|MaxLimit|MinLimit|Direction|GenerateConditions|PrincipalValue|Regularization|NIntegrate|ContinuedFraction\w*|Convergents|SumConvergence|PadeApproximant|InverseSeries|ComposeSeries|SeriesCoefficient|D|Derivative|DifferentialRoot|DifferenceRoot|Green\w+|NeumannValue|DirichletCondition|PeriodicBoundaryCondition|CompleteIntegral|DEigen\w+|SawtoothWave|SquareWave|TriangleWave|UnitBox|UnitTriangle)$'),
('number theory & combinatorics',r'^(Prime\w*|Divisor\w*|EulerPhi|MoebiusMu|JacobiSymbol|KroneckerSymbol|PowerMod|ModularInverse|ChineseRemainder|ExtendedGCD|IntegerDigits|FromDigits|DigitCount|IntegerLength|IntegerExponent|IntegerPart|FractionalPart|IntegerQ|EvenQ|OddQ|CoprimeQ|SquareFreeQ|PerfectNumber\w*|NextPrime|PrimePi|PrimeOmega|PrimeNu|Multinomial|Permutations|Subsets|Tuples|IntegerPartitions|Partitions\w+|Signature|Permut\w+|Cycles|Permutation\w+|\w+Group\w*|Group\w+|Orderings|BellB|CatalanNumber|PolygonalNumber|IntegerName|RomanNumeral|NumberDigit|BitAnd|BitOr|BitXor|BitNot|BitShift\w+|BaseForm|MixedRadix|RealDigits|LinearRecurrence|RecurrenceTable|FindSequenceFunction|FindLinearRecurrence|DivisorSigma|Divisible|Unitize|Ramp)$'),
('output forms & typesetting',r'Form$|^(Short|Shallow|Row|Column|Grid|TableForm|Style|Framed|Panel|Item|Spacer|Invisible|Pane|Highlighted|Subscript|Superscript|Subsuperscript|Overscript|Underscript|OverBar|OverHat|OverTilde|OverVector|Defer|Interpretation|Format|MakeBoxes|ToBoxes|RawBoxes|DisplayForm|\w+Box|Magnify|Bold|Italic|FontSize|FontFamily|FontColor|FontWeight|FontSlant|Alignment|Spacings|Dividers|ItemSize|ItemStyle|TableHeadings|Print|Echo|Definition|Information|FullDefinition|NumberForm|ScientificForm|EngineeringForm|AccountingForm|PaddedForm|Multicolumn|TextGrid|Skeleton|Iconize|OpenerView|TabView|MenuView|SlideView|FlipView|Graphics\w*|Hyperlink|Button|Mouseover)$'),
('dynamic & interface',r'Dynamic|Manipulat|Slider|Control|Locator|Setter|Checkbox|Popup|InputField|Toggler|Trigger|Animator|Dialog|Notebook|FrontEnd|Clock|Refresh|EventHandler|Mouse|Deploy|Interactive'),
('options & option values',r'^(Automatic|None|All|Method|Inherited|Options|SetOptions|OptionValue|OptionsPattern|FilterRules|Default|True|False|Null|Infinity|ComplexInfinity|Heads|Evaluated|Listable)$'),
('machine learning & optimization',r'Net|Classif|Predict|Learn|Cluster|Train|Neural|Feature|Dimension(Reduc)|Linear(Optim|Program)|Quadratic(Optim)|Convex|Conic|Semidefinite|Optimiz'),
('control systems & signal',r'TransferFunction|StateSpace|System(s)?Model|Filter|Bode|Nyquist|Controllab|Observab|Feedback|Wavelet|Signal|Spectro|Periodogram|^Z?Transform'),
('language core not yet designed',r'^(Dispatch|Definition|UpValues|DownValues|OwnValues|SubValues|DefaultValues|NValues|FormatValues|Names|Context\w*|Begin\w*|End\w*|Needs|Unique|Symbol\w*|ValueQ|AtomQ|NumberQ|NumericQ|ListQ|IntegerQ|StringQ|MemberQ|Count|Total|Sow|Reap|Composition|RightComposition|Identity|Through|Operate|Comap|ComapApply|MapApply|ApplyTo|Curry|OperatorApplied|ReverseApplied|Construct|Splice|Nothing|Delete|Insert|AppendTo|PrependTo|Increment|Decrement|PreIncrement|PreDecrement|AddTo|SubtractFrom|TimesBy|DivideBy|Set\w*|Unevaluated|ReleaseHold|Evaluate|Hold\w*|Inactive|Trace\w*|Timing|AbsoluteTiming|TimeConstrained|MemoryConstrained|Pause|Compile\w*|Function\w*|Slot\w*|Span|Part|Sequence\w*|Subsequences|Split\w*|Gather\w*|Tally|Union|Intersection|Complement|DeleteDuplicates\w*|DeleteCases|SelectFirst|FirstCase|FirstPosition|Pick|TakeWhile|DropWhile|LengthWhile|NestWhile\w*|FixedPointList|FoldPair\w*|Accumulate|Ordering|SortBy|ReverseSort\w*|Max\w+|Min\w+|TakeLargest\w*|TakeSmallest\w*|Level|Depth|LeafCount|ByteCount|Replace\w*|Rule\w*|Pattern\w*|Condition|Alternatives|Repeated\w*|Longest|Shortest|Optional|OrderlessPatternSequence|KeyValuePattern|Except|Verbatim|Blank\w*|MatchQ|FreeQ|SubsetQ|ContainsAll|ContainsAny|ContainsNone|ContainsOnly|DuplicateFreeQ|OrderedQ|Order|Equal|SameQ|AllTrue|AnyTrue|NoneTrue|Table|Do|Iterate\w*|Subdivide|Catenate|Transpose|Thread|MapThread|Outer|Inner|Distribute|Array\w*|PadLeft|PadRight|Padding|RotateLeft|RotateRight|Reverse|Riffle|Partition\w*|Flatten\w*|Tuples|ConstantArray|Failure|Success|Enclose|Confirm\w*|Throw|Catch|Abort\w*|Check\w*|Interrupt|Return|Goto|Label|Assert|On|Off|Switch|Which|PositionIndex|Characters|TreeForm|Head|Position|Cases|Count|Apply|Map|Scan|ReplaceAt|ApplyTo|Indexed|Ordering|Normal)$'),
]

NEUTRAL = {"options & option values"}

ORDER = [
    "options & option values",
    "language core not yet designed",
    "complex numbers",
    "number theory & combinatorics",
    "linear algebra & arrays",
    "special functions (D21)",
    "assumptions, simplification, logic, solving beyond the design",
    "calculus beyond the design",
    "strings & text",
    "associations & datasets",
    "output forms & typesetting",
    "probability & statistics",
    "graphs & networks",
    "graphics & plotting",
    "data, entities, units, dates, cloud, I/O",
]

# The areas whose most frequent symbols are worth listing.
DETAIL = ORDER[1:9]


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as f:
        defined = set(f.read().split())
    index = sys.argv[2] if len(sys.argv) == 3 else "corpus/wolfram-docs/index.tsv"
    with open(index, encoding="utf-8") as f:
        rows = list(csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE))

    def symbols(row):
        return set(filter(None, row["symbols"].split(",")))

    usable = [r for r in rows if r["status"] in ("ok", "partial")]
    inexact = [r for r in usable if r["inexact"] != "0"]
    exact = [r for r in usable if r["inexact"] == "0"]
    status = collections.Counter(r["status"] for r in rows)
    print(f"cases {len(rows)}: " + ", ".join(f"{k} {v}" for k, v in sorted(status.items())))
    print(f"usable {len(usable)}: inexact {len(inexact)}, exact {len(exact)}")
    print(f"inexact with every symbol defined: {sum(symbols(r) <= defined for r in inexact)}")

    # What each case still needs, beyond the registry.
    missing = [symbols(r) - defined for r in exact]
    missing_all = [symbols(r) - defined for r in usable]

    def within(have, sets):
        return sum(m <= have for m in sets)

    print("\nin scope (exact; with inexact cases allowed)")
    have = set()
    print(f"  {within(have, missing):6d} {within(have, missing_all):6d}  today")
    for name, text in STAGES:
        have |= set(text.split())
        print(f"  {within(have, missing):6d} {within(have, missing_all):6d}  + {name}")

    rest = [m - have for m in missing if not m <= have]
    freq = collections.Counter(s for m in rest for s in m)
    sole = collections.Counter(next(iter(m)) for m in rest if len(m) == 1)
    print(f"\nstill out of scope: {len(rest)} cases, {len(freq)} distinct missing symbols")
    print("most frequent:", ", ".join(f"{s} {k}" for s, k in freq.most_common(40)))
    print("most often the only one missing:", ", ".join(f"{s} {k}" for s, k in sole.most_common(40)))

    patterns = [(name, re.compile(p)) for name, p in AREAS]
    cache = {}

    def area(symbol):
        if symbol not in cache:
            cache[symbol] = next((n for n, p in patterns if p.search(symbol)), "uncategorized")
        return cache[symbol]

    areas = [{area(s) for s in m} for m in rest]
    touches = collections.Counter(a for c in areas for a in c)
    alone = collections.Counter(next(iter(c - NEUTRAL)) for c in areas if len(c - NEUTRAL) == 1)
    print(f"\n{'area':62s} touches   sole")
    for a, k in touches.most_common():
        print(f"{a:62s} {k:7d} {alone[a]:6d}")

    def top(a, k):
        symbols_of = collections.Counter({s: n for s, n in freq.items() if area(s) == a})
        return ", ".join(f"{s} {n}" for s, n in symbols_of.most_common(k))

    print(f"\nuncategorized symbols: {sum(area(s) == 'uncategorized' for s in freq)}")
    print("  " + top("uncategorized", 40))
    for a in DETAIL:
        print(f"{a}:\n  " + top(a, 22))

    base = within(have, missing)
    print(f"\nadding whole areas in turn, from {base}")
    added, previous = set(), 0
    for a in ORDER:
        added.add(a)
        k = sum(c <= added for c in areas)
        print(f"  {a:62s} +{k - previous:6d} -> {base + k}")
        previous = k


if __name__ == "__main__":
    main()
