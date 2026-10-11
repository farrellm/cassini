-- | The @cassini@ executable (DESIGN.md §4.10): the interactive loop, or
-- script mode. @cassini@ alone starts "Cassini.REPL". @cassini --script
-- FILE@ reads FullForm, one input per line, and writes FullForm (§7.4's
-- golden format); @--trace@ adds the evaluation steps.
module Main (main) where

import Cassini.REPL (repl)
import Cassini.Script (runScript, traceScript)

main :: IO ()
main =
  getArgs >>= \case
    [] -> repl
    ["--script", file] -> readFileBS file >>= runScript . decodeUtf8 >>= putText
    ["--trace", file] -> readFileBS file >>= traceScript . decodeUtf8 >>= putText
    _ -> do
      putTextLn "usage: cassini [--script FILE | --trace FILE]"
      exitFailure
