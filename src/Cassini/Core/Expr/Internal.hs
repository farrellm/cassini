{-# LANGUAGE MagicHash #-}
{-# LANGUAGE TypeFamilies #-}

-- | The representation of 'Expr': node shape, cached hash, intern id, the
-- 'Eq' that holds whichever interning implementation is active, and the base
-- functor (DESIGN.md §3.3–§3.4, §3.6).
--
-- Imported only by @Cassini.Core.*@ and the interning-agreement test. Every
-- other module uses "Cassini.Core.Expr", whose smart constructors keep the
-- hash and the id honest.
--
-- The @recursion-schemes@ instances are here, not in "Cassini.Core.Traversal",
-- because anywhere else they are orphans. 'embed' must call
-- "Cassini.Core.Intern"'s @intern@, which must see this module's types, so
-- @Intern@ imports this module through @Internal.hs-boot@.
module Cassini.Core.Expr.Internal
  ( Expr (..),
    Shape (..),
    ExprF (..),
    notInterned,
    hashShape,
    mkNode,
  )
where

import Cassini.Core.Intern (intern)
import Cassini.Core.Symbol (Symbol)
import Cassini.Number (Number (NInt, NRat), normalize)
import Data.Functor.Foldable (Base, Corecursive (embed), Recursive (project))
import Data.Hashable (Hashable (hash))
import Data.Vector qualified as V
import GHC.Exts (isTrue#, reallyUnsafePtrEquality#)
import Text.Show (Show (showsPrec), showChar, showString, shows)

-- | An expression node. Build one only through 'mkNode', which
-- "Cassini.Core.Expr"'s smart constructors call.
data Expr = Expr
  { -- | Cached structural hash: equal shapes have equal hashes.
    exprHash :: {-# UNPACK #-} !Int,
    -- | Intern id, or 'notInterned'.
    exprId :: {-# UNPACK #-} !Int,
    -- | Weak-pointer key (§3.4); one shared dummy when interning is off.
    exprKey :: !(IORef ()),
    -- | What the node is.
    exprShape :: !Shape
  }

-- | The node shapes, mirroring FullForm.
data Shape
  = SNumber !Number
  | SString !Text
  | SSymbol !Symbol
  | -- | Head and arguments.
    SApp !Expr !(V.Vector Expr)
  deriving stock (Eq)

-- | The id of a node that is not in the intern table.
notInterned :: Int
notInterned = -1

-- | The same heap object proves equality, equal ids prove equality, unequal
-- hashes prove inequality, and only a hash collision or a duplicate node
-- reaches the structural comparison. Never trusts the table alone (§3.4).
--
-- The pointer test can miss, never lie: a miss falls through to the rest. It
-- runs at every level of the structural comparison, so shared subterms cost
-- one comparison each, not a walk. The bangs keep '==' strict: the primop does
-- not force its arguments, and without them every caller's strictness is lost
-- and its arguments are passed as thunks.
instance Eq Expr where
  !x == !y =
    isTrue# (reallyUnsafePtrEquality# x y)
      || (x.exprId == y.exprId && x.exprId /= notInterned)
      || (x.exprHash == y.exprHash && x.exprShape == y.exprShape)

instance Hashable Expr where
  hashWithSalt s e = hashWithSalt s e.exprHash
  hash e = e.exprHash

instance NFData Expr where
  rnf e = rnf e.exprShape

instance NFData Shape where
  rnf = \case
    SNumber n -> rnf n
    SString t -> rnf t
    SSymbol s -> rnf s
    SApp h as -> rnf h `seq` rnf as

-- | FullForm-like, for GHCi and test output. "Cassini.Syntax.FullForm" is the
-- real printer (§2.3).
instance Show Expr where
  showsPrec _ e = case e.exprShape of
    SNumber (NInt i) -> shows i
    SNumber (NRat r) ->
      showString "Rational[" . shows (numerator r) . showString ", " . shows (denominator r) . showChar ']'
    SString t -> shows t
    SSymbol s -> shows s
    SApp h as ->
      shows h . showChar '[' . commaSep (V.toList as) . showChar ']'
    where
      commaSep = foldr (.) id . intersperse (showString ", ") . map shows

-- | The structural hash of a shape whose children carry their own hashes. Both
-- interning implementations hash with this, so the hash does not depend on the
-- flag.
hashShape :: Shape -> Int
hashShape = \case
  SNumber n -> hashWithSalt 0x6e756d (hash n)
  SString t -> hashWithSalt 0x737472 (hash t)
  SSymbol s -> hashWithSalt 0x73796d (hash s)
  SApp h as -> V.foldl' (\acc a -> hashWithSalt acc a.exprHash) (hashWithSalt 0x617070 h.exprHash) as

-- | One layer of an 'Expr'.
data ExprF r
  = NumberF !Number
  | StringF !Text
  | SymbolF !Symbol
  | AppF !r !(V.Vector r)
  deriving stock (Functor, Foldable, Traversable)

type instance Base Expr = ExprF

instance Recursive Expr where
  project e = case e.exprShape of
    SNumber n -> NumberF n
    SString t -> StringF t
    SSymbol s -> SymbolF s
    SApp h as -> AppF h as

-- | Interns a shape, normalizing a number first: the one place a node is
-- built. The smart constructors in "Cassini.Core.Expr" and 'embed' both call
-- it, so a fold cannot build a node they would not.
mkNode :: Shape -> Expr
mkNode =
  intern . \case
    SNumber n -> SNumber (normalize n)
    s -> s

-- | Rebuilds through 'mkNode', as the smart constructors do, so every fold
-- maintains the hash, the id and normalization.
instance Corecursive Expr where
  embed =
    mkNode . \case
      NumberF n -> SNumber n
      StringF t -> SString t
      SymbolF s -> SSymbol s
      AppF h as -> SApp h as
