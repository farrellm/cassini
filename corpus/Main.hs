-- | @cassini-corpus@: other systems' test cases and Wolfram's documentation
-- examples, under a ratchet (DESIGN.md §7.8).
--
-- A case is in scope when the scope rule admits it; the rest are counted
-- and not run. An in-scope case passes when every usable output is
-- structurally equal to Cassini's, up to the order of arguments under
-- @Orderless@ heads (both sides sorted, neither evaluated), and its messages
-- agree by @symbol::tag@. The suite fails only when a case listed in
-- @corpus/passing/<source>.txt@ fails: a newly passing case is reported, and
-- a person adds it after reading it. A case that fails for a deliberate
-- reason is listed in @corpus/divergences.txt@ with its D-number and is
-- reported as a divergence.
--
-- Options:
--
-- * @--page NAME@ (repeatable): run only those pages, for triage.
-- * @--verbose@: print every failure, expected against actual.
-- * @--write-passing FILE@: write the IDs that pass now, for a person to
--   diff against the ratchet.
module Main (main) where

import Cassini.Builtins (systemNames)
import Cassini.REPL (runScript)
import Data.HashSet qualified as HashSet
import Data.Map.Strict qualified as Map
import Data.Text qualified as T
import System.Directory (doesFileExist)
import System.Timeout (timeout)
import Test.Corpus.Wolfram (Case (..), casePath, inScope, loadCases)
import Test.Script (Entries, entries, sameOutput)

data Options = Options
  { pages :: ![Text],
    verbose :: !Bool,
    writePassing :: !(Maybe FilePath)
  }

data Outcome = Pass | Fail !Text

main :: IO ()
main = do
  opts <- parseOptions <$> getArgs
  let dir = "corpus/wolfram-docs"
  loadCases dir >>= \case
    Nothing -> putTextLn "cassini-corpus: corpus/wolfram-docs is absent; skipping (DESIGN.md §7.9)"
    Just cases -> do
      ratchet <- idSet "corpus/passing/wolfram.txt"
      divergences <- idSet "corpus/divergences.txt"
      let selected = filter (\c -> null opts.pages || page c `elem` opts.pages) cases
          scoped = filter (inScope systemNames) selected
      results <- forM scoped $ \c -> (c,) <$> runCase dir c
      let passing = [c.caseId | (c, Pass) <- results]
          failing = [(c.caseId, why) | (c, Fail why) <- results]
          broken = [(i, why) | (i, why) <- failing, HashSet.member i ratchet, not (HashSet.member i divergences)]
          diverging = [i | (i, _) <- failing, HashSet.member i divergences]
          newly = [i | i <- passing, not (HashSet.member i ratchet)]
          stale = [i | (i, _) <- failing, not (HashSet.member i ratchet), not (HashSet.member i divergences)]
      when opts.verbose $ for_ failing $ \(i, why) -> putTextLn ("FAIL " <> i <> "\n" <> why)
      putTextLn ("wolfram: " <> show (length scoped) <> " in scope of " <> show (length selected) <> " cases")
      putTextLn ("  passing:     " <> show (length passing))
      putTextLn ("  divergences: " <> show (length diverging))
      putTextLn ("  failing:     " <> show (length stale) <> " (not in the ratchet)")
      putTextLn ("  newly passing, not yet in the ratchet: " <> show (length newly))
      for_ opts.writePassing $ \f -> writeFileText f (unlines (sort passing))
      unless (null broken) $ do
        putTextLn ("ratchet broken: " <> show (length broken) <> " listed case(s) fail")
        for_ broken $ \(i, why) -> putTextLn ("  " <> i <> "\n" <> why)
        exitFailure
  where
    page c = T.intercalate "/" (take 1 (drop 1 (T.splitOn "/" c.caseId)))

parseOptions :: [String] -> Options
parseOptions = go (Options [] False Nothing)
  where
    go o = \case
      "--page" : p : rest -> go o {pages = toText p : o.pages} rest
      "--verbose" : rest -> go o {verbose = True} rest
      "--write-passing" : f : rest -> go o {writePassing = Just f} rest
      _ : rest -> go o rest
      [] -> o

-- | The first whitespace-separated word of each non-comment line.
idSet :: FilePath -> IO (HashSet Text)
idSet f = do
  present <- doesFileExist f
  if not present
    then pure mempty
    else HashSet.fromList . mapMaybe (viaNonEmpty head . words) . filter (not . ("#" `T.isPrefixOf`)) . lines . decodeUtf8 <$> readFileBS f

-- | Run one case in a fresh kernel, with five seconds to finish.
runCase :: FilePath -> Case -> IO Outcome
runCase dir c = do
  let base = casePath dir c
  input <- decodeUtf8 <$> readFileBS (base <> ".in")
  expected <- decodeUtf8 <$> readFileBS (base <> ".expected")
  timeout 5000000 (runScript input >>= \out -> T.length out `seq` pure out) >>= \case
    Nothing -> pure (Fail "  timed out after 5 s")
    Just actual -> pure (compareScripts expected actual)

-- | Compare by input number: each usable expected output with the actual
-- one, structurally up to Orderless order, and the messages as sorted
-- lists of names.
compareScripts :: Text -> Text -> Outcome
compareScripts expected actual =
  case [d | k <- ks, Just d <- [outputDiff k]] <> [d | k <- ks, Just d <- [messageDiff k]] of
    [] -> Pass
    ds -> Fail (T.unlines (map ("  " <>) ds))
  where
    ex = renumber (entries (translate expected))
    ac = entries actual
    ks = ordNub (map fst (Map.keys ex) <> map fst (Map.keys ac))
    outputDiff k = case Map.lookup (k, "Out") ex of
      Just [e]
        | "?" `T.isPrefixOf` e -> Nothing
        | otherwise -> case Map.lookup (k, "Out") ac of
            Just [a] | sameOutput e a -> Nothing
            a -> Just ("Out[" <> show k <> "]: expected " <> e <> ", got " <> maybe "nothing" (T.intercalate " | ") a)
      _ -> Nothing
    messageDiff k =
      let e = sort (Map.findWithDefault [] (k, "Message") ex)
          a = sort (Map.findWithDefault [] (k, "Message") ac)
       in if e == a then Nothing else Just ("Message[" <> show k <> "]: expected " <> show e <> ", got " <> show a)

-- | The expected file numbers its inputs as the documentation page did
-- (@Out[67]@ for a one-input case), and a script numbers them from 1. Each
-- input has exactly one @Out@ line, so the @k@th label in order is input @k@.
renumber :: Entries -> Entries
renumber m = Map.mapKeys (first (\k -> fromMaybe k (Map.lookup k ordinal))) m
  where
    ordinal = Map.fromList (zip (ordNub (map fst (Map.keys m))) [1 ..])

-- | The extractor writes a message's symbol as the notebook displays it, so
-- @Infinity::indet@ arrives as @\\[Infinity]::indet@: a normalizer defect
-- (§7.9) the adapter translates.
translate :: Text -> Text
translate = T.replace "\\[Infinity]::" "Infinity::"
