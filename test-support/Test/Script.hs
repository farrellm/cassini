{-# LANGUAGE PatternSynonyms #-}

-- | Reading and comparing the script format (DESIGN.md §7.4) for the suites
-- that compare Cassini with another system's answers: @cassini-corpus@
-- (§7.8) and @cassini-oracle@ (§7.5).
module Test.Script
  ( Entries,
    entries,
    sameOutput,
    canonical,
  )
where

import Cassini.Attributes (isOrderless)
import Cassini.Builtins (standardState)
import Cassini.Core.Expr (Expr, mkApp, pattern App, pattern Sym)
import Cassini.Core.Order (compareCanonical)
import Cassini.Eval.Kernel (KernelState (..))
import Cassini.REPL (resolveName)
import Cassini.Rules (SymbolInfo (..))
import Cassini.Syntax.FullForm (parseFullForm)
import Data.Map.Strict qualified as Map
import Data.Text qualified as T
import Data.Vector qualified as V

-- | A script's output: @Label[k]: text@ lines, by input number and label
-- (@Out@, @Message@, @Trace@), in order.
type Entries = Map (Int, Text) [Text]

-- | Parse a script's output.
entries :: Text -> Entries
entries = Map.fromListWith (flip (<>)) . mapMaybe entry . lines
  where
    entry line = do
      let (label, rest) = T.breakOn "[" line
      (k, body) <- case T.breakOn "]: " (T.drop 1 rest) of
        (n, b) | not (T.null b) -> (,T.drop 3 b) <$> readMaybe (toString n)
        _ -> Nothing
      pure ((k, label), [body])

-- | Equal as printed, or equal once each is read and put in canonical order
-- under @Orderless@ heads, without evaluating either: the order of
-- arguments is D8's known divergence, not worth an entry per case (§7.8).
sameOutput :: Text -> Text -> Bool
sameOutput e a = e == a || (canonical <$> parse e) == (canonical <$> parse a)
  where
    parse t = rightToMaybe (parseFullForm resolveName t)

-- | Sort the arguments of every @Orderless@ head by 'compareCanonical',
-- evaluating nothing.
canonical :: Expr -> Expr
canonical = \case
  App h as ->
    let as' = V.map canonical as
        sorted = case h of
          Sym s | Just si <- Map.lookup s standardState.ksSymbols, isOrderless si.siAttributes -> V.fromList (sortBy compareCanonical (V.toList as'))
          _ -> as'
     in mkApp (canonical h) sorted
  e -> e
