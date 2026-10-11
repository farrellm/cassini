{-# LANGUAGE PatternSynonyms #-}

-- | Registry assembly: one 'KernelState' with every builtin installed
-- (DESIGN.md §2.2).
--
-- Each builtin module exports 'Definition's. 'install' gives every native
-- rule an id, puts the implementation in the state's builtin table and a
-- 'Native' rule on the symbol's table (§4.2), and sets the symbol's
-- attributes. The registry also defines the attribute-only symbols the
-- evaluator itself relies on: @Hold@ and its relatives, @Sequence@,
-- @Unevaluated@, @Function@, the pattern heads, and the Boolean constants.
module Cassini.Builtins
  ( standardState,
    definitions,
    install,
    systemNames,
  )
where

import Cassini.Attributes (Attribute (..), attributeName, attributeSet)
import Cassini.Builtins.Arithmetic qualified as Arithmetic
import Cassini.Builtins.Assign qualified as Assign
import Cassini.Builtins.Define (Definition (..), NativeRule (..), args, define, down)
import Cassini.Builtins.Pattern qualified as Pattern
import Cassini.Builtins.Structural qualified as Structural
import Cassini.Core.Expr (apply, pattern Sym)
import Cassini.Core.Symbol (sBlankNullSequence, sSequence, symName)
import Cassini.Eval.Kernel (KernelState (..), emptyState)
import Cassini.Rules (BuiltinId (..), Origin (..), RuleBody (..), SymbolInfo (..), ValueKind (..), emptyInfo, insertRule, mkRule, modifyRules)
import Data.HashSet qualified as HashSet
import Data.IntMap.Strict qualified as IntMap
import Data.Map.Strict qualified as Map

-- | Every builtin, installed into an empty state. Each session, script and
-- corpus case starts from this.
standardState :: KernelState
standardState = install definitions emptyState

-- | Every builtin definition, in installation order.
definitions :: [Definition]
definitions = kernel <> attributeSymbols <> Arithmetic.definitions <> Structural.definitions <> Pattern.definitions <> Assign.definitions

-- | The attribute names as @System`@ symbols, so that the @Flat@ a user
-- writes is the @Flat@ that @Attributes@ returns.
attributeSymbols :: [Definition]
attributeSymbols = [define (attributeName a) [Protected] [] | a <- universe]

-- | The symbols the evaluator and the matcher give meaning to. They have
-- attributes and, for @Evaluate@, one rule; the meaning is in the steps of
-- §4.4 and in "Cassini.Pattern", keyed on the attributes, never on the name
-- (§4.4: no step may branch on @Hold@).
kernel :: [Definition]
kernel =
  [ define "List" [Locked, Protected] [],
    define "Hold" [HoldAll, Protected] [],
    define "HoldForm" [HoldAll, Protected] [],
    define "HoldComplete" [HoldAllComplete, Protected] [],
    define "HoldPattern" [HoldAll, Protected] [],
    define "Unevaluated" [HoldAllComplete, Protected] [],
    define "Sequence" [Protected] [],
    define "Evaluate" [Protected] [down evaluateRule],
    define "Function" [HoldAll, Protected] [],
    define "Rule" [Protected, SequenceHold] [],
    define "RuleDelayed" [HoldRest, Protected, SequenceHold] [],
    define "Blank" [Protected] [],
    define "BlankSequence" [Protected] [],
    define "BlankNullSequence" [Protected] [],
    define "Pattern" [HoldFirst, Protected] [],
    define "Condition" [HoldAll, Protected] [],
    define "PatternTest" [HoldRest, Protected] [],
    define "Alternatives" [Protected] [],
    define "Except" [Protected] [],
    define "Verbatim" [Protected] [],
    define "Optional" [Protected] [],
    define "Repeated" [Protected] [],
    define "RepeatedNull" [Protected] [],
    -- The heads of the atoms, which Head returns and FullForm reads
    -- (Rational[1, 2] is a number).
    define "Integer" [Protected] [],
    define "Rational" [Protected] [],
    define "String" [Protected] [],
    define "Symbol" [Protected] [],
    define "True" [Locked, Protected] [],
    define "False" [Locked, Protected] [],
    define "Null" [Locked, Protected] []
  ]
  where
    -- Evaluate[x] is x; with several arguments, their Sequence.
    evaluateRule e = pure $ case args e of
      [x] -> Just x
      xs -> Just (apply sSequence xs)

-- | Install definitions: attributes are added, and each native rule gets the
-- next id. A native rule's left-hand side is never matched (its
-- implementation decides), so it records only where the rule lives:
-- @s[___]@, or @s@ for an own value.
install :: [Definition] -> KernelState -> KernelState
install defs s0 = foldl' installOne s0 defs
  where
    installOne st d =
      let st' = st {ksSymbols = Map.alter (Just . addAttributes d . fromMaybe emptyInfo) d.defSymbol st.ksSymbols}
       in foldl' (installRule d) st' d.defRules
    addAttributes d si = si {siAttributes = si.siAttributes <> attributeSet d.defAttributes}
    installRule d st r =
      let i = IntMap.size st.ksBuiltins
          lhs = case r.nrKind of
            OwnValue -> Sym d.defSymbol
            _ -> apply d.defSymbol [apply sBlankNullSequence []]
          rule = mkRule Builtin lhs (Native (BuiltinId i))
       in st
            { ksBuiltins = IntMap.insert i r.nrFn st.ksBuiltins,
              ksSymbols = Map.adjust (modifyRules r.nrKind (insertRule rule)) d.defSymbol st.ksSymbols
            }

-- | The names of the @System`@ symbols the registry defines: what the
-- FullForm reader resolves to @System`@, and what the corpus scope rule
-- counts as implemented (§7.8).
systemNames :: HashSet Text
systemNames = HashSet.fromList [d.defSymbol.symName | d <- definitions]
