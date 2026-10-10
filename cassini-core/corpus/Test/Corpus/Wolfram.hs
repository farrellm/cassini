-- | The Wolfram documentation corpus's adapter (DESIGN.md §7.8–§7.9).
--
-- @corpus/wolfram-docs/@ is extracted from licensed documentation notebooks
-- by @corpus/tools/extract_wolfram_docs.py@ and is never committed (D27). Its
-- @index.tsv@ lists every case with its status, whether it holds an inexact
-- number, and the @System`@ symbols it mentions, which is what the scope rule
-- reads. A case's @.in@ and @.expected@ are already in 'Cassini.Script''s
-- script format (§7.4), so a case is a script run in a fresh kernel.
module Test.Corpus.Wolfram
  ( Case (..),
    loadCases,
    inScope,
    casePath,
  )
where

import Data.HashSet qualified as HashSet
import Data.Text qualified as T
import System.Directory (doesFileExist)
import System.FilePath ((</>))

-- | One row of @index.tsv@.
data Case = Case
  { caseId :: !Text,
    caseStatus :: !Text,
    caseInexact :: !Bool,
    caseSymbols :: ![Text]
  }

-- | Every case in the index, or 'Nothing' when the corpus is absent: a
-- fresh clone has none (§7.9), and the suite then skips.
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
              caseSymbols = filter (not . T.null) (T.splitOn "," symbols)
            }
      _ -> Nothing

-- | The scope rule (§7.8): every input usable (status @ok@, or @partial@,
-- whose unusable outputs are skipped), no inexact number while D9 stands,
-- and every @System`@ symbol defined by the registry.
inScope :: HashSet Text -> Case -> Bool
inScope defined c =
  c.caseStatus `elem` ["ok", "partial"]
    && not c.caseInexact
    && all (`HashSet.member` defined) c.caseSymbols

-- | A case's files, without extension: @wolfram/Plus/Scope/1@ is
-- @Plus/Scope/1@ under the corpus directory.
casePath :: FilePath -> Case -> FilePath
casePath dir c = dir </> toString (fromMaybe c.caseId (T.stripPrefix "wolfram/" c.caseId))
