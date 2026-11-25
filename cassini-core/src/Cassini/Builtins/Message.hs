{-# LANGUAGE PatternSynonyms #-}

-- | Message control: @Message@, @MessageName@, @Quiet@, @Check@, @Off@, @On@,
-- and @General@, the symbol that holds shared message text (DESIGN.md §4.7,
-- D42).
--
-- Each rule is WL 15.0.1's answer to a probe, run through the Wolfram Cloud
-- MCP on 2026-11-11 (§4.7). The scoping is the kernel's: 'quietly' and
-- 'checking' push a frame that ends however their body exits, and the
-- message handler reads the frames, the switched-off set and the per-input
-- count for @General::stop@. Assigning text, @f::tag = "…"@, is
-- "Cassini.Builtins.Assign"'s.
--
-- Left out, and unevaluated: @Quiet@'s third argument, @Off[]@ and @On[]@
-- without a message name, message groups, @$MessageList@, @Messages@ and the
-- language argument of @f::tag::lang@.
module Cassini.Builtins.Message (definitions, messageNameOf) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, message, sNullE, settled)
import Cassini.Core.Expr (Expr, pattern Call, pattern Str, pattern Sym)
import Cassini.Core.Symbol (Symbol, sList, systemSymbol)
import Cassini.Eval.Kernel (Kernel, MessageNames, checking, emitMessage, evaluate, lookupSymbol, quietly, switchMessage)
import Cassini.Eval.Message (MessageTag (..))
import Cassini.Rules (SymbolInfo (..))
import Data.Map.Strict qualified as Map
import Effectful (Eff, (:>))

-- | The message builtins, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "MessageName" [HoldFirst, Protected, ReadProtected] [down messageNameRule],
    define "Message" [HoldFirst, Protected] [down messageRule],
    define "Quiet" [HoldAll, Protected] [down quietRule],
    define "Check" [HoldAll, Protected] [down checkRule],
    define "Off" [HoldAll, Protected] [down (switch False)],
    define "On" [HoldAll, Protected] [down (switch True)],
    define "General" [Protected] []
  ]

-- | @MessageName[f, "tag"]@, read: the symbol and the tag.
messageNameOf :: Expr -> Maybe (Symbol, MessageTag)
messageNameOf = \case
  Call m [Sym f, Str t] | m == sMessageName -> Just (f, MessageTag t)
  _ -> Nothing

sMessageName :: Symbol
sMessageName = systemSymbol "MessageName"

-- | @f::tag@ is the text the session gave it, if any; otherwise it stays.
messageNameRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
messageNameRule e = case args e of
  [Sym f, Str t] -> Map.lookup t . (.siMessages) <$> lookupSymbol f
  _ -> pure Nothing

-- | @Message[f::tag, e₁, …]@ emits @f::tag@ with the evaluated @eᵢ@ and is
-- @Null@. A first argument that is not a message name stays, with
-- @Message::name@.
messageRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
messageRule e = case args e of
  n : xs
    | Just (f, t) <- messageNameOf n -> Just sNullE <$ emitMessage f t xs
    | otherwise -> Nothing <$ message "Message" "name" [n]
  [] -> pure Nothing

-- | The message names a @Quiet@ or @Check@ is given: one name, or a list of
-- them. 'Nothing' if the argument is neither, so the call stays.
namesOf :: Expr -> Maybe MessageNames
namesOf x = case x of
  Call l xs | l == sList -> Just <$> traverse messageNameOf xs
  _ -> Just . pure <$> messageNameOf x

-- | @Quiet[expr]@ evaluates @expr@ with none of its messages shown;
-- @Quiet[expr, names]@ hides only those named. The value is unchanged, and
-- settled, so that the next round does not evaluate it outside the @Quiet@.
quietRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
quietRule e = case args e of
  [x] -> Just . settled <$> quietly Nothing (evaluate x)
  [x, ns] | Just names <- namesOf ns -> Just . settled <$> quietly names (evaluate x)
  _ -> pure Nothing

-- | @Check[expr, failexpr]@ is @expr@'s value if evaluating it generated no
-- message, and @failexpr@, evaluated, otherwise; with names, only those
-- count. A message a @Quiet@ inside covers, or that is switched off, does
-- not count (§4.7).
checkRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
checkRule e = case args e of
  [x, failure] -> go Nothing x failure
  [x, failure, ns] | Just names <- namesOf ns -> go names x failure
  _ -> pure Nothing
  where
    go names x failure = do
      (v, seen) <- checking names (evaluate x)
      pure (Just (if seen then failure else settled v))

-- | @Off[f::tag, …]@ and @On[f::tag, …]@ switch messages off and on for the
-- session, and are @Null@. Without a message name they stay.
switch :: (Kernel :> es) => Bool -> Expr -> Eff es (Maybe Expr)
switch turnOn e = case traverse messageNameOf (args e) of
  Just names@(_ : _) -> Just sNullE <$ for_ names (uncurry (switchMessage turnOn))
  _ -> pure Nothing
