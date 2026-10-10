{-# LANGUAGE PatternSynonyms #-}

-- | Script mode: FullForm in, FullForm out (DESIGN.md §4.10, §7.4). The
-- interactive loop arrives with milestone 1c, as @Cassini.REPL@ in the
-- @cassini-repl@ package; this module stays here because the test suites,
-- the oracle, the corpus and the benchmarks all run scripts.
--
-- A script is one FullForm input per line, evaluated in order in one fresh
-- kernel. Blank lines, and lines that are one WL comment @(* … *)@, are not
-- inputs and are not numbered: a case can cite its source. For each input @k@ the output is a line
-- @Out[k]: <FullForm>@, or @Out[k]: -@ when the result is @Null@ (WL prints
-- nothing), followed by one @Message[k]: symbol::tag@ line per message, in
-- the order emitted. This is the Wolfram documentation corpus's format
-- (§7.9), so its cases and the regression corpus run through the same
-- function, and messages compare by name, never by text.
module Cassini.Script
  ( runScript,
    runScriptWith,
    traceScript,
    resolveName,
  )
where

import Cassini.Builtins (standardState, systemNames)
import Cassini.Core.Expr (Expr, pattern Sym)
import Cassini.Core.Symbol (Symbol, globalSymbol, sNull, systemSymbol)
import Cassini.Eval (evaluateTop, runEvalIO)
import Cassini.Eval.Kernel (EvalConfig (..), KernelState (..), TraceEntry (..), Unwind (..), defaultConfig)
import Cassini.Eval.Message (messageName)
import Cassini.Syntax.FullForm (fullForm, parseFullForm)
import Data.HashSet qualified as HashSet
import Data.Text qualified as T
import Effectful (runEff)

-- | Run a script against the standard builtins.
runScript :: Text -> IO Text
runScript = runScriptWith defaultConfig standardState

-- | Run a script and record, before each input's output, the steps of the
-- evaluation sequence (§7.4's golden traces): @Trace[k]: <step>: <FullForm>@,
-- indented by evaluation depth.
traceScript :: Text -> IO Text
traceScript = runScriptWith defaultConfig {trace = True} standardState

-- | Run a script from a given state, under a given configuration.
runScriptWith :: EvalConfig -> KernelState -> Text -> IO Text
runScriptWith cfg st src = do
  ref <- newIORef st
  outs <- forM (zip [1 :: Int ..] (filter isInput (lines src))) $ \(k, line) ->
    case parseFullForm resolveName line of
      Left _ -> pure [label "Out" k <> "$Failed", label "Message" k <> "Syntax::sntx"]
      Right e -> do
        r <- runEff (runEvalIO cfg ref (evaluateTop e))
        after <- readIORef ref
        writeIORef ref after {ksMessages = mempty, ksTrace = mempty}
        let traced = [label "Trace" k <> T.replicate (2 * (t.teDepth - 1)) " " <> t.teStep <> ": " <> fullForm t.teExpr | t <- toList after.ksTrace]
            out = label "Out" k <> either (const "$Aborted") showResult (unwound r)
            msgs = [label "Message" k <> messageName m | m <- toList after.ksMessages]
        pure (traced <> [out] <> msgs)
  pure (unlines (concat outs))
  where
    isInput line =
      let t = T.strip line
       in not (T.null t || ("(*" `T.isPrefixOf` t && "*)" `T.isSuffixOf` t))
    label :: Text -> Int -> Text
    label name k = name <> "[" <> show k <> "]: "
    showResult = \case
      Sym s | s == sNull -> "-"
      x -> fullForm x
    -- The top-level entry converts every unwind but an abort (§4.13).
    unwound :: Either Unwind Expr -> Either () Expr
    unwound = first (const ())

-- | A name without a context is @System`@ if the registry defines it, else
-- @Global`@.
resolveName :: Text -> Symbol
resolveName n
  | HashSet.member n systemNames = systemSymbol n
  | otherwise = globalSymbol n
