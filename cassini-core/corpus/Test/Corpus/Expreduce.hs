-- | Expreduce's adapter (DESIGN.md §7.8).
--
-- Expreduce's test cases, @ESameTest[expected, input]@ in its
-- @resources/*.m@, are vendored at a pinned commit under
-- @corpus/vendor/expreduce/@ (MIT, D26), and
-- @corpus/tools/extract_expreduce.py@ turns them into the sessions in
-- @cases/@: one per @Tests`Name@ block, as Expreduce's runner shares state,
-- with each expected value normalized by Mathics3's arithmetic (§7.9). The
-- inputs are Expreduce's own text, read by Cassini's infix parser. Expreduce
-- expects no messages, so none are compared.
module Test.Corpus.Expreduce (source) where

import Test.Corpus.Case (Source (..), Syntax (..), loadIndex)

-- | The corpus, under @corpus/vendor/expreduce/cases@.
source :: Source
source = Source {srcName = "expreduce", srcDir = "corpus/vendor/expreduce/cases", srcLoad = loadIndex, srcSyntax = InfixInputs, srcMessages = False}
