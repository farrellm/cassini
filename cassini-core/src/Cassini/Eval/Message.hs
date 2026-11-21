-- | Messages: the evaluator's report of a user error (DESIGN.md §4.7).
--
-- The evaluator never throws on user error. A malformed expression evaluates
-- to itself and emits a message, which accumulates in the kernel state until
-- the front end drains it. @Print@'s output goes on the same queue, so the
-- two stay in the order they happened (D40). Formatting is the front end's
-- job (L5).
module Cassini.Eval.Message
  ( Message (..),
    MessageTag (..),
    messageName,
    Emitted (..),
    emittedMessage,
  )
where

import Cassini.Core.Expr (Expr)
import Cassini.Core.Symbol (Symbol, symName)

-- | The part of a message name after @::@: @partw@ in @Part::partw@.
newtype MessageTag = MessageTag Text
  deriving newtype (Eq, Ord, Show, IsString, Hashable)

-- | One emitted message: @symbol::tag@, the expressions its template is
-- filled with, and its text, when the session defines one (@f::tag = "…"@,
-- or @General::tag@'s). Resolved when it is emitted, so formatting reads no
-- state; 'Nothing' leaves the front end its own template (§4.7).
data Message = Message
  { msgSymbol :: !Symbol,
    msgTag :: !MessageTag,
    msgArgs :: ![Expr],
    msgText :: !(Maybe Expr)
  }
  deriving stock (Show)

-- | The name as WL prints it and as the golden files compare it:
-- @Part::partw@.
messageName :: Message -> Text
messageName m = m.msgSymbol.symName <> "::" <> coerce m.msgTag

-- | One entry of the queue the front end drains: a message, or the evaluated
-- arguments of one @Print@ (D40).
data Emitted
  = EmittedMessage !Message
  | EmittedOutput ![Expr]
  deriving stock (Show)

-- | The message, if the entry is one.
emittedMessage :: Emitted -> Maybe Message
emittedMessage = \case
  EmittedMessage m -> Just m
  EmittedOutput _ -> Nothing
