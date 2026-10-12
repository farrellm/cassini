-- | The Wolfram documentation corpus's adapter (DESIGN.md §7.8–§7.9).
--
-- @corpus/wolfram-docs/@ is extracted from licensed documentation notebooks
-- by @corpus/tools/extract_wolfram_docs.py@ and is never committed (D27). Its
-- @index.tsv@ lists every case with its status, whether it holds an inexact
-- number, and the @System`@ symbols it mentions, which is what the scope rule
-- reads. A case's @.in@ and @.expected@ are already in 'Cassini.Script''s
-- script format (§7.4), so a case is a whole session, compared input by
-- input, messages included.
module Test.Corpus.Wolfram (source) where

import Data.Text qualified as T
import System.Directory (doesFileExist)
import System.FilePath ((</>))
import Test.Corpus.Case (Case (..), Source (..), Syntax (..))

-- | The corpus, under @corpus/wolfram-docs@.
source :: Source
source = Source {srcName = "wolfram", srcDir = "corpus/wolfram-docs", srcLoad = loadCases, srcSyntax = FullFormInputs, srcMessages = True}

-- | Every case in the index, or 'Nothing' when the corpus is absent: a
-- fresh clone has none (§7.9), and the suite then skips it.
loadCases :: FilePath -> IO (Maybe [Case])
loadCases dir = do
  let index = dir </> "index.tsv"
  present <- doesFileExist index
  if not present
    then pure Nothing
    else Just . mapMaybe row . drop 1 . lines . decodeUtf8 <$> readFileBS index
  where
    row line = case T.splitOn "\t" line of
      cid : status : _inputs : _outputs : _usable : _messages : _prints : inexact : symbols : _ ->
        Just
          Case
            { caseId = cid,
              caseStatus = status,
              caseInexact = inexact /= "0",
              caseSymbols = filter (not . T.null) (T.splitOn "," symbols),
              -- wolfram/Plus/Scope/1 is Plus/Scope/1 under the corpus.
              caseSession = toString (fromMaybe cid (T.stripPrefix "wolfram/" cid)),
              caseInput = Nothing
            }
      _ -> Nothing
