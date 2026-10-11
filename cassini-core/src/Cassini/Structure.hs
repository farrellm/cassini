{-# LANGUAGE PatternSynonyms #-}

-- | Structure-based operators: Cohen's primitive expression operators, as the
-- Haskell API and the backing for WL's structural builtins (DESIGN.md §3.7).
--
-- Source: @references/papers/textbooks/cohen2002_*.pdf@ §3.3 (@Kind@,
-- @Operand@, @Number_of_operands@, @Construct@, @Free_of@, @Substitute@,
-- @Sequential_substitute@, @Concurrent_substitute@).
--
-- One departure from Cohen: his operators are not sub-expressions, but here an
-- application's head is, as in WL, so @freeOf (f[x]) f@ is 'False' and
-- 'substitute' rewrites heads. That is what @FreeQ@ and @ReplaceAll@ need from
-- their fast path.
--
-- 'substituteFree' is the one substitution that knows the language's scoping
-- constructs (§4.13): pure-function application, @With@, and the
-- instantiation of a rule's right-hand side. Source for its renaming:
-- @references/papers/wolfram-language/wolfram_ref_modularity_and_naming.html@,
-- "Variables in Pure Functions and Rules".
module Cassini.Structure
  ( Kind (..),
    exprKind,
    PartError (..),
    part,
    numberOfParts,
    construct,
    freeOf,
    substitute,
    substituteSeq,
    substituteAll,

    -- * Scoping-aware substitution
    Binding (..),
    bindingExpr,
    Scoping (..),
    Slots (..),
    substituteFree,
  )
where

import Cassini.Core.Expr (Expr, apply, exprArity, exprHead, mkApp, pattern App, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Symbol
  ( Symbol,
    sFactorial,
    sFunction,
    sList,
    sModule,
    sNull,
    sPattern,
    sPlus,
    sPower,
    sRule,
    sRuleDelayed,
    sSequence,
    sSet,
    sSetDelayed,
    sSlot,
    sSlotSequence,
    sTimes,
    sWith,
    symContext,
    symName,
    symbol,
  )
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V

-- $setup
-- >>> import Cassini.Core.Expr (apply, mkNumber, mkSymbol)
-- >>> import Cassini.Core.Symbol (globalSymbol)
-- >>> import Cassini.Number (Number (NInt))

-- | Cohen's kinds, extended with strings (O-K, §3.5).
data Kind
  = KConstant
  | KString
  | KSymbol
  | KProduct
  | KSum
  | KPower
  | KFactorial
  | KFunction
  deriving stock (Eq, Show, Enum, Bounded)

-- | The kind. @Plus@, @Times@ and @Factorial@ heads, and @Power@ with exactly
-- two arguments, have their Cohen kinds. @Factorial@ needs exactly one
-- argument, as @Power@ needs two, because O-5 compares its operand. Any other
-- application is a function, including a curried one (@f[x][y]@).
--
-- >>> exprKind (apply sPower [mkSymbol (globalSymbol "x")])
-- KFunction
exprKind :: Expr -> Kind
exprKind = \case
  Num _ -> KConstant
  Str _ -> KString
  Sym _ -> KSymbol
  App (Sym f) as
    | f == sPlus -> KSum
    | f == sTimes -> KProduct
    | f == sPower, V.length as == 2 -> KPower
    | f == sFactorial, V.length as == 1 -> KFactorial
  App _ _ -> KFunction

-- | @Part[expr, i]@ does not exist.
data PartError = PartError
  { -- | The expression indexed.
    partExpr :: !Expr,
    -- | The index asked for.
    partIndex :: !Int
  }
  deriving stock (Eq, Show)

-- | Part @i@: 0 is the head, @1..n@ the arguments, and @-n..-1@ the arguments
-- counted from the end, as in WL. An atom has only part 0.
--
-- >>> part (apply (globalSymbol "f") [mkNumber (NInt 1), mkNumber (NInt 2)]) (-1)
-- Right 2
-- >>> isLeft (part (mkSymbol (globalSymbol "x")) 1)
-- True
part :: Expr -> Int -> Either PartError Expr
part e i
  | i == 0 = Right (exprHead e)
  | otherwise = case e of
      App _ as
        | i > 0, Just x <- as V.!? (i - 1) -> Right x
        | i < 0, Just x <- as V.!? (V.length as + i) -> Right x
      _ -> Left (PartError e i)

-- | The number of arguments; 0 for an atom.
numberOfParts :: Expr -> Int
numberOfParts = exprArity

-- | An application of a head to arguments.
construct :: Expr -> V.Vector Expr -> Expr
construct = mkApp

-- | Whether no complete subexpression of @u@, heads included, is @t@.
--
-- >>> let a = mkSymbol (globalSymbol "a"); b = mkSymbol (globalSymbol "b"); c = mkSymbol (globalSymbol "c")
-- >>> freeOf (apply sPlus [a, b, c]) (apply sPlus [a, b])
-- True
freeOf :: Expr -> Expr -> Bool
freeOf u t
  | u == t = False
  | otherwise = case u of
      App h as -> freeOf h t && all (`freeOf` t) as
      _ -> True

-- | @substitute u t r@ replaces every complete subexpression of @u@ that is
-- @t@ with @r@. The replacement is not searched again. Subtrees with no
-- occurrence are returned as they are, not rebuilt.
substitute :: Expr -> Expr -> Expr -> Expr
substitute u t r = substituteAll u [(t, r)]

-- | Substitute each pair in turn: later pairs see earlier replacements.
substituteSeq :: Expr -> [(Expr, Expr)] -> Expr
substituteSeq = foldl' (\u (t, r) -> substitute u t r)

-- | Substitute all pairs at once: at each subexpression the first pair whose
-- target it is applies, and replacements are not searched again.
substituteAll :: Expr -> [(Expr, Expr)] -> Expr
substituteAll u0 rules = fromMaybe u0 (go u0)
  where
    -- 'Nothing' means unchanged, so unchanged subtrees keep their nodes.
    go u = case find ((== u) . fst) rules of
      Just (_, r) -> Just r
      Nothing -> case u of
        App h as ->
          let h' = go h
              as' = V.map go as
           in if isNothing h' && V.all isNothing as'
                then Nothing
                else Just (mkApp (fromMaybe h h') (V.zipWith fromMaybe as as'))
        _ -> Nothing

-- | What a symbol is replaced by: one expression, or a run of arguments,
-- which is spliced where it lands in an argument list. A pattern variable's
-- binding (§4.5.1), and a pure function's parameter.
data Binding
  = BOne !Expr
  | BSeq !(V.Vector Expr)
  deriving stock (Eq, Show)

-- | The binding as one expression: a run becomes @Sequence[…]@, which
-- step 5 splices wherever it lands in an argument list.
bindingExpr :: Binding -> Expr
bindingExpr = \case
  BOne x -> x
  BSeq xs -> apply sSequence (V.toList xs)

-- | How a substitution treats a scoping construct inside the expression it
-- substitutes into. Both rename a construct's own names to @x$@ when its
-- inside is changed, so that a substituted value cannot be captured.
data Scoping
  = -- | @Function@ and @With@: a construct's own names shield its inside, and
    -- every one of them is renamed when that inside changes.
    Shielding
  | -- | A rule's right-hand side, which WL instantiates "effectively … using
    -- the @/.@ operator": every occurrence is replaced, a construct's own
    -- names included, and only its other names are renamed.
    Literal
  deriving stock (Eq, Show)

-- | The values a pure function in slot form fills its slots with: @#n@ is
-- the @n@th argument, @##n@ the arguments from the @n@th on, and @#0@ the
-- function itself. A slot beyond the arguments is left as it is, and so is
-- @##n@ beyond one past them (@##n@ just past them is empty).
data Slots = Slots
  { slotArgs :: !(V.Vector Expr),
    slotSelf :: !Expr
  }

-- | Substitute for symbols, and for slots when there are 'Slots', all at
-- once, respecting the scoping constructs inside: @Function@, @With@,
-- @Module@, and rules and definitions (@->@, @:>@, @=@, @:=@), whose local
-- names are their patterns' names. A run is spliced into the argument list
-- it lands in, as WL does, so @f[x]@ with @x@ bound to the run @a, b@ is
-- @f[a, b]@ even under a head that holds; anywhere else it is
-- @Sequence[…]@. Subtrees that do not change keep their nodes.
--
-- A slot-form @Function@ inside shields every slot, since its slots are its
-- own. A construct whose inside a parameter's substitution changes has its
-- local names renamed first, per the 'Scoping': WL renames "whenever body is
-- modified in any way by the action of another pure function", more
-- liberally than capture alone would need. Filling slots renames nothing,
-- as in WL, where @Function[Function[v, f[#, v]]][x]@ is
-- @Function[v, f[x, v]]@ (@wolfram/Slot/PossibleIssues/1@).
--
-- >>> let x = mkSymbol (globalSymbol "x"); y = mkSymbol (globalSymbol "y")
-- >>> let fn ps b = apply sFunction [apply sList ps, b]
-- >>> substituteFree Shielding (Map.singleton (globalSymbol "x") (BOne y)) Nothing (fn [y] (apply sPlus [x, y]))
-- Function[List[y$], Plus[y, y$]]
substituteFree :: Scoping -> Map Symbol Binding -> Maybe Slots -> Expr -> Expr
substituteFree scoping vars0 slots0 u0
  | Map.null vars0 && isNothing slots0 = u0
  | otherwise = fromMaybe u0 (go vars0 slots0 u0)
  where
    -- 'Nothing' means unchanged.
    go vars slots u = case u of
      Sym x -> bindingExpr <$> Map.lookup x vars
      App (Sym h) as
        | h == sSlot, Just sl <- slots, [Int_ n] <- V.toList as -> slot sl n
        | h == sSlotSequence, Just sl <- slots, [Int_ n] <- V.toList as, fills sl n -> Just (apply sSequence (V.toList (V.drop (fromInteger n - 1) sl.slotArgs)))
        | Just sc <- scope h as -> scoped vars slots sc
      App h as ->
        let h' = go vars slots h
            as' = V.map (arg vars slots) as
         in if isNothing h' && V.all isNothing as'
              then Nothing
              else Just (mkApp (fromMaybe h h') (V.concat (V.toList (V.zipWith (fromMaybe . V.singleton) as as'))))
      _ -> Nothing
    -- An argument, which a run or a slot sequence splices into its list.
    arg vars slots a = case a of
      Sym x | Just (BSeq xs) <- Map.lookup x vars -> Just xs
      App (Sym h) xs
        | h == sSlotSequence, Just sl <- slots, [Int_ n] <- V.toList xs, fills sl n -> Just (V.drop (fromInteger n - 1) sl.slotArgs)
      _ -> V.singleton <$> go vars slots a
    -- @##n@ is filled up to one past the last argument, where it is empty.
    fills sl n = n >= 1 && n <= toInteger (V.length sl.slotArgs) + 1
    slot sl n
      | n == 0 = Just sl.slotSelf
      | n >= 1 = sl.slotArgs V.!? (fromInteger n - 1)
      | otherwise = Nothing
    -- A scoping construct: substitute outside its scope as usual, and inside
    -- it under its shield, renaming its names first if the inside changes.
    scoped vars slots sc =
      let inVars = case scoping of
            Shielding -> foldl' (flip Map.delete) vars sc.scLocal
            Literal -> vars
          inSlots = if sc.scSlots then Nothing else slots
          inside = go inVars inSlots
          renamed = case scoping of
            Shielding -> sc.scLocal
            Literal -> filter (`Map.notMember` vars) sc.scLocal
          -- Only a parameter's substitution renames: filling slots does not
          -- (wolfram/Slot/PossibleIssues/1). Checked only when there is a
          -- name to rename, and the inside is otherwise traversed once, so
          -- that nested constructs cost linear, not exponential, time.
          renames = not (null renamed) && not (Map.null inVars) && isJust (sc.scMap (const Nothing) (go inVars Nothing))
       in if renames
            then (\sc' -> fromMaybe sc'.scExpr (sc'.scMap (go vars slots) inside)) <$> rename renamed sc
            else sc.scMap (go vars slots) inside

-- | Rename a construct's local names to @x$@ inside its scope, and read it
-- again.
rename :: [Symbol] -> Scope -> Maybe Scope
rename names sc = case sc.scMap (const Nothing) (\x -> Just (substituteAll x pairs)) of
  Just (App (Sym h) as) -> scope h as
  _ -> Nothing
  where
    pairs = [(Sym x, Sym (symbol x.symContext (x.symName <> "$"))) | x <- names]

-- | A scoping construct, read: its local names, whether it shields slots,
-- and how to rebuild it from substitutions applied to the parts outside its
-- scope and inside it ('Nothing' if neither changes anything).
data Scope = Scope
  { scExpr :: !Expr,
    scLocal :: ![Symbol],
    scSlots :: !Bool,
    scMap :: (Expr -> Maybe Expr) -> (Expr -> Maybe Expr) -> Maybe Expr
  }

-- | Read a scoping construct: @Function[body]@ and @Function[Null, body, …]@
-- (slot form: no names, every slot), @Function[x, body, …]@ and
-- @Function[{x, …}, body, …]@, @With@ and @Module@ over @{x, x = v, x := v, …}@
-- (the values are outside the scope), and @lhs -> rhs@, @lhs :> rhs@,
-- @lhs = rhs@ and @lhs := rhs@, whose names are the left-hand side's pattern
-- names.
scope :: Symbol -> V.Vector Expr -> Maybe Scope
scope h as
  | h == sFunction = case V.toList as of
      [_] -> Just (whole [] True)
      Sym n : _ : _ | n == sNull -> Just (whole [] True)
      ps : _ : _ -> (`whole` False) <$> params ps
      _ -> Nothing
  | h == sWith || h == sModule,
    [App (Sym l) specs, body] <- V.toList as,
    l == sList =
      (\xs -> Scope e xs False (local specs body)) <$> traverse specName (V.toList specs)
  | h `elem` [sRule, sRuleDelayed, sSet, sSetDelayed],
    [lhs, _] <- V.toList as =
      Just (whole (ordNub (patternNames lhs)) False)
  | otherwise = Nothing
  where
    e = mkApp (Sym h) as
    -- Every argument is inside.
    whole xs sl = Scope e xs sl $ \_ fin ->
      let as' = V.map fin as
       in if V.all isNothing as' then Nothing else Just (mkApp (Sym h) (V.zipWith fromMaybe as as'))
    -- A specification's name and the body are inside; its value is outside.
    local specs body fout fin =
      let specs' = V.map (spec fout fin) specs
          body' = fin body
       in if V.all isNothing specs' && isNothing body'
            then Nothing
            else Just (mkApp (Sym h) (V.fromList [apply sList (V.toList (V.zipWith fromMaybe specs specs')), fromMaybe body body']))
    spec fout fin = \case
      App (Sym s) xs
        | s == sSet || s == sSetDelayed,
          [x, v] <- V.toList xs ->
            let x' = fin x
                v' = fout v
             in if isNothing x' && isNothing v' then Nothing else Just (apply s [fromMaybe x x', fromMaybe v v'])
      x -> fin x
    specName = \case
      Sym x -> Just x
      App (Sym s) xs | s == sSet || s == sSetDelayed, [Sym x, _] <- V.toList xs -> Just x
      _ -> Nothing
    params = \case
      Sym x -> Just [x]
      App (Sym l) xs | l == sList -> traverse (\case Sym x -> Just x; _ -> Nothing) (V.toList xs)
      _ -> Nothing

-- | The names of the patterns in a left-hand side, @x@ of @x_@ and @x:p@.
patternNames :: Expr -> [Symbol]
patternNames = \case
  App (Sym p) xs | p == sPattern, [Sym x, q] <- V.toList xs -> x : patternNames q
  App h xs -> patternNames h <> concatMap patternNames (V.toList xs)
  _ -> []
