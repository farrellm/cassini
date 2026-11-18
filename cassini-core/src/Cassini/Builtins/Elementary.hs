{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ViewPatterns #-}

-- | The elementary functions: @Sin@ … @Csc@, @Sinh@ … @Csch@, @ArcSin@ …
-- @ArcCsc@, @Exp@ and @Log@, with the constants @Pi@ and @E@ (DESIGN.md
-- §4.11).
--
-- Each head's built-in downvalue is 'simplifyElementary' on its evaluated
-- argument, and each derivative is a built-in subvalue on @Derivative@, so
-- one module holds everything the system knows about a function. A pole is
-- @ComplexInfinity@ and @Log[0]@ is @DirectedInfinity[-1]@, both silent as
-- in WL (§4.7).
module Cassini.Builtins.Elementary (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Arithmetic (fromSimplified)
import Cassini.Builtins.Define (Definition, args, define, down, sub)
import Cassini.Core.Expr (Expr, apply, mkApp, mkNumber, pattern App, pattern Call, pattern Int_, pattern Sym)
import Cassini.Core.Symbol (sDerivative, sFunction, sPlus, sPower, sSlot, sTimes)
import Cassini.Number (fromRational')
import Cassini.Simplify.Elementary (Fn (..), fnOf, fnSymbol, sE, simplifyElementary)
import Data.Vector qualified as V

-- | The elementary heads, @Pi@ and @E@, and their derivatives.
definitions :: [Definition]
definitions =
  [define (show fn) [Listable, NumericFunction, Protected] [down (rule fn)] | fn <- universe]
    <> [ define "Pi" [Constant, Protected, ReadProtected] [],
         define "E" [Constant, Protected, ReadProtected] [],
         define "Derivative" [] [sub (pure . derivativeOf)]
       ]
  where
    rule fn e = case args e of
      [x] -> maybe (pure Nothing) (fromSimplified e) (simplifyElementary (fnSymbol fn) (V.singleton x))
      _ -> pure Nothing

-- | @Derivative[n][f]@ for an elementary @f@: the table of §4.11 for the
-- first derivative, and for a higher one, the derivative of that pure
-- function.
derivativeOf :: Expr -> Maybe Expr
derivativeOf = \case
  App (Call d [Int_ n]) (V.toList -> [Sym f])
    | d == sDerivative,
      n >= 1,
      Just fn <- fnOf f,
      Just body <- derivativeBody fn ->
        let d1 = apply sFunction [body]
         in Just (if n == 1 then d1 else mkApp (apply sDerivative [Int_ (n - 1)]) (V.singleton d1))
  _ -> Nothing

-- | The body of the first derivative, in @#1@.
derivativeBody :: Fn -> Maybe Expr
derivativeBody = \case
  Sin -> Just (f Cos)
  Cos -> Just (neg (f Sin))
  Tan -> Just (sq (f Sec))
  Cot -> Just (neg (sq (f Csc)))
  Sec -> Just (times [f Sec, f Tan])
  Csc -> Just (neg (times [f Cot, f Csc]))
  Sinh -> Just (f Cosh)
  Cosh -> Just (f Sinh)
  Tanh -> Just (sq (f Sech))
  Coth -> Just (neg (sq (f Csch)))
  Sech -> Just (neg (times [f Sech, f Tanh]))
  Csch -> Just (neg (times [f Coth, f Csch]))
  ArcSin -> Just (pow (oneMinus (pow slot 2)) (-1 / 2))
  ArcCos -> Just (neg (pow (oneMinus (pow slot 2)) (-1 / 2)))
  ArcTan -> Just (pow (onePlus (pow slot 2)) (-1))
  ArcCot -> Just (neg (pow (onePlus (pow slot 2)) (-1)))
  ArcSec -> Just (times [pow slot (-2), pow (oneMinus (pow slot (-2))) (-1 / 2)])
  ArcCsc -> Just (neg (times [pow slot (-2), pow (oneMinus (pow slot (-2))) (-1 / 2)]))
  Exp -> Just (apply sPower [Sym sE, slot])
  Log -> Just (pow slot (-1))
  where
    slot = apply sSlot [Int_ 1]
    f fn = apply (fnSymbol fn) [slot]
    neg x = times [Int_ (-1), x]
    times = apply sTimes
    sq x = pow x 2
    pow x (e :: Rational) = apply sPower [x, mkNumber (fromRational' e)]
    oneMinus x = apply sPlus [Int_ 1, neg x]
    onePlus x = apply sPlus [Int_ 1, x]
