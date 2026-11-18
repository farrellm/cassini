{-# LANGUAGE PatternSynonyms #-}

-- | Held arguments kept out of a pure procedure (DESIGN.md §4.12).
--
-- The procedures behind @Expand@, @TrigExpand@, @TrigReduce@ and @Simplify@
-- are pure and descend into every argument, since they cannot read
-- attributes. 'outsideHeld' reads them first: each argument its head holds
-- (@Hold[1 + 1]@'s, @Function[x, 1 + 1]@'s body) is swapped for an opaque
-- placeholder, the procedure runs, and the arguments go back. So
-- @Expand[Hold[1 + 1]]@ stays @Hold[1 + 1]@, as WL 15.0.1's does.
module Cassini.Builtins.Held (outsideHeld, unary, overList) where

import Cassini.Attributes (attributeSet, holdsArgument)
import Cassini.Builtins.Arithmetic (fromSimplified)
import Cassini.Builtins.Define (args)
import Cassini.Core.Expr (Expr, apply, mkApp, mkNumber, pattern App, pattern Call, pattern Int_, pattern Sym)
import Cassini.Core.Order (compareCanonical)
import Cassini.Core.Symbol (Symbol, sList, sPlus, sTimes, symbol)
import Cassini.Eval.Kernel (Kernel, lookupAttributes)
import Cassini.Number (Number (NInt))
import Cassini.Simplify.Automatic (Undefined)
import Data.HashMap.Strict qualified as HashMap
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | A one-argument builtin over a procedure on normal forms. The argument
-- is already evaluated, so in the evaluator's normal form, which is
-- 'Cassini.Simplify.Elementary.simplifyE''s (§4.11); what it holds stays out
-- of the procedure's reach ('outsideHeld').
unary :: (Kernel :> es) => (Expr -> Either Undefined Expr) -> Expr -> Eff es (Maybe Expr)
unary f e = case args e of
  [x] -> outsideHeld f x >>= fromSimplified e
  _ -> pure Nothing

-- | A builtin that threads over a single list argument, as WL's @Expand@ and
-- @Simplify@ do without being @Listable@, and is the given rule otherwise.
overList :: (Expr -> Eff es (Maybe Expr)) -> Expr -> Eff es (Maybe Expr)
overList f e = case e of
  Call self [Call l xs] | l == sList -> pure (Just (apply sList [apply self [x] | x <- xs]))
  _ -> f e

-- | Run a procedure with every held argument of the expression out of its
-- reach. An expression with none is passed as it is, at the cost of one
-- attribute lookup per compound node.
outsideHeld :: (Kernel :> es) => (Expr -> Either Undefined Expr) -> Expr -> Eff es (Either Undefined Expr)
outsideHeld f u = do
  (held, u') <- runShield (shield u) HashMap.empty
  pure $
    case u' of
      Just v -> snd . restore (table held) <$> f v
      Nothing -> f u
  where
    table held = V.fromList (map fst (sortOn snd (HashMap.toList held)))

-- | The placeholders' head, in a context no user symbol is read into.
sHeld :: Symbol
sHeld = symbol "Cassini`Private`" "Held"

placeholder :: Int -> Expr
placeholder k = apply sHeld [mkNumber (NInt (toInteger k))]

-- | A state of the held arguments seen so far, each with its index; equal
-- arguments share one, so the procedure still sees that they are equal.
newtype Shield es a = Shield {runShield :: HashMap Expr Int -> Eff es (HashMap Expr Int, a)}

-- | Replace each held argument by its placeholder. 'Nothing' when the
-- expression holds nothing, so that it is passed on unrebuilt.
shield :: (Kernel :> es) => Expr -> Shield es (Maybe Expr)
shield u = Shield $ \m -> case u of
  App h as -> do
    attrs <- case h of
      Sym s -> lookupAttributes s
      _ -> pure (attributeSet [])
    (m1, h') <- case h of
      App _ _ -> runShield (shield h) m
      _ -> pure (m, Nothing)
    let n = V.length as
        go mm i = \case
          [] -> pure (mm, [])
          a : rest -> do
            (mm', a') <-
              if holdsArgument attrs i n
                then pure (hold mm a)
                else runShield (shield a) mm
            (mm'', rest') <- go mm' (i + 1) rest
            pure (mm'', a' : rest')
    (m2, as') <- go m1 1 (V.toList as)
    pure $
      if isNothing h' && all isNothing as'
        then (m2, Nothing)
        else (m2, Just (mkApp (fromMaybe h h') (V.fromList (zipWith fromMaybe (V.toList as) as'))))
  _ -> pure (m, Nothing)
  where
    hold mm a = case HashMap.lookup a mm of
      Just k -> (mm, Just (placeholder k))
      Nothing -> let k = HashMap.size mm in (HashMap.insert a k mm, Just (placeholder k))

-- | Put the held arguments back. A sum or product a placeholder sat in is
-- sorted again, since the arguments and their placeholders need not sort
-- alike; nothing else depends on it, because equal arguments had equal
-- placeholders and so combined as they would have. The flag says whether
-- anything changed below.
restore :: V.Vector Expr -> Expr -> (Bool, Expr)
restore held u = case u of
  Call g [Int_ k] | g == sHeld, Just v <- held V.!? fromInteger k -> (True, v)
  App h as ->
    let (ch, h') = restore held h
        rs = V.map (restore held) as
        as' = V.map snd rs
     in if ch || V.any fst rs
          then (True, mkApp h' (if sorted h' then V.fromList (sortBy compareCanonical (V.toList as')) else as'))
          else (False, u)
  _ -> (False, u)
  where
    sorted = \case
      Sym s -> s == sPlus || s == sTimes
      _ -> False
