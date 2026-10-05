{-# LANGUAGE MagicHash #-}
{-# LANGUAGE UnboxedTuples #-}
{-# OPTIONS_GHC -fno-full-laziness -fno-cse #-}

-- | Hash-consing through a global weak-value table: the @intern@ flag's
-- implementation (DESIGN.md §3.4, step 2).
--
-- Structurally equal nodes built while one is live share a node and an id.
-- Each node carries a fresh unit 'IORef' as its weak-pointer key, so an entry
-- lives exactly as long as some copy of its node does; a finalizer deletes the
-- entry, and lookups drop dead entries as they scan. A premature reap costs a
-- duplicate node, never an answer, because 'Eq' does not trust ids alone.
--
-- Source for the observation that the collector's weak references make this
-- safe: @references/papers/haskell/zhu2025_hash_consing.pdf@.
module Cassini.Core.Intern (intern) where

import {-# SOURCE #-} Cassini.Core.Expr.Internal (Expr (..), Shape, hashShape)
import Control.Concurrent.MVar (modifyMVar, modifyMVar_)
import Control.Exception (evaluate)
import Data.HashMap.Strict qualified as HashMap
import GHC.Exts (mkWeak#)
import GHC.IO (IO (IO))
import GHC.IORef (IORef (IORef))
import GHC.STRef (STRef (STRef))
import GHC.Weak (Weak (Weak), deRefWeak)
import System.IO.Unsafe (unsafePerformIO)

-- | Entries keyed by structural hash; the 'Int' in each is the entry serial
-- that 'reap' deletes, which is also the node's id.
data Table = Table !Int !(HashMap.HashMap Int [(Int, Weak Expr)])

-- | The finalizers are a second writer, and 'intern' allocates weak pointers in
-- its critical section, so an 'MVar' rather than 'atomicModifyIORef''.
internTable :: MVar Table
internTable = unsafePerformIO (newMVar (Table 0 HashMap.empty))
{-# NOINLINE internTable #-}

-- | The node of this shape: an existing live one, or a new one entered in the
-- table.
intern :: Shape -> Expr
intern s = unsafePerformIO (internIO s)
{-# NOINLINE intern #-}

internIO :: Shape -> IO Expr
internIO s = do
  -- Hashing forces every child to WHNF. It must happen outside the critical
  -- section: an unforced child is a pending 'intern', which would deadlock.
  h <- evaluate (hashShape s)
  modifyMVar internTable (insertOrFind h)
  where
    insertOrFind h t@(Table next table) = do
      let bucket = HashMap.findWithDefault [] h table
      (found, dead) <- scan h bucket
      -- Rebuild the bucket only when it held dead entries.
      live <- if dead then filterM (fmap isJust . deRefWeak . snd) bucket else pure bucket
      let table' = if dead then HashMap.insert h live table else table
      case found of
        Just e -> pure (if dead then Table next table' else t, e)
        Nothing -> do
          key <- newIORef ()
          let e = Expr h next key s
          w <- weakOn key e (reap h next)
          pure (Table (next + 1) (HashMap.insert h ((next, w) : live) table'), e)
    -- The first live node with this shape, and whether any entry was dead.
    scan h = go False
      where
        go dead [] = pure (Nothing, dead)
        go dead ((_, w) : rest) =
          deRefWeak w >>= \case
            Nothing -> go True rest
            Just e
              | e.exprHash == h && e.exprShape == s -> pure (Just e, dead)
              | otherwise -> go dead rest

-- | A weak pointer keyed on the 'IORef''s primitive 'MutVar#', as
-- 'Data.IORef.mkWeakIORef' does, with the node as its value.
weakOn :: IORef () -> Expr -> IO () -> IO (Weak Expr)
weakOn (IORef (STRef r#)) e (IO finalizer) = IO $ \st ->
  case mkWeak# r# e finalizer st of
    (# st', w #) -> (# st', Weak w #)

-- | Delete entry @n@ from bucket @h@.
reap :: Int -> Int -> IO ()
reap h n = modifyMVar_ internTable $ \(Table next table) ->
  pure (Table next (HashMap.update dropEntry h table))
  where
    dropEntry entries = case filter ((/= n) . fst) entries of
      [] -> Nothing
      rest -> Just rest
