{-# LANGUAGE PatternSynonyms #-}

-- | The session's history: @In@, @Out@ and @$Line@ (DESIGN.md §4.10).
--
-- The front end, script mode or the interactive loop, records each input
-- with 'recordLine': @In[k]@ holds the input unevaluated, @Out[k]@ its
-- result, and @$Line@ the number the next input will have. @%@ is
-- @Out[]@, the last output, and @%%…@ is @Out[-k]@, counted back from
-- @$Line@; both are built-in downvalues of @Out@. The history is ordinary
-- user rules on protected symbols, written past the protection as the
-- kernel's own bookkeeping, as WL keeps it.
module Cassini.Builtins.Session (definitions, recordLine) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, own)
import Cassini.Core.Expr (Expr, apply, pattern Int_, pattern Sym)
import Cassini.Core.Symbol (Symbol, systemSymbol)
import Cassini.Eval.Kernel (Kernel, evaluate, modifySymbol)
import Cassini.Rules (Origin (..), RuleBody (..), ValueKind (..), insertRule, mkRule, modifyRules)
import Effectful (Eff, (:>))

-- | @In@, @Out@ and @$Line@, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "In" [Listable, Protected] [],
    define "Out" [Listable, NHoldFirst, Protected] [down relative],
    define "$Line" [] [own (const (pure (Just (Int_ 1))))]
  ]

sIn, sOut, sLine :: Symbol
sIn = systemSymbol "In"
sOut = systemSymbol "Out"
sLine = systemSymbol "$Line"

-- | @Out[]@ is @Out[$Line - 1]@, and @Out[-k]@ is @Out[$Line - k]@.
relative :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
relative e = case args e of
  [] -> back 1
  [Int_ k] | k < 0 -> back (negate k)
  _ -> pure Nothing
  where
    back k =
      evaluate (Sym sLine) >>= \case
        Int_ line | line - k >= 1 -> pure (Just (apply sOut [Int_ (line - k)]))
        _ -> pure Nothing

-- | Record input @k@: @In[k]@ is the input, held, @Out[k]@ the result, and
-- @$Line@ becomes @k + 1@.
recordLine :: (Kernel :> es) => Integer -> Expr -> Expr -> Eff es ()
recordLine k input output = do
  let lhs h = apply h [Int_ k]
  modifySymbol sIn (modifyRules DownValue (insertRule (mkRule User (lhs sIn) (Delayed input))))
  modifySymbol sOut (modifyRules DownValue (insertRule (mkRule User (lhs sOut) (Immediate output))))
  modifySymbol sLine (modifyRules OwnValue (insertRule (mkRule User (Sym sLine) (Immediate (Int_ (k + 1))))))
