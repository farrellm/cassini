-- | Messages: the evaluator's report of a user error (DESIGN.md §4.7).
--
-- The evaluator never throws on user error. A malformed expression evaluates
-- to itself and emits a message, which accumulates in the kernel state until
-- the front end drains it. Formatting is the front end's job (L5).
module Cassini.Eval.Message
  ( Message (..),
    MessageTag (..),
    messageName,
  )
where

import Cassini.Core.Expr (Expr)
import Cassini.Core.Symbol (Symbol, symName)

-- | The part of a message name after @::@: @partw@ in @Part::partw@.
newtype MessageTag = MessageTag Text
  deriving newtype (Eq, Ord, Show, IsString)

-- | One emitted message: @symbol::tag@ and the expressions its template is
-- filled with.
data Message = Message
  { msgSymbol :: !Symbol,
    msgTag :: !MessageTag,
    msgArgs :: ![Expr]
  }
  deriving stock (Show)

-- | The name as WL prints it and as the golden files compare it:
-- @Part::partw@.
messageName :: Message -> Text
messageName m = m.msgSymbol.symName <> "::" <> coerce m.msgTag
