-- | @cassini-corpus@: other systems' test cases and Wolfram's documentation
-- examples, under a ratchet (DESIGN.md §7.8).
--
-- Three sources: the Wolfram documentation corpus (§7.9), Expreduce's tests
-- (vendored) and Mathics3's (fetched by @corpus/fetch.sh@). A source that is
-- absent is skipped, so a fresh clone runs Expreduce's alone.
--
-- A case is in scope when the scope rule admits it; the rest are counted
-- and not run. Each session with a case in scope runs once, in a fresh
-- kernel, with five seconds to finish; an infix input is read by
-- "Cassini.Syntax.Parser", and one it cannot read gives @$Failed@ with
-- @Syntax::sntx@. A case passes when each output it compares is
-- structurally equal to Cassini's, up to the order of arguments under
-- @Orderless@ heads (both sides sorted, neither evaluated), and, where the
-- source names its messages, its messages agree by @symbol::tag@. The
-- suite fails only when a case listed in @corpus/passing/<source>.txt@
-- fails: a newly passing case is reported, and a person adds it after
-- reading it. A case that fails for a known reason is listed in
-- @corpus/divergences.txt@ and is reported as a divergence.
--
-- Options:
--
-- * @--source NAME@ (repeatable): run only those sources (@wolfram@,
--   @expreduce@, @mathics@).
-- * @--page NAME@ (repeatable): run only those pages, the second component of
--   a case ID (a Wolfram page, an Expreduce module, a Mathics3 file's
--   directory or name).
-- * @--verbose@: print every failure, expected against actual.
-- * @--write-passing FILE@: write the IDs that pass now, for a person to
--   diff against the ratchet.
module Main (main) where

import Cassini.Builtins (systemNames)
import Cassini.Script (resolveName, runScript)
import Cassini.Syntax.FullForm (fullForm)
import Cassini.Syntax.Parser (parseExpr)
import Data.HashSet qualified as HashSet
import Data.Map.Strict qualified as Map
import Data.Text qualified as T
import System.Directory (doesFileExist)
import System.FilePath ((</>))
import System.Timeout (timeout)
import Test.Corpus.Case (Case (..), Source (..), Syntax (..), inScope)
import Test.Corpus.Expreduce qualified as Expreduce
import Test.Corpus.Mathics qualified as Mathics
import Test.Corpus.Wolfram qualified as Wolfram
import Test.Script (Entries, entries, sameOutput)

data Options = Options
  { sources :: ![Text],
    pages :: ![Text],
    verbose :: !Bool,
    writePassing :: !(Maybe FilePath)
  }

data Outcome = Pass | Fail !Text

main :: IO ()
main = do
  opts <- parseOptions <$> getArgs
  divergences <- idSet "corpus/divergences.txt"
  let selected = [s | s <- [Wolfram.source, Expreduce.source, Mathics.source], null opts.sources || s.srcName `elem` opts.sources]
  reports <- forM selected (runSource opts divergences)
  for_ opts.writePassing $ \f -> writeFileText f (unlines (sort (concatMap fst reports)))
  let broken = concatMap snd reports
  unless (null broken) $ do
    putTextLn ("ratchet broken: " <> show (length broken) <> " listed case(s) fail")
    for_ broken $ \(i, why) -> putTextLn ("  " <> i <> "\n" <> why)
    exitFailure

-- | Run one source's cases in scope: the IDs that pass, and the listed
-- cases that fail.
runSource :: Options -> HashSet Text -> Source -> IO ([Text], [(Text, Text)])
runSource opts divergences src =
  src.srcLoad src.srcDir >>= \case
    Nothing -> do
      putTextLn ("cassini-corpus: " <> toText src.srcDir <> " is absent; skipping " <> src.srcName <> " (DESIGN.md §7.8)")
      pure ([], [])
    Just cases -> do
      ratchet <- idSet ("corpus/passing/" <> toString src.srcName <> ".txt")
      let chosen = filter (\c -> null opts.pages || page c `elem` opts.pages) cases
          scoped = filter (inScope systemNames) chosen
          bySession = Map.fromListWith (flip (<>)) [(c.caseSession, [c]) | c <- scoped]
      results <- fmap concat . forM (Map.toList bySession) $ \(session, cs) -> do
        outcomes <- runSession src session cs
        pure (zip cs outcomes)
      let passing = [c.caseId | (c, Pass) <- results]
          failing = [(c.caseId, why) | (c, Fail why) <- results]
          broken = [(i, why) | (i, why) <- failing, HashSet.member i ratchet, not (HashSet.member i divergences)]
          diverging = [i | (i, _) <- failing, HashSet.member i divergences]
          newly = [i | i <- passing, not (HashSet.member i ratchet)]
          stale = [i | (i, _) <- failing, not (HashSet.member i ratchet), not (HashSet.member i divergences)]
      when opts.verbose $ for_ failing $ \(i, why) -> putTextLn ("FAIL " <> i <> "\n" <> why)
      putTextLn (src.srcName <> ": " <> show (length scoped) <> " in scope of " <> show (length chosen) <> " cases")
      putTextLn ("  passing:     " <> show (length passing))
      putTextLn ("  divergences: " <> show (length diverging))
      putTextLn ("  failing:     " <> show (length stale) <> " (not in the ratchet)")
      putTextLn ("  newly passing, not yet in the ratchet: " <> show (length newly))
      pure (passing, broken)
  where
    page c = T.intercalate "/" (take 1 (drop 1 (T.splitOn "/" c.caseId)))

parseOptions :: [String] -> Options
parseOptions = go (Options [] [] False Nothing)
  where
    go o = \case
      "--source" : s : rest -> go o {sources = toText s : o.sources} rest
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

-- | Run one session in a fresh kernel, with five seconds to finish, and
-- judge each of its cases.
runSession :: Source -> FilePath -> [Case] -> IO [Outcome]
runSession src session cs = do
  let base = src.srcDir </> session
  input <- decodeUtf8 <$> readFileBS (base <> ".in")
  expected <- decodeUtf8 <$> readFileBS (base <> ".expected")
  let script = case src.srcSyntax of
        FullFormInputs -> input
        InfixInputs -> unlines (map toFullForm (lines input))
  timeout 5000000 (runScript script >>= \out -> T.length out `seq` pure out) >>= \case
    Nothing -> pure (map (const (Fail "  timed out after 5 s")) cs)
    Just actual -> pure (map (\c -> compareScripts src.srcMessages c.caseInput expected actual) cs)
  where
    -- An input the parser cannot read is left as it is, which the FullForm
    -- reader cannot read either: $Failed, with Syntax::sntx.
    toFullForm line = either (const line) fullForm (parseExpr resolveName line)

-- | Compare by input number, every input or one: each usable expected
-- output with the actual one, structurally up to Orderless order, and the
-- messages as sorted lists of names when the source names them.
compareScripts :: Bool -> Maybe Int -> Text -> Text -> Outcome
compareScripts messages only expected actual =
  case [d | k <- ks, Just d <- [outputDiff k]] <> [d | messages, k <- ks, Just d <- [messageDiff k]] of
    [] -> Pass
    ds -> Fail (T.unlines (map ("  " <>) ds))
  where
    ex = renumber (entries (translate expected))
    ac = entries actual
    ks = maybe (ordNub (map fst (Map.keys ex) <> map fst (Map.keys ac))) pure only
    outputDiff k = case Map.lookup (k, "Out") ex of
      Just [e]
        | "?" `T.isPrefixOf` e -> Nothing
        | otherwise -> case Map.lookup (k, "Out") ac of
            Just [a] | sameOutput e a -> Nothing
            a -> Just ("Out[" <> show k <> "]: expected " <> e <> ", got " <> maybe "nothing" (T.intercalate " | ") a <> syntaxError k)
      _ -> Nothing
    messageDiff k =
      let e = sort (Map.findWithDefault [] (k, "Message") ex)
          a = sort (Map.findWithDefault [] (k, "Message") ac)
       in if e == a then Nothing else Just ("Message[" <> show k <> "]: expected " <> show e <> ", got " <> show a)
    syntaxError k = if "Syntax::sntx" `elem` Map.findWithDefault [] (k, "Message") ac then " (Syntax::sntx)" else ""

-- | The Wolfram corpus's expected file numbers its inputs as the
-- documentation page did (@Out[67]@ for a one-input case), and a script
-- numbers them from 1. Each input has exactly one @Out@ line, so the @k@th
-- label in order is input @k@. The other sources number from 1 already.
renumber :: Entries -> Entries
renumber m = Map.mapKeys (first (\k -> fromMaybe k (Map.lookup k ordinal))) m
  where
    ordinal = Map.fromList (zip (ordNub (map fst (Map.keys m))) [1 ..])

-- | The Wolfram extractor writes a message's symbol as the notebook displays
-- it, so @Infinity::indet@ arrives as @\\[Infinity]::indet@: a normalizer
-- defect (§7.9) the adapter translates.
translate :: Text -> Text
translate = T.replace "\\[Infinity]::" "Infinity::"
