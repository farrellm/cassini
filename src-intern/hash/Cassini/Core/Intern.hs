{-# OPTIONS_GHC -fno-full-laziness -fno-cse #-}

-- | Hash-only node construction: the @intern@ flag's default (DESIGN.md §3.4,
-- step 1). Every node caches its structural hash and is 'notInterned'.
--
-- The other implementation, behind the flag, is in @src-intern/weak@; both
-- export exactly 'intern'.
module Cassini.Core.Intern (intern) where

import {-# SOURCE #-} Cassini.Core.Expr.Internal (Expr (..), Shape, hashShape, notInterned)
import System.IO.Unsafe (unsafePerformIO)

-- | Build a node. Pure: no table is consulted.
intern :: Shape -> Expr
intern s = Expr (hashShape s) notInterned dummyKey s

-- | The weak-pointer key every node shares when nothing is weakly referenced.
dummyKey :: IORef ()
dummyKey = unsafePerformIO (newIORef ())
{-# NOINLINE dummyKey #-}
