-- The representation, for "Cassini.Core.Intern", which builds nodes and which
-- "Cassini.Core.Expr.Internal" imports for 'Corecursive'. Must agree with the
-- module exactly.
module Cassini.Core.Expr.Internal (Expr (..), Shape (..), notInterned, hashShape) where

import Cassini.Core.Symbol (Symbol)
import Cassini.Number (Number)
import Data.Vector qualified as V

data Expr = Expr
  { exprHash :: {-# UNPACK #-} !Int,
    exprId :: {-# UNPACK #-} !Int,
    exprKey :: !(IORef ()),
    exprShape :: !Shape
  }

data Shape
  = SNumber !Number
  | SString !Text
  | SSymbol !Symbol
  | SApp !Expr !(V.Vector Expr)

instance Eq Shape

notInterned :: Int

hashShape :: Shape -> Int
