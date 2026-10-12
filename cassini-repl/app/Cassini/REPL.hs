{-# LANGUAGE PatternSynonyms #-}

-- | The read-eval-print loop (DESIGN.md §4.10, §4.13): @In[n]:=@ and
-- @Out[n]=@, @%@, messages, a trace of the evaluation steps, timing, and
-- interrupts.
--
-- Input is the infix syntax ("Cassini.Syntax.Parser"); output is
-- "Cassini.Syntax.Pretty"'s, or FullForm on request. An input that ends
-- inside an open bracket, or with an operator waiting for its operand,
-- continues on the next line.
--
-- __Interrupts.__ Ctrl-C at the prompt discards the line. During evaluation
-- the handler only sets a flag; the next evaluation step clears it and
-- aborts through the kernel's ordinary channel, so the input gives
-- @$Aborted@ and every guarantee of an @Abort[]@ holds. A computation below
-- the kernel, such as one huge exact power, never reaches a step, so a
-- second Ctrl-C while the flag is still set is thrown asynchronously: the
-- input is abandoned, and the loop says that the session state is no longer
-- guaranteed, since nothing restored what the input changed (§4.13). That
-- second Ctrl-C is also why exact arithmetic needs no size limit here (D33).
module Cassini.REPL (repl) where

import Cassini.Builtins (standardState)
import Cassini.Builtins.Session (recordLine)
import Cassini.Core.Expr (Expr, pattern Sym)
import Cassini.Core.Symbol (sNull, systemSymbol)
import Cassini.Eval (evaluateTop, runEvalIO, runEvalInterruptible)
import Cassini.Eval.Kernel (EvalConfig (..), KernelState (..), TraceEntry (..), defaultConfig)
import Cassini.Script (evaluateInput, resolveName)
import Cassini.Syntax.FullForm (fullForm)
import Cassini.Syntax.Parser (incomplete, parseExpr)
import Cassini.Syntax.Pretty (pretty, prettyMessage)
import Control.Concurrent (myThreadId, throwTo)
import Control.Exception (AsyncException (UserInterrupt), throwIO, try)
import Data.Text qualified as T
import Effectful (runEff)
import GHC.Clock (getMonotonicTime)
import System.Console.Haskeline (InputT, Settings (..), defaultSettings, getInputLine, handleInterrupt, outputStrLn, runInputT, withInterrupt)
import System.Posix.Signals (Handler (Catch), installHandler, sigINT)
import Text.Printf (printf)

-- | The loop's own settings, changed by its commands.
data Options = Options
  { timing :: !Bool,
    showFullForm :: !Bool
  }

-- | Run the loop until end of input.
repl :: IO ()
repl = do
  session <- newIORef standardState
  flag <- newIORef False
  mainThread <- myThreadId
  -- A first Ctrl-C sets the flag; a second, while it is still set, is
  -- thrown at the loop.
  _ <- installHandler sigINT (Catch (atomicModifyIORef' flag (True,) >>= \pending -> when pending (throwTo mainThread UserInterrupt))) Nothing
  history <- fmap (<> "/.cassini_history") <$> lookupEnv "HOME"
  putTextLn "cassini — a computer algebra system. :help for the commands; Ctrl-D quits."
  runInputT defaultSettings {historyFile = history} (loop session flag (Options False False) 1)

loop :: IORef KernelState -> IORef Bool -> Options -> Integer -> InputT IO ()
loop session flag opts n = do
  line <- handleInterrupt (pure (Just "")) (withInterrupt (readInput n))
  case line of
    Nothing -> pure ()
    Just src
      | T.null (T.strip src) -> loop session flag opts n
      | Just cmd <- T.stripPrefix ":" (T.strip src) -> command cmd
      | otherwise -> do
          next <- liftIO (evaluateLine session flag opts n src)
          loop session flag opts next
  where
    command cmd = case T.words cmd of
      ["quit"] -> pure ()
      ["q"] -> pure ()
      ["help"] -> say help >> loop session flag opts n
      ["timing"] -> do
        say ("timing " <> if opts.timing then "off" else "on")
        loop session flag opts {timing = not opts.timing} n
      ["fullform"] -> do
        say ("FullForm output " <> if opts.showFullForm then "off" else "on")
        loop session flag opts {showFullForm = not opts.showFullForm} n
      "trace" : _ -> do
        liftIO (traceLine session flag (T.strip (T.drop 5 cmd)))
        loop session flag opts n
      _ -> say ("unknown command :" <> cmd <> "; :help lists them") >> loop session flag opts n
    say = outputStrLn . toString

-- | One input, read over as many lines as it takes to be complete.
readInput :: Integer -> InputT IO (Maybe Text)
readInput n = go ("In[" <> show n <> "]:= ") ""
  where
    go prompt acc =
      getInputLine (toString prompt) >>= \case
        Nothing -> pure (if T.null acc then Nothing else Just acc)
        Just l -> do
          let src = if T.null acc then toText l else acc <> "\n" <> toText l
          if incomplete resolveName src && not (":" `T.isPrefixOf` T.strip src)
            then go (T.replicate (T.length prompt) " ") src
            else pure (Just src)

-- | Parse, evaluate and print input @n@, and give the next input's number.
-- A syntax error uses no number.
evaluateLine :: IORef KernelState -> IORef Bool -> Options -> Integer -> Text -> IO Integer
evaluateLine session flag opts n src = case parseExpr resolveName src of
  Left err -> do
    putTextLn ("Syntax::sntx: " <> T.strip err)
    pure n
  Right e -> do
    writeIORef flag False
    start <- getMonotonicTime
    outcome <- try @AsyncException (runEff (runEvalInterruptible defaultConfig session flag (evaluateInput n e)))
    end <- getMonotonicTime
    writeIORef flag False
    result <- case outcome of
      Right (Right v) -> pure (Just v)
      Right (Left _) -> pure Nothing
      Left UserInterrupt -> do
        putTextLn "Interrupted outside an evaluation step: what the input changed was not restored, and the session state is no longer guaranteed."
        pure Nothing
      Left other -> throwIO other
    let shown = fromMaybe aborted result
    -- An aborted input is recorded too, as $Aborted.
    when (isNothing result) $ void (runEff (runEvalIO defaultConfig session (recordLine n e shown)))
    messages <- atomicModifyIORef' session (\k -> (k {ksMessages = mempty, ksTrace = mempty}, toList k.ksMessages))
    for_ messages (putTextLn . prettyMessage)
    case shown of
      Sym s | s == sNull -> pass
      v -> putTextLn ("Out[" <> show n <> "]= " <> (if opts.showFullForm then fullForm else pretty) v)
    when opts.timing $ putStrLn (printf "Timing: %.6f s" (end - start))
    pure (n + 1)
  where
    aborted = Sym (systemSymbol "$Aborted")

-- | @:trace expr@: evaluate with the evaluation sequence's steps recorded,
-- and print them, indented by depth, without recording the input.
traceLine :: IORef KernelState -> IORef Bool -> Text -> IO ()
traceLine session flag src = case parseExpr resolveName src of
  Left err -> putTextLn ("Syntax::sntx: " <> T.strip err)
  Right e -> do
    -- Interruptible as an input is: Ctrl-C aborts at the next step, and a
    -- second one, thrown at the loop, is caught here rather than ending it.
    writeIORef flag False
    outcome <- try @AsyncException (runEff (runEvalInterruptible defaultConfig {trace = True} session flag (evaluateTop e)))
    writeIORef flag False
    r <- case outcome of
      Right r -> pure r
      Left UserInterrupt -> do
        putTextLn "Interrupted outside an evaluation step: what the input changed was not restored, and the session state is no longer guaranteed."
        pure (Right (Sym (systemSymbol "$Aborted")))
      Left other -> throwIO other
    (steps, messages) <- atomicModifyIORef' session (\k -> (k {ksMessages = mempty, ksTrace = mempty}, (toList k.ksTrace, toList k.ksMessages)))
    for_ steps $ \t -> putTextLn (T.replicate (2 * (t.teDepth - 1)) " " <> t.teStep <> ": " <> pretty t.teExpr)
    for_ messages (putTextLn . prettyMessage)
    putTextLn (either (const "$Aborted") showResult r)
  where
    showResult :: Expr -> Text
    showResult = pretty

help :: Text
help =
  T.unlines
    [ "Enter an expression in the infix syntax: f[x_] := x^2; D[f[y] g[y], y]",
      "  %, %%, %n      the last output, the one before, output n",
      "  :trace expr    show the evaluation steps of expr",
      "  :timing        toggle printing each input's evaluation time",
      "  :fullform      toggle FullForm output",
      "  :quit          quit (or Ctrl-D)",
      "Ctrl-C aborts an evaluation at its next step; a second Ctrl-C abandons it outright."
    ]
