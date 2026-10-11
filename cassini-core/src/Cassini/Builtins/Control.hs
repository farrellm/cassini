{-# LANGUAGE PatternSynonyms #-}

-- | Pure functions and sequencing: @Function@, @Slot@, @SlotSequence@ and
-- @CompoundExpression@ (DESIGN.md §4.13).
--
-- Source: @references/papers/wolfram-language/wolfram_ref_function.html@,
-- and for the renaming that keeps a substituted value from being captured,
-- @references/papers/wolfram-language/wolfram_ref_modularity_and_naming.html@,
-- "Variables in Pure Functions and Rules".
--
-- @Function[params, body][args]@ and @Function[body][args]@ apply as a
-- built-in subvalue on @Function@ (step 13's @h[…][…]@), by substituting into
-- the held body with 'Cassini.Structure.substituteFree'. A pure function is
-- applied by a built-in rung, so it does not catch @Return@ (§4.4). The
-- rest of §4.13 (conditionals, scoping, loops, non-local exits) is the
-- control-flow track's.
module Cassini.Builtins.Control (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, message, sNullE, sub)
import Cassini.Core.Expr (Expr, pattern App, pattern Int_, pattern Sym)
import Cassini.Core.Symbol (Symbol, sFunction, sList, sNull, sSlot, sSlotSequence)
import Cassini.Eval.Kernel (Kernel, evaluate)
import Cassini.Structure (Binding (..), Scoping (Shielding), Slots (..), substituteFree)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | The pure-function and sequencing builtins, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "Function" [HoldAll, Protected] [sub functionRule],
    define "Slot" [NHoldAll, Protected] [],
    define "SlotSequence" [NHoldAll, Protected] [],
    define "CompoundExpression" [HoldAll, Protected, ReadProtected] [down compoundRule]
  ]

-- | @Function[…][args]@. In slot form, @#n@ is the @n@th argument and
-- arguments beyond the highest slot are ignored; a slot with no argument
-- stays, with @Function::slotn@, and so does a @##n@ with none after the
-- one before it, with @Function::slots@. With named parameters, each takes its
-- argument and any further arguments are ignored; too few arguments is
-- @Function::fpct@, and the application stays unevaluated.
functionRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
functionRule e = case e of
  App f@(App (Sym h) fargs) as | h == sFunction -> case V.toList fargs of
    [body] -> slotForm f body as
    [Sym n, body, _] | n == sNull -> slotForm f body as
    ps : body : _
      | Just xs <- params ps ->
          if length xs > V.length as
            then Nothing <$ message "Function" "fpct" [ps, e]
            else pure (Just (substituteFree Shielding (Map.fromList (zip xs (map BOne (V.toList as)))) Nothing body))
    _ -> pure Nothing
  _ -> pure Nothing
  where
    slotForm f body as = do
      for_ (unfilled (V.length as) body) $ \case
        Left n -> message "Function" "slotn" [Int_ n, e]
        Right n -> message "Function" "slots" [Int_ n, e]
      pure (Just (substituteFree Shielding Map.empty (Just (Slots as f)) body))
    params = \case
      Sym x -> Just [x]
      App (Sym l) xs | l == sList -> traverse symbolOf (V.toList xs)
      _ -> Nothing
    symbolOf :: Expr -> Maybe Symbol
    symbolOf = \case
      Sym x -> Just x
      _ -> Nothing

-- | The slots in a slot-form body that @k@ arguments cannot fill, each
-- once, outside any slot-form @Function@ inside it, whose slots are its own:
-- 'Left' a slot @#n@ beyond the arguments, 'Right' a @##n@ beyond one past
-- them (@wolfram/SlotSequence/PossibleIssues/1@).
unfilled :: Int -> Expr -> [Either Integer Integer]
unfilled k = ordNub . go
  where
    go = \case
      App (Sym h) xs
        | h == sSlot, [Int_ n] <- V.toList xs, n > toInteger k -> [Left n]
        | h == sSlotSequence, [Int_ n] <- V.toList xs, n > toInteger k + 1 -> [Right n]
        | h == sFunction, slotForm (V.toList xs) -> []
      App h xs -> go h <> concatMap go (V.toList xs)
      _ -> []
    slotForm = \case
      [_] -> True
      Sym n : _ : _ -> n == sNull
      _ -> False

-- | @CompoundExpression[e1, …, en]@ evaluates each @ei@ in turn and gives
-- the last. The last is returned unevaluated, for the fixed point to
-- evaluate once, so a message it emits is emitted once. With no arguments
-- it is @Null@.
compoundRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
compoundRule e = case unsnoc (args e) of
  Nothing -> pure (Just sNullE)
  Just (before, lastE) -> Just lastE <$ traverse_ evaluate before
  where
    unsnoc xs = (take (length xs - 1) xs,) <$> viaNonEmpty last xs
