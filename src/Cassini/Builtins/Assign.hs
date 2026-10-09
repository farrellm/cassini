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
import Cassini.Core.Expr (Expr, apply, exprArgs, mkApp, mkString, pattern App, pattern Int_, pattern Str, pattern Sym)
import Cassini.Core.Symbol (Symbol, globalSymbol, sBlank, sBlankNullSequence, sBlankSequence, sCondition, sHoldPattern, sList, sPattern, sPatternTest, symName, systemSymbol)
import Cassini.Eval.Kernel (Kernel, evaluate, lookupSymbol, modifySymbol)
import Cassini.Pattern (unholdPattern)
import Cassini.Rules (Origin (..), Rule (..), RuleBody (..), SymbolInfo (..), ValueKind (..), hasRules, insertRule, mkRule, modifyRules, removeRule, ruleSetToList, rulesOf)
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
    define "SetAttributes" [HoldFirst, Protected] [down (changeAttributes Attributes.insert)],
    define "ClearAttributes" [HoldFirst, Protected] [down (changeAttributes Attributes.delete)],
    define "Protect" [HoldAll, Protected] [down (protection True)],
    define "Unprotect" [HoldAll, Protected] [down (protection False)],
    define "$Failed" [Protected] []
  ]

-- | Which table an assignment writes.
data Target = Target !Symbol !ValueKind

-- | The table a left-hand side belongs in, seen through @HoldPattern@ and a
-- condition.
target :: Expr -> Maybe Target
target lhs = case lhsCore lhs of
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

-- | The left-hand side seen through @HoldPattern@ and any condition on it:
-- @f[x_] /; test := rhs@ is a rule for @f@, and @g /: f[g[x_]] /; test := rhs@
-- an upvalue for @g@, whose argument tags are @f[g[x_]]@'s.
lhsCore :: Expr -> Expr
lhsCore e = case unholdPattern e of
  App (Sym c) as | c == sCondition, [p, _] <- V.toList as -> lhsCore p
  e' -> e'

-- | The tags of the left-hand side's arguments, which upvalues go on.
argumentTags :: Expr -> [Symbol]
argumentTags = mapMaybe tagSymbol . V.toList . exprArgs . lhsCore

sPart, sAttributes :: Symbol
sPart = systemSymbol "Part"
sAttributes = systemSymbol "Attributes"

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
-- @{x, {y, z}} = {1, {2, 3}}@ assigns elementwise, at every depth.
assignment :: (Kernel :> es) => Text -> (Expr -> RuleBody) -> Expr -> Eff es (Maybe Expr)
assignment name body e = case args e of
  [App (Sym p) xs, rhs]
    | p == sPart,
      name == "Set",
      Sym s : is@(_ : _) <- V.toList xs ->
        Just rhs <$ partAssignment s is rhs
  [App (Sym l) ls, rhs]
    | l == sList,
      name == "Set" ->
        Just rhs <$ elementwise ls rhs
  [App (Sym a) xs, rhs]
    | a == sAttributes,
      name == "Set",
      [Sym s] <- V.toList xs,
      Just attrs <- traverse attributeOf (listOf rhs) ->
        Just rhs <$ replaceAttributes s attrs
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
    elementwise ls rhs = case rhs of
      App (Sym l') rs
        | l' == sList,
          V.length rs == V.length ls ->
            V.zipWithM_ one ls rs
      _ -> message name "shape" [apply sList (V.toList ls), rhs]
    one x v = case x of
      App (Sym l) xs | l == sList -> elementwise xs v
      _ -> prepareLhs x >>= \x' -> void (write name x' (body v))

-- | @s[[i, …]] = v@: replace a part of @s@'s own value, which must exist.
-- An index is an integer (negative from the end, 0 the head) or a list of
-- them; a list of indices takes a list of values of the same length,
-- elementwise, or one value for every index. Out of range is @Set::partw@,
-- and no own value is @Set::noval@; either way the value is unchanged.
partAssignment :: (Kernel :> es) => Symbol -> [Expr] -> Expr -> Eff es ()
partAssignment s is0 rhs = do
  info <- lookupSymbol s
  is <- traverse evaluate is0
  let lhs = apply sPart (Sym s : is)
  case [v | r <- ruleSetToList (rulesOf OwnValue info), r.ruleOrigin == User, Immediate v <- [r.ruleBody]] of
    current : _
      | isProtected info.siAttributes -> message "Set" "wrsym" [Sym s]
      | Just new <- setPart current is rhs ->
          modifySymbol s (modifyRules OwnValue (insertRule (mkRule User (Sym s) (Immediate new))))
      | otherwise -> message "Set" "partw" [lhs]
    [] -> message "Set" "noval" [Sym s, lhs]

-- | Replace the part at a sequence of indices; 'Nothing' when one is out of
-- range or is not an index.
setPart :: Expr -> [Expr] -> Expr -> Maybe Expr
setPart x is v = case is of
  [] -> Just v
  -- An index beyond a machine integer is out of range, not wrapped.
  Int_ i : rest -> toIntegralSized i >>= \k -> setAt x k rest v
  App (Sym l) js : rest | l == sList -> do
    ks <- traverse index (V.toList js)
    let vs = case v of
          App (Sym l') ws | l' == sList, V.length ws == length ks -> V.toList ws
          _ -> map (const v) ks
    foldlM (\acc (k, w) -> setAt acc k rest w) x (zip ks vs)
  _ -> Nothing
  where
    index = \case
      Int_ i -> toIntegralSized i
      _ -> Nothing
    setAt y k rest w = case y of
      App h as
        | k == 0 -> (`mkApp` as) <$> setPart h rest w
        | otherwise -> do
            let pos = if k < 0 then V.length as + k else k - 1
            a <- as V.!? pos
            a' <- setPart a rest w
            Just (mkApp h (as V.// [(pos, a')]))
      _ -> Nothing

-- | @UpSet@ and @UpSetDelayed@: an upvalue for the tag of every argument.
upAssignment :: (Kernel :> es) => Text -> (Expr -> RuleBody) -> Expr -> Eff es (Maybe Expr)
upAssignment name body e = case args e of
  [lhs, rhs] -> do
    lhs' <- prepareLhs lhs
    case ordNub (argumentTags lhs') of
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
        argTags = argumentTags lhs'
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
-- @$Failed@ with @Unset::norep@ when there is none, and with @Unset::wrsym@
-- or @Unset::write@, as 'write' refuses, when the tag is protected.
unset :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
unset e = case args e of
  [lhs] -> do
    lhs' <- prepareLhs lhs
    case target lhs' of
      Nothing -> Just sFailedE <$ message "Unset" "norep" [lhs']
      Just (Target s k) -> do
        info <- lookupSymbol s
        let (removed, rules') = removeRule lhs' (rulesOf k info)
        if isProtected info.siAttributes
          then do
            if k == OwnValue then message "Unset" "wrsym" [Sym s] else message "Unset" "write" [Sym s, lhs']
            pure (Just sFailedE)
          else
            if removed
              then Just sNullE <$ modifySymbol s (modifyRules k (const rules'))
              else Just sFailedE <$ message "Unset" "norep" [lhs']
  _ -> pure Nothing

-- | @Attributes[s]@: the list of attribute names, in WL's order (by name).
-- The symbol may be given by name, as @Attributes["Set"]@.
attributes :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
attributes e = case args e of
  [x] | Just s0 <- symbolOrName x -> do
    s <- s0
    info <- lookupSymbol s
    pure (Just (apply sList [Sym (systemSymbol (attributeName a)) | a <- attributeList info.siAttributes]))
  _ -> pure Nothing
  where
    symbolOrName = \case
      Sym s -> Just (pure s)
      Str t -> Just (named t)
      _ -> Nothing

-- | @Attributes[s] = {…}@: replace the symbol's attributes. A @Locked@
-- symbol refuses with @Attributes::locked@, as @SetAttributes@ does.
replaceAttributes :: (Kernel :> es) => Symbol -> [Attribute] -> Eff es ()
replaceAttributes s attrs = do
  info <- lookupSymbol s
  if Attributes.member Locked info.siAttributes
    then message "Attributes" "locked" [Sym s]
    else modifySymbol s (\si -> si {siAttributes = foldr Attributes.insert mempty attrs})

-- | @SetAttributes@ and @ClearAttributes@: one symbol or a list, and one
-- attribute or a list. A @Locked@ symbol refuses with @Attributes::locked@.
changeAttributes :: (Kernel :> es) => (Attribute -> Attributes.AttributeSet -> Attributes.AttributeSet) -> Expr -> Eff es (Maybe Expr)
changeAttributes f e = case args e of
  -- HoldFirst: step 3 has already evaluated the attributes.
  [ss, as] ->
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

-- | @Protect@ and @Unprotect@: the names of the symbols whose protection
-- changed, as strings. A @Locked@ symbol refuses with @Protect::locked@,
-- for @Unprotect@ too, as WL's message does.
protection :: (Kernel :> es) => Bool -> Expr -> Eff es (Maybe Expr)
protection protect e =
  traverse symbolsOf (args e) >>= \xs -> case sequence xs of
    Just symss -> do
      let syms = concat symss
      changed <- fmap catMaybes . forM syms $ \s -> do
        info <- lookupSymbol s
        let was = isProtected info.siAttributes
        if Attributes.member Locked info.siAttributes
          then Nothing <$ message "Protect" "locked" [Sym s]
          else
            if was == protect
              then pure Nothing
              else do
                modifySymbol s (\si -> si {siAttributes = (if protect then Attributes.insert else Attributes.delete) Protected si.siAttributes})
                pure (Just (mkString s.symName))
      pure (Just (apply sList changed))
    Nothing -> pure Nothing
  where
    -- A symbol, a name, or a list of them.
    symbolsOf = \case
      Sym s -> pure (Just [s])
      Str t -> Just . pure <$> named t
      App (Sym l) xs | l == sList -> fmap concat . sequence <$> traverse symbolsOf (V.toList xs)
      _ -> pure Nothing

-- | The symbol a name means: the System` symbol if the kernel knows one,
-- else the Global` one.
named :: (Kernel :> es) => Text -> Eff es Symbol
named t = do
  info <- lookupSymbol (systemSymbol t)
  pure $ if info.siAttributes /= mempty || hasRules info then systemSymbol t else globalSymbol t

attributeOf :: Expr -> Maybe Attribute
attributeOf = \case
  Sym a -> attributeFromName a.symName
  _ -> Nothing

symbolList :: Expr -> Maybe [Symbol]
symbolList = traverse (\case Sym s -> Just s; _ -> Nothing) . listOf

listOf :: Expr -> [Expr]
listOf = \case
  App (Sym l) xs | l == sList -> V.toList xs
  x -> [x]
