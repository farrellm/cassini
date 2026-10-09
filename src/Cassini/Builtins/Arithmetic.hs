{-# LANGUAGE PatternSynonyms #-}

-- | @Plus@, @Times@, @Power@, @Divide@, @Subtract@, @Minus@ and @Sqrt@
-- (DESIGN.md §2.2, §4.6).
--
-- The built-in downvalues of @Plus@, @Times@ and @Power@ are Cohen's
-- 'simplifySum', 'simplifyProduct' and 'simplifyPower' on arguments step 3
-- has already evaluated, so already simplified. They are not the recursive
-- 'Cassini.Simplify.Automatic.simplify', which would re-traverse every
-- subtree on every round. The other heads rewrite to those three, as in WL:
-- @Sqrt[x]@ is @Power[x, 1/2]@.
--
-- An 'Undefined' answer becomes WL's result and message (§4.7): division by
-- zero is @ComplexInfinity@ with @Power::infy@, @0^0@ is @Indeterminate@ with
-- @Power::indet@.
module Cassini.Builtins.Arithmetic (definitions, fromSimplified) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, message, own)
import Cassini.Core.Expr (Expr, apply, mkNumber, pattern Int_, pattern Sym)
import Cassini.Core.Symbol (sDirectedInfinity, sIndeterminate, sPlus, sPower, sTimes)
import Cassini.Eval.Kernel (Kernel)
import Cassini.Number (fromRational')
import Cassini.Simplify.Automatic (Undefined (..), simplifyPower, simplifyProduct, simplifySum)
import Data.Ratio ((%))
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | The arithmetic builtins, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "Plus" (OneIdentity : flatOrderless) [down (\e -> fromSimplified e (simplifySum (V.fromList (args e))))],
    define "Times" (OneIdentity : flatOrderless) [down (\e -> fromSimplified e (simplifyProduct (V.fromList (args e))))],
    define "Power" [Listable, NumericFunction, OneIdentity, Protected] [down powerRule],
    define "Divide" numeric [down (rewrite2 (\a b -> apply sTimes [a, apply sPower [b, Int_ (-1)]]))],
    define "Subtract" numeric [down (rewrite2 (\a b -> apply sPlus [a, apply sTimes [Int_ (-1), b]]))],
    define "Minus" numeric [down (rewrite1 (\a -> apply sTimes [Int_ (-1), a]))],
    define "Sqrt" numeric [down (rewrite1 (\a -> apply sPower [a, mkNumber (fromRational' (1 % 2))]))],
    -- The infinities are symbols that evaluate to their FullForm (§4.15).
    define "Infinity" [Constant, Protected, ReadProtected] [own (const (pure (Just (apply sDirectedInfinity [Int_ 1]))))],
    define "ComplexInfinity" [Constant, Protected, ReadProtected] [own (const (pure (Just complexInfinity)))],
    define "DirectedInfinity" [Listable, Protected, ReadProtected] [],
    define "Indeterminate" [Protected, ReadProtected] []
  ]
  where
    flatOrderless = [Flat, Listable, NumericFunction, Orderless, Protected]
    numeric = [Listable, NumericFunction, Protected]
    -- Power[x, y, z] is Power[x, Power[y, z]]: right-associative, as WL's.
    powerRule e = case args e of
      [v, w] -> fromSimplified e (simplifyPower v w)
      v : w : rest@(_ : _) -> pure (Just (apply sPower [v, nest w rest]))
      _ -> pure Nothing
    nest y = \case
      [] -> y
      z : zs -> apply sPower [y, nest z zs]
    rewrite1 f e = pure $ case args e of
      [a] -> Just (f a)
      _ -> Nothing
    rewrite2 f e = pure $ case args e of
      [a, b] -> Just (f a b)
      _ -> Nothing

-- | A simplifier's answer as a builtin's: an 'Undefined' becomes WL's result
-- for the same input, with its message (§4.7).
fromSimplified :: (Kernel :> es) => Expr -> Either Undefined Expr -> Eff es (Maybe Expr)
fromSimplified e = \case
  Right r -> pure (Just r)
  Left u -> case u of
    DivisionByZero -> infinite
    ZeroDenominator -> infinite
    ZeroToZero -> indeterminate
    ZeroOverZero -> indeterminate
    Pole -> pure (Just complexInfinity)
    LogOfZero -> pure (Just (apply sDirectedInfinity [Int_ (-1)]))
  where
    infinite = Just complexInfinity <$ message "Power" "infy" [e]
    indeterminate = Just (Sym sIndeterminate) <$ message "Power" "indet" [e]

complexInfinity :: Expr
complexInfinity = apply sDirectedInfinity []
