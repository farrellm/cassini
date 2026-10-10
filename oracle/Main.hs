-- | @cassini-oracle@: differential testing against Mathics3 (DESIGN.md §7.5).
--
-- Runs each script in @oracle/cases/@, and each regression case in
-- @test/regress/@, through Cassini's 'runScript' and through Mathics3
-- (@oracle/mathics_eval.py@), and compares them input by input:
--
-- * outputs agree if they are structurally equal up to @Orderless@ order,
--   or if Cassini evaluates their difference to 0 (semantic comparison);
-- * if the difference evaluates to a nonzero number, they disagree;
-- * anything else is inconclusive, reported for a person to read and never
--   a failure (§7.5: a suite that cries wolf gets turned off);
-- * messages agree if their names agree as sorted lists;
-- * an input on which Mathics3 itself fails (a Python exception) is
--   inconclusive.
--
-- A disagreement listed in @oracle/divergences.txt@ (@case k reason@) is
-- reported as a divergence. Any other disagreement fails the suite.
--
-- The suite skips, passing, when @CASSINI_MATHICS_PYTHON@ is unset or names
-- an interpreter without Mathics3, so it never breaks a clean checkout.
module Main (main) where

import Cassini.REPL (resolveName, runScript)
import Cassini.Syntax.FullForm (fullForm, parseFullForm)
import Data.List (partition)
import Data.Map.Strict qualified as Map
import Data.Text qualified as T
import System.Directory (doesFileExist, listDirectory)
import System.Exit (ExitCode (ExitSuccess))
import System.FilePath (takeBaseName, takeExtension, (</>))
import System.Process (readProcessWithExitCode)
import Test.Script (Entries, entries, sameOutput)

data Verdict = Agree | Disagree !Text | Inconclusive !Text

main :: IO ()
main =
  lookupEnv "CASSINI_MATHICS_PYTHON" >>= \case
    Nothing -> putTextLn "cassini-oracle: CASSINI_MATHICS_PYTHON is unset; skipping (DESIGN.md §7.5)"
    Just python -> do
      (code, _, _) <- readProcessWithExitCode python ["-I", "-c", "import mathics"] ""
      if code /= ExitSuccess
        then putTextLn ("cassini-oracle: no Mathics3 in " <> toText python <> "; skipping")
        else run python

run :: FilePath -> IO ()
run python = do
  cases <- (<>) <$> scripts "oracle/cases" <*> scripts "test/regress"
  whitelist <- divergences "oracle/divergences.txt"
  results <- fmap concat . forM cases $ \(name, file) -> do
    src <- decodeUtf8 <$> readFileBS file
    -- A case that needs a test-only builtin (Test`up) has no Mathics3 twin.
    if "Test`" `T.isInfixOf` src
      then pure []
      else do
        ours <- entries <$> runScript src
        theirs <- entries . toText <$> mathics python src
        verdicts <- compareRuns ours theirs
        pure [(name, k, v) | (k, v) <- verdicts]
  -- A listed input is a divergence whether the comparison disagreed or
  -- could not decide.
  let listed (n, k, _) = Map.member (n, k) whitelist
      (whitelisted, failures) = partition listed [(n, k, why) | (n, k, Disagree why) <- results]
      (whitelisted', inconclusive) = partition listed [(n, k, why) | (n, k, Inconclusive why) <- results]
  for_ inconclusive $ \(n, k, why) -> putTextLn ("inconclusive " <> n <> " [" <> show k <> "]: " <> why)
  for_ (whitelisted <> whitelisted') $ \(n, k, why) ->
    putTextLn ("divergence   " <> n <> " [" <> show k <> "] (" <> Map.findWithDefault "" (n, k) whitelist <> "): " <> why)
  for_ failures $ \(n, k, why) -> putTextLn ("DISAGREE     " <> n <> " [" <> show k <> "]: " <> why)
  putTextLn
    ( "oracle: "
        <> show (length results)
        <> " inputs, "
        <> show (length [() | (_, _, Agree) <- results])
        <> " agree, "
        <> show (length whitelisted + length whitelisted')
        <> " divergences, "
        <> show (length inconclusive)
        <> " inconclusive, "
        <> show (length failures)
        <> " disagree"
    )
  unless (null failures) exitFailure

-- | The @.in@ scripts of a directory, by name.
scripts :: FilePath -> IO [(Text, FilePath)]
scripts dir = do
  files <- sort . filter ((== ".in") . takeExtension) <$> listDirectory dir
  pure [(toText (takeBaseName f), dir </> f) | f <- files]

-- | @case k reason@ lines; @#@ starts a comment.
divergences :: FilePath -> IO (Map (Text, Int) Text)
divergences f = do
  present <- doesFileExist f
  if not present
    then pure mempty
    else do
      ls <- lines . decodeUtf8 <$> readFileBS f
      pure $
        Map.fromList
          [ ((n, k), unwords reason)
          | l <- ls,
            not ("#" `T.isPrefixOf` l),
            n : kt : reason <- [words l],
            Just k <- [readMaybe (toString kt)]
          ]

-- | Run a script in Mathics3.
mathics :: FilePath -> Text -> IO String
mathics python src = do
  (_, out, err) <- readProcessWithExitCode python ["-I", "oracle/mathics_eval.py"] (toString src)
  pure (if null out then err else out)

-- | One verdict per input.
compareRuns :: Entries -> Entries -> IO [(Int, Verdict)]
compareRuns ours theirs = forM ks $ \k -> do
  let o = Map.lookup (k, "Out") ours
      t = Map.lookup (k, "Out") theirs
      om = sort (Map.findWithDefault [] (k, "Message") ours)
      tm = sort (Map.findWithDefault [] (k, "Message") theirs)
  out <- case (o, t) of
    (_, Just [b]) | "?" `T.isPrefixOf` b -> pure (Inconclusive ("Mathics3 failed: " <> T.drop 1 b))
    (Just [a], Just [b])
      | sameOutput b a -> pure Agree
      | otherwise -> semantic a b
    _ -> pure (Disagree ("output missing: ours " <> show o <> ", Mathics3 " <> show t))
  pure . (k,) $ case out of
    Agree
      | om == tm -> Agree
      | otherwise -> Disagree ("messages: ours " <> show om <> ", Mathics3 " <> show tm)
    v -> v
  where
    ks = ordNub (map fst (Map.keys ours <> Map.keys theirs))

-- | Compare by evaluating the difference in Cassini: 0 agrees, a nonzero
-- number disagrees, and anything else, including either side unreadable, is
-- inconclusive. Until milestone 2a this is §5.6's rational layer only.
semantic :: Text -> Text -> IO Verdict
semantic ours theirs = case (parse ours, parse theirs) of
  (Just a, Just b) -> do
    let difference = "Plus[" <> fullForm a <> ", Times[-1, " <> fullForm b <> "]]"
    out <- entries <$> runScript difference
    pure $ case Map.lookup (1, "Out") out of
      Just ["0"] -> Agree
      Just [d] | isNumber d -> Disagree (ours <> " /= " <> theirs)
      _ -> Inconclusive (ours <> " vs " <> theirs)
  _ -> pure (Inconclusive (ours <> " vs " <> theirs))
  where
    parse t = rightToMaybe (parseFullForm resolveName t)
    isNumber d = T.all (\c -> c == '-' || c `elem` ['0' .. '9']) d || "Rational[" `T.isPrefixOf` d
