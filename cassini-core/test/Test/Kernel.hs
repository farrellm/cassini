-- | Running the evaluator purely in tests: 'runEvalPure' under
-- 'runPureEff', so the type checker guarantees there is no 'IO' in what is
-- tested (DESIGN.md §4.3).
module Test.Kernel
  ( run,
    eval,
    evalWith,
    evalStd,
    parse,
    ff,
    messageNames,
    std,
  )
where

import Cassini.Builtins (standardState)
import Cassini.Core.Expr (Expr, mkString)
import Cassini.Eval (evaluateTop, runEvalPure)
import Cassini.Eval.Kernel (EvalConfig, Kernel, KernelState (..), Unwind, defaultConfig)
import Cassini.Eval.Message (messageName)
import Cassini.Script (resolveName)
import Cassini.Syntax.FullForm (fullForm, parseFullForm)
import Effectful (Eff, runPureEff)

-- | The standard builtins.
std :: KernelState
std = standardState

-- | Run kernel code from a state, purely.
run :: KernelState -> Eff '[Kernel] a -> (Either Unwind a, KernelState)
run st m = runPureEff (runEvalPure defaultConfig st m)

-- | Evaluate one top-level input from a state. An abort, which nothing in
-- these tests raises, shows as the string @"$Aborted"@.
eval :: KernelState -> Expr -> (Expr, KernelState)
eval = evalWith defaultConfig

-- | 'eval' under a configuration.
evalWith :: EvalConfig -> KernelState -> Expr -> (Expr, KernelState)
evalWith cfg st e = first (fromRight (mkString "$Aborted")) (runPureEff (runEvalPure cfg st (evaluateTop e)))

-- | Evaluate a sequence of FullForm inputs in one fresh standard kernel, and
-- give the last result as FullForm.
evalStd :: [Text] -> Text
evalStd = go std
  where
    go st = \case
      [] -> ""
      [t] -> ff (fst (eval st (parse t)))
      t : ts -> go (snd (eval st (parse t))) ts

-- | Read FullForm with the front end's name resolution. A syntax error reads
-- as a string saying so, which no expected value equals.
parse :: Text -> Expr
parse = either (mkString . ("parse error: " <>)) id . parseFullForm resolveName

-- | Print FullForm.
ff :: Expr -> Text
ff = fullForm

-- | The names of the messages a state holds, in order.
messageNames :: KernelState -> [Text]
messageNames st = messageName <$> toList st.ksMessages
