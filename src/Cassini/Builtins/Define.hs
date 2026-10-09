{-# LANGUAGE PatternSynonyms #-}

-- | The shape every builtin module exports, and the helpers they share.
--
-- A builtin is a symbol's attributes and its native rules. Each module of
-- @Cassini.Builtins.*@ exports a list of 'Definition's, and
-- "Cassini.Builtins" assembles them into one kernel state, numbering the
-- implementations (§4.2: a rule holds a 'Cassini.Rules.BuiltinId', not a
-- function).
module Cassini.Builtins.Define
  ( Definition (..),
    NativeRule (..),
    define,
    down,
    up,
    own,
    sub,
    args,
    message,
    symbolHeaded,
    sym,
    sNullE,
    sTrueE,
    sFalseE,
    sFailedE,
  )
where

import Cassini.Attributes (Attribute)
import Cassini.Core.Expr (Expr, exprArgs, pattern App, pattern Sym)
import Cassini.Core.Symbol (Symbol, sFalse, sNull, sTrue, systemSymbol)
import Cassini.Eval.Kernel (BuiltinFn (..), Kernel, emitMessage)
import Cassini.Eval.Message (MessageTag (..))
import Cassini.Rules (ValueKind (..))
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | One native rule: which table it goes in, and its implementation. A
-- native rule is never matched by pattern: its implementation decides, and
-- answers 'Nothing' when it does not apply.
data NativeRule = NativeRule
  { nrKind :: !ValueKind,
    nrFn :: !BuiltinFn
  }

-- | A builtin symbol: its attributes and its native rules, in order.
data Definition = Definition
  { defSymbol :: !Symbol,
    defAttributes :: ![Attribute],
    defRules :: ![NativeRule]
  }

-- | A @System`@ symbol with attributes and rules.
define :: Text -> [Attribute] -> [NativeRule] -> Definition
define name = Definition (systemSymbol name)

-- | A built-in downvalue.
down :: (forall es. (Kernel :> es) => Expr -> Eff es (Maybe Expr)) -> NativeRule
down f = NativeRule DownValue (BuiltinFn f)

-- | A built-in upvalue.
up :: (forall es. (Kernel :> es) => Expr -> Eff es (Maybe Expr)) -> NativeRule
up f = NativeRule UpValue (BuiltinFn f)

-- | A built-in own value.
own :: (forall es. (Kernel :> es) => Expr -> Eff es (Maybe Expr)) -> NativeRule
own f = NativeRule OwnValue (BuiltinFn f)

-- | A built-in subvalue.
sub :: (forall es. (Kernel :> es) => Expr -> Eff es (Maybe Expr)) -> NativeRule
sub f = NativeRule SubValue (BuiltinFn f)

-- | The arguments, as a list.
args :: Expr -> [Expr]
args = V.toList . exprArgs

-- | Emit @System`symbol::tag@.
message :: (Kernel :> es) => Text -> Text -> [Expr] -> Eff es ()
message s t = emitMessage (systemSymbol s) (MessageTag t)

-- | Whether the expression is an application of this symbol.
symbolHeaded :: Symbol -> Expr -> Bool
symbolHeaded s = \case
  App (Sym h) _ -> h == s
  _ -> False

-- | A @System`@ symbol as an expression.
sym :: Text -> Expr
sym = Sym . systemSymbol

-- | @Null@, @True@, @False@ and @$Failed@.
sNullE, sTrueE, sFalseE, sFailedE :: Expr
sNullE = Sym sNull
sTrueE = Sym sTrue
sFalseE = Sym sFalse
sFailedE = sym "$Failed"
