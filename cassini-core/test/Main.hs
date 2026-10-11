-- | The fast suite: unit, property and golden tests (DESIGN.md §7.1). Run on
-- every commit under both settings of the @intern@ flag.
module Main (main) where

import Test.Cassini.Attributes qualified
import Test.Cassini.Core.Intern qualified
import Test.Cassini.Core.Order qualified
import Test.Cassini.Core.Traversal qualified
import Test.Cassini.Eval qualified
import Test.Cassini.Number qualified
import Test.Cassini.Pattern qualified
import Test.Cassini.Pattern.Commutative qualified
import Test.Cassini.Pattern.Sequence qualified
import Test.Cassini.Pattern.Syntactic qualified
import Test.Cassini.Rules qualified
import Test.Cassini.Simplify.Automatic qualified
import Test.Cassini.Structure qualified
import Test.Cassini.Syntax qualified
import Test.Golden (goldenTests)
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main = do
  golden <- goldenTests
  defaultMain $
    testGroup
      "cassini"
      [ Test.Cassini.Number.tests,
        Test.Cassini.Core.Intern.tests,
        Test.Cassini.Core.Order.tests,
        Test.Cassini.Core.Traversal.tests,
        Test.Cassini.Structure.tests,
        Test.Cassini.Attributes.tests,
        Test.Cassini.Rules.tests,
        Test.Cassini.Pattern.Syntactic.tests,
        Test.Cassini.Pattern.Sequence.tests,
        Test.Cassini.Pattern.Commutative.tests,
        Test.Cassini.Pattern.tests,
        Test.Cassini.Simplify.Automatic.tests,
        Test.Cassini.Eval.tests,
        Test.Cassini.Syntax.tests,
        golden
      ]
