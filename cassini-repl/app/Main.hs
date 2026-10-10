-- | The @cassini@ executable. Its body is the REPL (DESIGN.md §4.10). Until
-- the interactive loop arrives with milestone 1c, it has script mode only:
-- @cassini --script FILE@ reads FullForm, one input per line, and writes
-- FullForm (§7.4's golden format); @--trace@ adds the evaluation steps.
module Main (main) where

import Cassini.Script (runScript, traceScript)

main :: IO ()
main =
  getArgs >>= \case
    ["--script", file] -> readFileBS file >>= runScript . decodeUtf8 >>= putText
    ["--trace", file] -> readFileBS file >>= traceScript . decodeUtf8 >>= putText
    _ -> do
      putTextLn "usage: cassini --script FILE | --trace FILE (the REPL arrives with milestone 1c)"
      exitFailure
