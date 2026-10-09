-- | The regression corpus and the golden evaluation traces (DESIGN.md §7.4).
--
-- Each @test/regress/*.in@ is a FullForm script, run through
-- 'Cassini.REPL.runScript''s format and compared with its @.expected@; each
-- @test/trace/*.in@ is run with the evaluation steps recorded. Adding a case
-- is adding two files. Goldens are read before they are accepted: a person
-- reads the diff, and the commit message says why the new output is right.
--
-- Every case runs against the standard builtins plus one test-only built-in
-- upvalue, @Test`up@, which answers @"builtin upvalue"@ for any expression
-- with a @Test`up[…]@ argument. 1a's builtins have no upvalue of their own,
-- and @0002-builtin-upvalue-beats-user-downvalue@ needs one.
module Test.Golden (goldenTests) where

import Cassini.Builtins (install, standardState)
import Cassini.Builtins.Define (Definition (..), up)
import Cassini.Core.Expr (mkString)
import Cassini.Core.Symbol (symbol)
import Cassini.Eval.Kernel (EvalConfig (..), KernelState, defaultConfig)
import Cassini.REPL (runScriptWith)
import System.FilePath (replaceExtension, takeBaseName)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Golden (findByExtension, goldenVsString)

-- | Both golden sets, discovered from the file system.
goldenTests :: IO TestTree
goldenTests = do
  regress <- sort <$> findByExtension [".in"] "test/regress"
  traces <- sort <$> findByExtension [".in"] "test/trace"
  pure $
    testGroup
      "golden"
      [ testGroup "regress" (map (golden False) regress),
        testGroup "trace" (map (golden True) traces)
      ]
  where
    golden traced file =
      goldenVsString (takeBaseName file) (replaceExtension file ".expected") $ do
        src <- decodeUtf8 <$> readFileBS file
        out <- runScriptWith defaultConfig {trace = traced} goldenState src
        pure (encodeUtf8 out)

goldenState :: KernelState
goldenState = install [Definition (symbol "Test`" "up") [] [up (\_ -> pure (Just (mkString "builtin upvalue")))]] standardState
