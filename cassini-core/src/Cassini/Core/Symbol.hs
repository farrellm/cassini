{-# OPTIONS_GHC -fno-full-laziness -fno-cse #-}

-- | Interned symbol names with contexts (DESIGN.md §3.2).
--
-- Symbols are interned unconditionally, so equality and map-key order are an
-- 'Int' comparison. That order is allocation order and therefore
-- session-dependent: anything a user can see sorts with 'compareSymbolName'.
--
-- This module and "Cassini.Core.Intern" are the tree's only importers of
-- "System.IO.Unsafe" (§2.3).
module Cassini.Core.Symbol
  ( Symbol,
    symId,
    symContext,
    symName,
    symbol,
    systemSymbol,
    globalSymbol,
    compareSymbolName,
    fullName,

    -- * Well-known symbols
    sPlus,
    sTimes,
    sPower,
    sFactorial,
    sList,
    sInteger,
    sRational,
    sString,
    sSymbol,

    -- * Kernel symbols
    sHold,
    sSequence,
    sUnevaluated,
    sEvaluate,
    sIndeterminate,
    sComplexInfinity,
    sDirectedInfinity,
    sTrue,
    sFalse,
    sNull,
    sFunction,
    sRule,
    sRuleDelayed,
    sHoldPattern,
    sBlank,
    sBlankSequence,
    sBlankNullSequence,
    sPattern,
    sCondition,
    sPatternTest,
    sAlternatives,
    sRepeated,
    sRepeatedNull,
    sOptional,
    sExcept,
    sVerbatim,
  )
where

import Data.HashMap.Strict qualified as HashMap
import System.IO.Unsafe (unsafePerformIO)
import Text.Show (Show (showsPrec), showString)

-- | An interned symbol. Construct with 'symbol'.
data Symbol = Symbol
  { -- | Allocation serial; unique per (context, name) within a session.
    symId :: {-# UNPACK #-} !Int,
    -- | The context, with its trailing backquote: @System`@, @Global`@.
    symContext :: !Text,
    -- | The name within the context.
    symName :: !Text
  }

instance Eq Symbol where
  (==) = (==) `on` symId

-- | Map-key order only: interning order, therefore session-dependent.
instance Ord Symbol where
  compare = compare `on` symId

instance Hashable Symbol where
  hashWithSalt s x = hashWithSalt s x.symId

instance NFData Symbol where
  rnf x = rnf x.symId

instance Show Symbol where
  showsPrec _ x = showString (toString x.symName)

-- | Cohen's O-2: the only symbol comparison any output may depend on. Names
-- first, context second: context first would sort every @Global`@ symbol
-- before every @System`@ one. Names compare by code point, so @Pi@ sorts
-- before @x@.
--
-- >>> compareSymbolName (globalSymbol "x") (systemSymbol "Pi")
-- GT
compareSymbolName :: Symbol -> Symbol -> Ordering
compareSymbolName = comparing symName <> comparing symContext

-- | The context-qualified name, @System`Plus@.
fullName :: Symbol -> Text
fullName x = x.symContext <> x.symName

-- | The symbol with this context and name, allocating it on first use.
symbol :: Text -> Text -> Symbol
symbol ctx name = unsafePerformIO (internSymbol ctx name)
{-# NOINLINE symbol #-}

-- | A symbol in @System`@.
systemSymbol :: Text -> Symbol
systemSymbol = symbol "System`"

-- | A symbol in @Global`@.
globalSymbol :: Text -> Symbol
globalSymbol = symbol "Global`"

data SymbolTable = SymbolTable !Int !(HashMap.HashMap (Text, Text) Symbol)

symbolTable :: IORef SymbolTable
symbolTable = unsafePerformIO (newIORef (SymbolTable 0 HashMap.empty))
{-# NOINLINE symbolTable #-}

-- | Lookup-or-allocate as one atomic step, so two threads interning the same
-- name get the same symbol.
internSymbol :: Text -> Text -> IO Symbol
internSymbol ctx name = atomicModifyIORef' symbolTable $ \t@(SymbolTable next table) ->
  case HashMap.lookup (ctx, name) table of
    Just s -> (t, s)
    Nothing ->
      let s = Symbol next ctx name
       in (SymbolTable (next + 1) (HashMap.insert (ctx, name) s table), s)

-- | @System`Plus@.
sPlus :: Symbol
sPlus = systemSymbol "Plus"

-- | @System`Times@.
sTimes :: Symbol
sTimes = systemSymbol "Times"

-- | @System`Power@.
sPower :: Symbol
sPower = systemSymbol "Power"

-- | @System`Factorial@.
sFactorial :: Symbol
sFactorial = systemSymbol "Factorial"

-- | @System`List@.
sList :: Symbol
sList = systemSymbol "List"

-- | @System`Integer@, the head of an integer.
sInteger :: Symbol
sInteger = systemSymbol "Integer"

-- | @System`Rational@, the head of a fraction.
sRational :: Symbol
sRational = systemSymbol "Rational"

-- | @System`String@, the head of a string.
sString :: Symbol
sString = systemSymbol "String"

-- | @System`Symbol@, the head of a symbol.
sSymbol :: Symbol
sSymbol = systemSymbol "Symbol"

-- | @System`Hold@, the evaluator wraps a cut-off result in it (§4.3).
sHold :: Symbol
sHold = systemSymbol "Hold"

-- | @System`Sequence@, spliced into argument lists (step 5).
sSequence :: Symbol
sSequence = systemSymbol "Sequence"

-- | @System`Unevaluated@, stripped by step 6.
sUnevaluated :: Symbol
sUnevaluated = systemSymbol "Unevaluated"

-- | @System`Evaluate@, forces a held argument (step 4).
sEvaluate :: Symbol
sEvaluate = systemSymbol "Evaluate"

-- | @System`Indeterminate@, absorbs numeric functions (§4.15).
sIndeterminate :: Symbol
sIndeterminate = systemSymbol "Indeterminate"

-- | @System`ComplexInfinity@, the result of @1/0@ (§4.7).
sComplexInfinity :: Symbol
sComplexInfinity = systemSymbol "ComplexInfinity"

-- | @System`DirectedInfinity@, an infinity with a direction (§4.15).
sDirectedInfinity :: Symbol
sDirectedInfinity = systemSymbol "DirectedInfinity"

-- | @System`True@.
sTrue :: Symbol
sTrue = systemSymbol "True"

-- | @System`False@.
sFalse :: Symbol
sFalse = systemSymbol "False"

-- | @System`Null@.
sNull :: Symbol
sNull = systemSymbol "Null"

-- | @System`Function@, a pure function, whose third argument gives attributes (§4.13).
sFunction :: Symbol
sFunction = systemSymbol "Function"

-- | @System`Rule@.
sRule :: Symbol
sRule = systemSymbol "Rule"

-- | @System`RuleDelayed@.
sRuleDelayed :: Symbol
sRuleDelayed = systemSymbol "RuleDelayed"

-- | @System`HoldPattern@, a pattern held unevaluated (§4.5.1).
sHoldPattern :: Symbol
sHoldPattern = systemSymbol "HoldPattern"

-- | @System`Blank@.
sBlank :: Symbol
sBlank = systemSymbol "Blank"

-- | @System`BlankSequence@.
sBlankSequence :: Symbol
sBlankSequence = systemSymbol "BlankSequence"

-- | @System`BlankNullSequence@.
sBlankNullSequence :: Symbol
sBlankNullSequence = systemSymbol "BlankNullSequence"

-- | @System`Pattern@.
sPattern :: Symbol
sPattern = systemSymbol "Pattern"

-- | @System`Condition@.
sCondition :: Symbol
sCondition = systemSymbol "Condition"

-- | @System`PatternTest@.
sPatternTest :: Symbol
sPatternTest = systemSymbol "PatternTest"

-- | @System`Alternatives@.
sAlternatives :: Symbol
sAlternatives = systemSymbol "Alternatives"

-- | @System`Repeated@.
sRepeated :: Symbol
sRepeated = systemSymbol "Repeated"

-- | @System`RepeatedNull@.
sRepeatedNull :: Symbol
sRepeatedNull = systemSymbol "RepeatedNull"

-- | @System`Optional@.
sOptional :: Symbol
sOptional = systemSymbol "Optional"

-- | @System`Except@.
sExcept :: Symbol
sExcept = systemSymbol "Except"

-- | @System`Verbatim@.
sVerbatim :: Symbol
sVerbatim = systemSymbol "Verbatim"
