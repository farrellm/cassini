-- | The surface syntax: FullForm and the infix syntax each read back what
-- they print (DESIGN.md §4.10, §7.3's @Syntax@ row), and the infix parser
-- reads what WL's does.
module Test.Cassini.Syntax (tests) where

import Cassini.Core.Expr (Expr, apply, mkApp, mkSymbol)
import Cassini.Core.Symbol (Symbol, symbol, systemSymbol)
import Cassini.Script (resolveName)
import Cassini.Syntax.FullForm (fullForm, parseFullForm)
import Cassini.Syntax.Parser (incomplete, parseExpr)
import Cassini.Syntax.Pretty (pretty)
import Data.HashSet qualified as HashSet
import Data.Vector qualified as V
import Test.Gen (fn, genExpr, int, rat, shrinkExpr, str, sym)
import Test.QuickCheck (Gen, chooseInt, chooseInteger, elements, frequency, vectorOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (counterexample, forAllShrink, sized, testProperty, (===))

tests :: TestTree
tests =
  testGroup
    "Syntax"
    [ testGroup
        "FullForm"
        [ testProperty "parseFullForm (fullForm e) ≡ Right e" $
            forAllShrink (sized genExpr) shrinkExpr $
              \e -> parseFullForm resolveGen (fullForm e) === Right e,
          testCase "Rational[p, q] reads as a number" $
            parseFullForm resolveName "Rational[2, 4]" @?= Right (rat (1 / 2)),
          testCase "a negative integer" $ parseFullForm resolveName "f[-3]" @?= Right (fn "f" [int (-3)]),
          testCase "escapes in strings" $ fullForm (str "a\"b\\c\n") @?= "\"a\\\"b\\\\c\\n\"",
          testCase "a context prints in full, except System` and Global`" $
            map fullForm [mkSymbol (symbol "Test`" "up"), sym "x"] @?= ["Test`up", "x"],
          testCase "a context reads" $
            parseFullForm resolveName "Test`up" @?= Right (mkSymbol (symbol "Test`" "up")),
          testCase "a real is refused (D9)" $ isLeft (parseFullForm resolveName "1.5") @?= True
        ],
      testGroup
        "infix"
        [ testProperty "parseExpr (pretty e) ≡ Right e, over generated terms" $
            forAllShrink (sized genExpr) shrinkExpr roundTrip,
          testProperty "parseExpr (pretty e) ≡ Right e, over every operator form" $
            forAllShrink (sized genSurface) shrinkExpr roundTrip,
          testGroup "WL's parse, as Mathics3 10.0.1 reads it" (map parsesAs mathics),
          testGroup "the two departures (Cassini.Syntax.Parser)" (map parsesAs departures),
          testCase "a real is refused (D9)" $ isLeft (parseExpr resolveName "1.5") @?= True,
          testGroup "WL's string escapes, as WL 15.0.1 reads them" (map readsString stringEscapes),
          testGroup "string escapes WL refuses, or Stage 1 lacks" (map refusesString badEscapes),
          testCase "FullForm reads the same escapes" $ parseFullForm resolveName "\"\\101\\.41\"" @?= Right (str "AA"),
          testCase "control characters print as escapes" $ pretty (str "\r\b\SOH") @?= "\"\\r\\b\\.01\"",
          testCase "1.. is Repeated[1], not a real" $ ff "1.." @?= "Repeated[1]",
          testCase "an open bracket is incomplete" $ incomplete resolveName "f[x," @?= True,
          testCase "a trailing operator is incomplete" $ incomplete resolveName "a +" @?= True,
          testCase "a stray bracket is an error, not incomplete" $ incomplete resolveName "f]" @?= False,
          testCase "a complete input is not incomplete" $ incomplete resolveName "f[x]" @?= False
        ]
    ]
  where
    roundTrip e =
      let printed = pretty e
       in counterexample (toString printed) (parseExpr resolveGen printed === Right e)
    parsesAs (input, expected) = testCase (toString input) (ff input @?= expected)
    ff = either ("parse error: " <>) fullForm . parseExpr resolveName
    readsString (input, expected) = testCase (toString input) (parseExpr resolveName input @?= Right (str expected))
    refusesString input = testCase (toString input) (isLeft (parseExpr resolveName input) @?= True)

-- | String literals and the text WL 15.0.1 reads from them
-- (@ToCharacterCode[ToExpression[…]]@, through the Wolfram Cloud MCP).
stringEscapes :: [(Text, Text)]
stringEscapes =
  [ ("\"\\101\"", "A"),
    ("\"\\1012\"", "A2"),
    ("\"\\.41\"", "A"),
    ("\"\\:0041\"", "A"),
    ("\"\\|000041\"", "A"),
    ("\"\\b\\f\\r\\t\\n\"", "\b\f\r\t\n"),
    ("\"\\'\"", "\\'")
  ]

-- | String literals WL refuses with @Syntax::stresc@ or @Syntax::sntoct1@
-- and @sntoct2@, and the named-character and box escapes Stage 1 lacks (D36).
badEscapes :: [Text]
badEscapes = ["\"\\x41\"", "\"\\SOH\"", "\"\\q\"", "\"\\7\"", "\"\\0\"", "\"\\.4\"", "\"\\a\"", "\"\\[Alpha]\"", "\"\\<a\\>\""]

-- | Inputs and their parses, read by Mathics3 10.0.1's parser
-- (@FullForm[Hold[…]]@), which follows WL's.
mathics :: [(Text, Text)]
mathics =
  [ ("1/x", "Times[1, Power[x, -1]]"),
    ("-a b", "Times[-1, a, b]"),
    ("a/b/c", "Times[a, Power[b, -1], Power[c, -1]]"),
    ("(a b) c", "Times[Times[a, b], c]"),
    ("-(a b)", "Times[-1, Times[a, b]]"),
    ("a - b c", "Plus[a, Times[-1, b, c]]"),
    ("-2^x", "Times[-1, Power[2, x]]"),
    ("a b/c", "Times[a, b, Power[c, -1]]"),
    ("a/b c", "Times[a, Power[b, -1], c]"),
    ("x^-1 b", "Times[Power[x, -1], b]"),
    ("a + (b + c)", "Plus[a, Plus[b, c]]"),
    ("f@g@x", "f[g[x]]"),
    ("x // f // g", "g[f[x]]"),
    ("f''[x]", "Derivative[2][f][x]"),
    ("a ~f~ b ~g~ c", "g[f[a, b], c]"),
    ("#^2 &", "Function[Power[Slot[1], 2]]"),
    ("a; b;", "CompoundExpression[a, b, Null]"),
    ("a < b <= c", "Inequality[a, Less, b, LessEqual, c]"),
    ("a == b == c", "Equal[a, b, c]"),
    ("x_:0", "Optional[Pattern[x, Blank[]], 0]"),
    ("x:_+_", "Pattern[x, Plus[Blank[], Blank[]]]"),
    ("p..", "Repeated[p]"),
    ("{a,b}[[1,2]]", "Part[List[a, b], 1, 2]"),
    ("a -> b -> c", "Rule[a, Rule[b, c]]"),
    ("x_?f", "PatternTest[Pattern[x, Blank[]], f]"),
    ("f[a,,b]", "f[a, Null, b]"),
    ("a || b && c", "Or[a, And[b, c]]"),
    ("!a == b", "Not[Equal[a, b]]"),
    ("a b -> c /; d", "Rule[Times[a, b], Condition[c, d]]"),
    ("- - a", "Times[-1, -1, a]"),
    ("a===b===c", "SameQ[a, b, c]"),
    ("n!", "Factorial[n]"),
    ("a!=b", "Unequal[a, b]"),
    ("a^b^c", "Power[a, Power[b, c]]"),
    ("-x^2", "Times[-1, Power[x, 2]]"),
    ("2 3", "Times[2, 3]"),
    ("x /. a -> b /. c -> d", "ReplaceAll[ReplaceAll[x, Rule[a, b]], Rule[c, d]]"),
    ("f /: g[f] = 1", "TagSet[f, g[f], 1]"),
    ("x =.", "Unset[x]"),
    ("a*-b", "Times[a, -1, b]"),
    ("-1 2 b", "Times[-1, 2, b]"),
    ("#&[1]", "Function[Slot[1]][1]"),
    ("(#&)[1]", "Function[Slot[1]][1]"),
    ("f /@ g /@ x", "Map[f, Map[g, x]]"),
    ("x_.", "Optional[Pattern[x, Blank[]]]"),
    ("-(-a)", "Times[-1, Times[-1, a]]"),
    ("Plus[a]-b", "Plus[Plus[a], Times[-1, b]]"),
    ("f @@@ {{a}, g[b]}", "Apply[f, List[List[a], g[b]], List[1]]")
  ]

-- | Where this parser departs from Mathics3's, and why: each reads as what
-- evaluation gives, so that every expression has a printed form that reads
-- back as itself.
departures :: [(Text, Text)]
departures =
  [ ("1/2", "Rational[1, 2]"),
    ("-1/2", "Rational[-1, 2]"),
    ("a - 2 b", "Plus[a, Times[-2, b]]"),
    ("a - 1/2 b", "Plus[a, Times[Rational[-1, 2], b]]")
  ]

-- | Terms over every head the printer has an operator form for, under the
-- front end's resolution: the operator heads are @System`@ symbols.
genSurface :: Int -> Gen Expr
genSurface n
  | n <= 1 = leaf
  | otherwise =
      frequency
        [ (2, leaf),
          (2, genExpr n),
          (6, op <$> elements binaryHeads <*> sub 2 <*> sub 2),
          (3, apply . systemSymbol <$> elements flatHeads <*> args 2 3),
          (2, (\h a -> apply (systemSymbol h) [a]) <$> elements unaryHeads <*> sub 1),
          (2, (\x b -> apply (systemSymbol "Pattern") [x, b]) <$> name <*> oneOf' [blankE, sub 1]),
          (1, (\p v -> apply (systemSymbol "Optional") [p, v]) <$> patternE <*> sub 2),
          (1, (\p -> apply (systemSymbol "Optional") [p]) <$> patternE),
          (2, (\b -> apply (systemSymbol "Function") [b]) <$> sub 1),
          (1, (\x is -> apply (systemSymbol "Part") (x : is)) <$> sub 2 <*> args 1 2),
          (1, (\k f -> mkApp (apply (systemSymbol "Derivative") [int k]) (V.singleton f)) <$> chooseInteger (1, 3) <*> name),
          (1, (\k f x -> mkApp (mkApp (apply (systemSymbol "Derivative") [int k]) (V.singleton f)) (V.singleton x)) <$> chooseInteger (1, 2) <*> name <*> sub 2),
          (1, apply (systemSymbol "CompoundExpression") <$> ((<>) <$> args 1 2 <*> elements [[], [mkSymbol (systemSymbol "Null")]])),
          (1, apply (systemSymbol "List") <$> args 0 3)
        ]
  where
    sub k = genSurface ((n - 1) `div` k)
    args lo hi = do
      k <- chooseInt (lo, hi)
      vectorOf k (genSurface ((n - 1) `div` max 1 k))
    op h a b = apply (systemSymbol h) [a, b]
    oneOf' gs = frequency [(1, g) | g <- gs]
    name = sym <$> elements ["x", "y", "f"]
    blankE = apply . systemSymbol <$> elements ["Blank", "BlankSequence", "BlankNullSequence"] <*> elements [[], [sym "h"], [mkSymbol (systemSymbol "Integer")]]
    patternE = oneOf' [blankE, (\x b -> apply (systemSymbol "Pattern") [x, b]) <$> name <*> blankE]
    leaf =
      frequency
        [ (4, genExpr 1),
          (1, (\k -> apply (systemSymbol "Slot") [int k]) <$> chooseInteger (0, 3)),
          (1, (\k -> apply (systemSymbol "SlotSequence") [int k]) <$> chooseInteger (1, 3)),
          (1, blankE),
          (1, (\k -> apply (systemSymbol "Out") [int k | k /= 0]) <$> chooseInteger (-3, 3))
        ]

binaryHeads, flatHeads, unaryHeads :: [Text]
binaryHeads =
  [ "Set",
    "SetDelayed",
    "UpSet",
    "UpSetDelayed",
    "Rule",
    "RuleDelayed",
    "ReplaceAll",
    "ReplaceRepeated",
    "Condition",
    "PatternTest",
    "Apply",
    "Map",
    "AddTo",
    "Power"
  ]
flatHeads = ["Plus", "Times", "Alternatives", "Or", "And", "Equal", "Unequal", "Less", "GreaterEqual", "SameQ", "UnsameQ", "StringJoin", "CompoundExpression"]
unaryHeads = ["Not", "Factorial", "Repeated", "RepeatedNull", "Unset", "Increment", "PreDecrement", "Function"]

-- | The front end's resolution, plus the operator heads the generators
-- build that the registry does not define, which the printer prints bare.
resolveGen :: Text -> Symbol
resolveGen n
  | HashSet.member n extra = systemSymbol n
  | otherwise = resolveName n
  where
    extra = HashSet.fromList (["Factorial", "Integer"] <> binaryHeads <> flatHeads <> unaryHeads)
