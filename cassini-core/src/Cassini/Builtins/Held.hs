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
import Cassini.Structure (rebuildChanged)
import Data.HashMap.Strict qualified as HashMap
import Data.Vector qualified as V
import Effectful (Eff, (:>))
import Effectful.State.Static.Local (State, get, put, runState)

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
  (u', held) <- runState (HashMap.empty :: HashMap Expr Int) (shield u)
  pure $
    case u' of
      -- a result the held arguments vanished from is returned as it is
      Just v -> (\r -> fromMaybe r (restore (table held) r)) <$> f v
      Nothing -> f u
  where
    table held = V.fromList (map fst (sortOn snd (HashMap.toList held)))

-- | The placeholders' head, in a context no user symbol is read into.
sHeld :: Symbol
sHeld = symbol "Cassini`Private`" "Held"

placeholder :: Int -> Expr
placeholder k = apply sHeld [mkNumber (NInt (toInteger k))]

-- | Replace each held argument by its placeholder. 'Nothing' when the
-- expression holds nothing, so that it is passed on unrebuilt. The state is
-- the held arguments seen so far, each with its index; equal arguments share
-- one, so the procedure still sees that they are equal.
shield :: (Kernel :> es, State (HashMap Expr Int) :> es) => Expr -> Eff es (Maybe Expr)
shield = \case
  App h as -> do
    attrs <- case h of
      Sym s -> lookupAttributes s
      _ -> pure (attributeSet [])
    h' <- case h of
      App _ _ -> shield h
      _ -> pure Nothing
    let n = V.length as
    as' <- V.imapM (\i a -> if holdsArgument attrs (i + 1) n then Just <$> hold a else shield a) as
    pure (rebuildChanged h as h' as')
  _ -> pure Nothing
  where
    hold a = do
      m <- get
      k <- case HashMap.lookup a m of
        Just k -> pure k
        Nothing -> let k = HashMap.size m in k <$ put (HashMap.insert a k m)
      pure (placeholder k)

-- | Put the held arguments back. A sum or product a placeholder sat in is
-- sorted again, since the arguments and their placeholders need not sort
-- alike; nothing else depends on it, because equal arguments had equal
-- placeholders and so combined as they would have. 'Nothing' when nothing
-- changed below.
restore :: V.Vector Expr -> Expr -> Maybe Expr
restore held u = case u of
  Call g [Int_ k] | g == sHeld, Just v <- held V.!? fromInteger k -> Just v
  App h as -> resort <$> rebuildChanged h as (restore held h) (V.map (restore held) as)
  _ -> Nothing
  where
    resort = \case
      App h' as' | sorted h' -> mkApp h' (V.fromList (sortBy compareCanonical (V.toList as')))
      v -> v
    sorted = \case
      Sym s -> s == sPlus || s == sTimes
      _ -> False
