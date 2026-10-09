{-# LANGUAGE PatternSynonyms #-}

-- | Assignment and attributes: @Set@, @SetDelayed@, @UpSet@,
-- @UpSetDelayed@, @TagSet@, @TagSetDelayed@, @Unset@, @Attributes@,
-- @SetAttributes@, @ClearAttributes@, @Protect@ and @Unprotect@
-- (DESIGN.md §2.2, §4.2).
--
-- An assignment writes a user rule into one of the four tables (§4.2): an own
-- value for a symbol, a downvalue for @f[…]@, a subvalue for @f[…][…]@ (keyed
-- on the innermost head symbol), and upvalues for @UpSet@. The left-hand
-- side's arguments are evaluated, unless its head holds them or it is
-- wrapped in @HoldPattern@; its head is not. A protected tag refuses the
-- write with WL's message: @Set::wrsym@ for a symbol, @Set::write@ for a
-- tag.
module Cassini.Builtins.Assign (definitions) where

import Cassini.Attributes (Attribute (..), attributeFromName, attributeList, attributeName, holdsArgument, isProtected)
import Cassini.Attributes qualified as Attributes
import Cassini.Builtins.Define (Definition, args, define, down, message, sFailedE, sNullE)
import Cassini.Core.Expr (Expr, apply, exprArgs, mkApp, mkString, pattern App, pattern Sym)
import Cassini.Core.Symbol (Symbol, sBlank, sBlankNullSequence, sBlankSequence, sCondition, sHoldPattern, sList, sPattern, sPatternTest, symName, systemSymbol)
import Cassini.Eval.Kernel (Kernel, evaluate, lookupSymbol, modifySymbol)
import Cassini.Rules (Origin (..), RuleBody (..), SymbolInfo (..), ValueKind (..), insertRule, mkRule, modifyRules, removeRule, rulesOf)
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | The assignment and attribute builtins, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "Set" [HoldFirst, Protected, SequenceHold] [down (assignment "Set" Immediate)],
    define "SetDelayed" [HoldAll, Protected, SequenceHold] [down (assignment "SetDelayed" Delayed)],
    define "UpSet" [HoldFirst, Protected, SequenceHold] [down (upAssignment "UpSet" Immediate)],
    define "UpSetDelayed" [HoldAll, Protected, SequenceHold] [down (upAssignment "UpSetDelayed" Delayed)],
    define "TagSet" [HoldAll, Protected, SequenceHold] [down (tagAssignment "TagSet" Immediate)],
    define "TagSetDelayed" [HoldAll, Protected, SequenceHold] [down (tagAssignment "TagSetDelayed" Delayed)],
    define "Unset" [HoldFirst, Listable, Protected, ReadProtected] [down unset],
    define "Attributes" [HoldAll, Listable, Protected] [down attributes],
    define "SetAttributes" [HoldFirst, Protected] [down (changeAttributes "SetAttributes" Attributes.insert)],
    define "ClearAttributes" [HoldFirst, Protected] [down (changeAttributes "ClearAttributes" Attributes.delete)],
    define "Protect" [HoldAll, Protected] [down (protection "Protect" True)],
    define "Unprotect" [HoldAll, Protected] [down (protection "Unprotect" False)],
    define "$Failed" [Protected] []
  ]

-- | Which table an assignment writes.
data Target = Target !Symbol !ValueKind

-- | The table a left-hand side belongs in, seen through @HoldPattern@.
target :: Expr -> Maybe Target
target lhs = case unholdPattern lhs of
  Sym s -> Just (Target s OwnValue)
  App (Sym f) _ -> Just (Target f DownValue)
  App h@(App _ _) _ -> (`Target` SubValue) <$> tagSymbol h
  _ -> Nothing

-- | The symbol an expression's rules are keyed on: itself, or its innermost
-- head symbol. Seen through pattern objects, so the tag of @y_g@ is @g@, as
-- an upvalue @f[y_g] ^:= …@ requires.
tagSymbol :: Expr -> Maybe Symbol
tagSymbol = \case
  Sym s -> Just s
  App (Sym h) as
    | h == sPattern, [_, p] <- V.toList as -> tagSymbol p
    | h `elem` [sHoldPattern, sCondition, sPatternTest], p : _ <- V.toList as -> tagSymbol p
    | h `elem` [sBlank, sBlankSequence, sBlankNullSequence] -> case V.toList as of
        [c] -> tagSymbol c
        _ -> Nothing
  App h _ -> tagSymbol h
  _ -> Nothing

unholdPattern :: Expr -> Expr
unholdPattern = \case
  App (Sym h) as | h == sHoldPattern, [x] <- V.toList as -> unholdPattern x
  e -> e

-- | Evaluate the left-hand side's arguments, as WL does, unless the head
-- holds them or the whole is in @HoldPattern@. The head is not evaluated.
prepareLhs :: (Kernel :> es) => Expr -> Eff es Expr
prepareLhs lhs = case lhs of
  App (Sym h) _ | h == sHoldPattern -> pure lhs
  App h as -> do
    attrs <- case h of
      Sym s -> (\si -> si.siAttributes) <$> lookupSymbol s
      _ -> pure mempty
    let n = V.length as
    mkApp h <$> V.imapM (\i a -> if holdsArgument attrs (i + 1) n then pure a else evaluate a) as
  _ -> pure lhs

-- | Write one user rule, unless the tag is protected or there is no tag.
-- 'True' when it was written.
write :: (Kernel :> es) => Text -> Expr -> RuleBody -> Eff es Bool
write name lhs body = case target lhs of
  Nothing -> False <$ message name "setraw" [lhs]
  Just (Target s k) -> do
    info <- lookupSymbol s
    if isProtected info.siAttributes
      then do
        if k == OwnValue then message name "wrsym" [Sym s] else message name "write" [Sym s, lhs]
        pure False
      else True <$ modifySymbol s (modifyRules k (insertRule (mkRule User lhs body)))

-- | @Set@ and @SetDelayed@. @Set@ returns its (evaluated) right-hand side,
-- and @SetDelayed@ returns @Null@, or @$Failed@ when the write is refused.
-- @{x, y} = {1, 2}@ assigns elementwise.
assignment :: (Kernel :> es) => Text -> (Expr -> RuleBody) -> Expr -> Eff es (Maybe Expr)
assignment name body e = case args e of
  [App (Sym l) ls, rhs]
    | l == sList,
      name == "Set" -> case rhs of
        App (Sym l') rs
          | l' == sList,
            V.length rs == V.length ls -> do
              V.zipWithM_ (\x v -> prepareLhs x >>= \x' -> write name x' (body v)) ls rs
              pure (Just rhs)
        _ -> Just rhs <$ message name "shape" [apply sList (V.toList ls), rhs]
  [lhs, rhs] -> do
    lhs' <- prepareLhs lhs
    ok <- write name lhs' (body rhs)
    pure (Just (result ok rhs))
  _ -> pure Nothing
  where
    result ok rhs
      | name == "Set" = rhs
      | ok = sNullE
      | otherwise = sFailedE

-- | @UpSet@ and @UpSetDelayed@: an upvalue for the tag of every argument.
upAssignment :: (Kernel :> es) => Text -> (Expr -> RuleBody) -> Expr -> Eff es (Maybe Expr)
upAssignment name body e = case args e of
  [lhs, rhs] -> do
    lhs' <- prepareLhs lhs
    case ordNub (mapMaybe tagSymbol (V.toList (exprArgs (unholdPattern lhs')))) of
      [] -> Just sFailedE <$ message name "nosym" [lhs']
      tags -> do
        for_ tags $ \s -> do
          info <- lookupSymbol s
          if isProtected info.siAttributes
            then message name "write" [Sym s, lhs']
            else modifySymbol s (modifyRules UpValue (insertRule (mkRule User lhs' (body rhs))))
        pure (Just (if name == "UpSet" then rhs else sNullE))
  _ -> pure Nothing

-- | @TagSet@ and @TagSetDelayed@: the rule goes on the named tag, as a
-- down, sub or own value if the tag is the left-hand side's own, else as an
-- upvalue if it is an argument's.
tagAssignment :: (Kernel :> es) => Text -> (Expr -> RuleBody) -> Expr -> Eff es (Maybe Expr)
tagAssignment name body e = case args e of
  [Sym s, lhs, rhs0] -> do
    rhs <- if name == "TagSet" then evaluate rhs0 else pure rhs0
    lhs' <- prepareLhs lhs
    let own = target lhs'
        argTags = mapMaybe tagSymbol (V.toList (exprArgs (unholdPattern lhs')))
        result = if name == "TagSet" then rhs else sNullE
    case own of
      Just (Target t _) | t == s -> do
        ok <- write name lhs' (body rhs)
        pure (Just (if ok then result else sFailedE))
      _
        | s `elem` argTags -> do
            info <- lookupSymbol s
            if isProtected info.siAttributes
              then Just sFailedE <$ message name "write" [Sym s, lhs']
              else Just result <$ modifySymbol s (modifyRules UpValue (insertRule (mkRule User lhs' (body rhs))))
        | otherwise -> Just sFailedE <$ message name "tagnf" [Sym s, lhs']
  _ -> pure Nothing

-- | @Unset[lhs]@: remove the user rule with this left-hand side. @Null@, or
-- @$Failed@ with @Unset::norep@ when there is none.
unset :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
unset e = case args e of
  [lhs] -> do
    lhs' <- prepareLhs lhs
    case target lhs' of
      Nothing -> Just sFailedE <$ message "Unset" "norep" [lhs']
      Just (Target s k) -> do
        info <- lookupSymbol s
        let (removed, rules') = removeRule lhs' (rulesOf k info)
        if removed
          then Just sNullE <$ modifySymbol s (modifyRules k (const rules'))
          else Just sFailedE <$ message "Unset" "norep" [lhs']
  _ -> pure Nothing

-- | @Attributes[s]@: the list of attribute names, in WL's order (by name).
attributes :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
attributes e = case args e of
  [Sym s] -> do
    info <- lookupSymbol s
    pure (Just (apply sList [Sym (systemSymbol (attributeName a)) | a <- attributeList info.siAttributes]))
  _ -> pure Nothing

-- | @SetAttributes@ and @ClearAttributes@: one symbol or a list, and one
-- attribute or a list. A @Locked@ symbol refuses with @Attributes::locked@.
changeAttributes :: (Kernel :> es) => Text -> (Attribute -> Attributes.AttributeSet -> Attributes.AttributeSet) -> Expr -> Eff es (Maybe Expr)
changeAttributes _ f e = case args e of
  [ss, as0] -> do
    as <- evaluate as0
    case (symbolList ss, traverse attributeOf (listOf as)) of
      (Just syms, Just attrs) -> do
        for_ syms $ \s -> do
          info <- lookupSymbol s
          if Attributes.member Locked info.siAttributes
            then message "Attributes" "locked" [Sym s]
            else modifySymbol s (\si -> si {siAttributes = foldr f si.siAttributes attrs})
        pure (Just sNullE)
      _ -> pure Nothing
  _ -> pure Nothing
  where
    attributeOf = \case
      Sym a -> attributeFromName a.symName
      _ -> Nothing

-- | @Protect@ and @Unprotect@: the names of the symbols whose protection
-- changed, as strings.
protection :: (Kernel :> es) => Text -> Bool -> Expr -> Eff es (Maybe Expr)
protection name protect e = case traverse symbolOf (args e) of
  Just syms -> do
    changed <- fmap catMaybes . forM syms $ \s -> do
      info <- lookupSymbol s
      let was = isProtected info.siAttributes
      if Attributes.member Locked info.siAttributes
        then Nothing <$ message name "locked" [Sym s]
        else
          if was == protect
            then pure Nothing
            else do
              modifySymbol s (\si -> si {siAttributes = (if protect then Attributes.insert else Attributes.delete) Protected si.siAttributes})
              pure (Just (mkString s.symName))
    pure (Just (apply sList changed))
  Nothing -> pure Nothing
  where
    symbolOf = \case
      Sym s -> Just s
      _ -> Nothing

symbolList :: Expr -> Maybe [Symbol]
symbolList = traverse (\case Sym s -> Just s; _ -> Nothing) . listOf

listOf :: Expr -> [Expr]
listOf = \case
  App (Sym l) xs | l == sList -> V.toList xs
  x -> [x]
