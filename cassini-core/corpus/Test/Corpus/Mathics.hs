-- | Mathics3's adapter (DESIGN.md §7.8).
--
-- Mathics3's test suite is GPL, so @corpus/fetch.sh@ clones it at a pinned
-- commit into the gitignored @corpus/fetched/@ (D26), and
-- @corpus/tools/extract_mathics_tests.py@ reads its @check_evaluation@ calls
-- with Python's @ast@ into sessions under @corpus/fetched/mathics/@: one per
-- test function, split where a case resets the session, with each expected
-- string evaluated once by Mathics3. The inputs are Mathics3's own text,
-- read by Cassini's infix parser. Its expected messages are text without
-- their @symbol::tag@, so they are not compared.
module Test.Corpus.Mathics (source) where

import Test.Corpus.Case (Source (..), Syntax (..), loadIndex)

-- | The corpus, under @corpus/fetched/mathics@.
source :: Source
source = Source {srcName = "mathics", srcDir = "corpus/fetched/mathics", srcLoad = loadIndex, srcSyntax = InfixInputs, srcMessages = False}
