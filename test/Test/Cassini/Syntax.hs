-- | "Cassini.Syntax.FullForm": reading what is printed gives back the
-- expression (DESIGN.md §4.10, §7.3; the @Syntax@ row's FullForm half).
module Test.Cassini.Syntax (tests) where

import Cassini.Core.Expr (mkSymbol)
import Cassini.Core.Symbol (Symbol, symbol, systemSymbol)
import Cassini.REPL (resolveName)
import Cassini.Syntax.FullForm (fullForm, parseFullForm)
import Test.Gen (fn, genExpr, int, rat, shrinkExpr, str, sym)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (forAllShrink, sized, testProperty, (===))

tests :: TestTree
tests =
  testGroup
    "Syntax.FullForm"
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
    ]

-- | The front end's resolution, plus @Factorial@, which the generators build
-- and the registry does not define until the integer builtins arrive
-- (§4.15). The property is about the printer and the reader agreeing.
resolveGen :: Text -> Symbol
resolveGen n
  | n == "Factorial" = systemSymbol n
  | otherwise = resolveName n
