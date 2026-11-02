-- | What every corpus adapter produces (DESIGN.md §7.8): cases, each in a
-- session, with what the scope rule reads.
--
-- A session is a script run in one fresh kernel. A Wolfram documentation
-- case is a whole session, and compares every input. An Expreduce or
-- Mathics3 case is one input of a session the case shares with its
-- neighbours, as the source's own runner shares its state, so the session
-- runs once and each case compares its own input.
module Test.Corpus.Case
  ( Case (..),
    Source (..),
    Syntax (..),
    inScope,
    loadIndex,
  )
where

import Data.HashSet qualified as HashSet
import Data.Text qualified as T
import System.Directory (doesFileExist)
import System.FilePath ((</>))

-- | One case.
data Case = Case
  { caseId :: !Text,
    -- | @ok@, or why it is unusable.
    caseStatus :: !Text,
    caseInexact :: !Bool,
    -- | The @System`@ symbols its inputs and outputs mention.
    caseSymbols :: ![Text],
    -- | The session's files, without extension, under the corpus directory.
    caseSession :: !FilePath,
    -- | The input it compares, or every input.
    caseInput :: !(Maybe Int)
  }

-- | How a corpus writes its inputs: FullForm, or the infix syntax, which
-- "Cassini.Syntax.Parser" reads.
data Syntax = FullFormInputs | InfixInputs
  deriving stock (Eq)

-- | A corpus: its name (the prefix of its case IDs and its ratchet's file
-- name), where it is, how to load it, how its inputs are written, and
-- whether its expected messages are names to compare.
data Source = Source
  { srcName :: !Text,
    srcDir :: !FilePath,
    srcLoad :: FilePath -> IO (Maybe [Case]),
    srcSyntax :: !Syntax,
    srcMessages :: !Bool
  }

-- | The scope rule (§7.8): usable, no inexact number while D9 stands, and
-- every @System`@ symbol defined by the registry. A Wolfram case whose
-- unusable outputs are skipped (@partial@) is usable.
inScope :: HashSet Text -> Case -> Bool
inScope defined c =
  c.caseStatus `elem` ["ok", "partial"]
    && not c.caseInexact
    && all (`HashSet.member` defined) c.caseSymbols

-- | The index the Expreduce and Mathics3 extractors write: per case, its ID,
-- status, session, input number, whether it is inexact, and its symbols.
-- 'Nothing' when the corpus is absent.
loadIndex :: FilePath -> IO (Maybe [Case])
loadIndex dir = do
  let index = dir </> "index.tsv"
  present <- doesFileExist index
  if not present
    then pure Nothing
    else Just . mapMaybe row . drop 1 . lines . decodeUtf8 <$> readFileBS index
  where
    row line = case T.splitOn "\t" line of
      [cid, status, session, input, inexact, symbols] ->
        Just
          Case
            { caseId = cid,
              caseStatus = status,
              caseInexact = inexact /= "0",
              caseSymbols = filter (not . T.null) (T.splitOn "," symbols),
              caseSession = toString session,
              caseInput = readMaybe (toString input)
            }
      _ -> Nothing
