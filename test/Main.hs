-- | The fast suite: unit, property and golden tests (DESIGN.md §7.1). Run on
-- every commit under both settings of the @intern@ flag.
module Main (main) where

import Test.Cassini.Core.Intern qualified
import Test.Cassini.Core.Order qualified
import Test.Cassini.Core.Traversal qualified
import Test.Cassini.Number qualified
import Test.Cassini.Structure qualified
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain $
    testGroup
      "cassini"
      [ Test.Cassini.Number.tests,
        Test.Cassini.Core.Intern.tests,
        Test.Cassini.Core.Order.tests,
        Test.Cassini.Core.Traversal.tests,
        Test.Cassini.Structure.tests
      ]
