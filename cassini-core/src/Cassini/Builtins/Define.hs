{-# LANGUAGE PatternSynonyms #-}

-- | The shape every builtin module exports, and the helpers they share.
--
-- A builtin is a symbol's attributes and its native rules. Each module of
-- @Cassini.Builtins.*@ exports a list of 'Definition's, and
-- "Cassini.Builtins" assembles them into one kernel state, numbering the
-- implementations (§4.2: a rule holds a 'Cassini.Rules.BuiltinId', not a
-- function).
module Cassini.Builtins.Define
  ( Definition (..),
    NativeRule (..),
    define,
    down,
    up,
    own,
    sub,
    args,
    message,
    sym,
    sNullE,
    sTrueE,
    sFalseE,
    sFailedE,
    PartSpec (..),
    partSpec,
    Bound (..),
    levelSpec,
    inLevel,
    firstJustM,
  )
where

import Cassini.Attributes (Attribute)
import Cassini.Core.Expr (Expr, exprArgs, pattern App, pattern Int_, pattern Sym)
import Cassini.Core.Symbol (Symbol, sDirectedInfinity, sFalse, sList, sNull, sTrue, systemSymbol)
import Cassini.Eval.Kernel (BuiltinFn (..), Kernel, emitMessage)
import Cassini.Eval.Message (MessageTag (..))
import Cassini.Rules (ValueKind (..))
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | One native rule: which table it goes in, and its implementation. A
-- native rule is never matched by pattern: its implementation decides, and
-- answers 'Nothing' when it does not apply.
data NativeRule = NativeRule
  { nrKind :: !ValueKind,
    nrFn :: !BuiltinFn
  }

-- | A builtin symbol: its attributes and its native rules, in order.
data Definition = Definition
  { defSymbol :: !Symbol,
    defAttributes :: ![Attribute],
    defRules :: ![NativeRule]
  }

-- | A @System`@ symbol with attributes and rules.
define :: Text -> [Attribute] -> [NativeRule] -> Definition
define name = Definition (systemSymbol name)

-- | A built-in downvalue.
down :: (forall es. (Kernel :> es) => Expr -> Eff es (Maybe Expr)) -> NativeRule
down f = NativeRule DownValue (BuiltinFn f)

-- | A built-in upvalue.
up :: (forall es. (Kernel :> es) => Expr -> Eff es (Maybe Expr)) -> NativeRule
up f = NativeRule UpValue (BuiltinFn f)

-- | A built-in own value.
own :: (forall es. (Kernel :> es) => Expr -> Eff es (Maybe Expr)) -> NativeRule
own f = NativeRule OwnValue (BuiltinFn f)

-- | A built-in subvalue.
sub :: (forall es. (Kernel :> es) => Expr -> Eff es (Maybe Expr)) -> NativeRule
sub f = NativeRule SubValue (BuiltinFn f)

-- | The arguments, as a list.
args :: Expr -> [Expr]
args = V.toList . exprArgs

-- | Emit @System`symbol::tag@.
message :: (Kernel :> es) => Text -> Text -> [Expr] -> Eff es ()
message s t = emitMessage (systemSymbol s) (MessageTag t)

-- | A @System`@ symbol as an expression.
sym :: Text -> Expr
sym = Sym . systemSymbol

-- | @Null@, @True@, @False@ and @$Failed@.
sNullE, sTrueE, sFalseE, sFailedE :: Expr
sNullE = Sym sNull
sTrueE = Sym sTrue
sFalseE = Sym sFalse
sFailedE = sym "$Failed"

-- | One index of @Part@ or of a part assignment.
data PartSpec = Index !Integer | Indices ![Integer] | AllParts

-- | An index as a part specification, or the index itself when it is not one
-- (@Part::pkspec1@, @Set::pkspec1@).
partSpec :: Expr -> Either Expr PartSpec
partSpec = \case
  Int_ i -> Right (Index i)
  Sym a | a == sAll -> Right AllParts
  j@(App (Sym l) js)
    | l == sList -> maybeToRight j (Indices <$> traverse intIndex (V.toList js))
  j -> Left j
  where
    sAll = systemSymbol "All"
    intIndex = \case
      Int_ i -> Just i
      _ -> Nothing

-- | One bound of a level specification.
data Bound = Level !Integer | Infinite

-- | @n@ is @{1, n}@, @{n}@ is @{n, n}@, @Infinity@ is @{1, Infinity}@ and
-- @All@ is @{0, Infinity}@.
levelSpec :: Expr -> Maybe (Bound, Bound)
levelSpec spec = case spec of
  App (Sym l) ns | l == sList -> case V.toList ns of
    [n] -> (\b -> (b, b)) <$> bound n
    [m, n] -> (,) <$> bound m <*> bound n
    _ -> Nothing
  Sym a | a == systemSymbol "All" -> Just (Level 0, Infinite)
  _ -> (Level 1,) <$> bound spec
  where
    bound = \case
      Int_ n -> Just (Level n)
      App (Sym d) xs | d == sDirectedInfinity, [Int_ 1] <- V.toList xs -> Just Infinite
      _ -> Nothing

-- | Whether a part at level @p@ with depth @d@ is in the specification: a
-- non-negative bound compares the level, a negative bound @-k@ the depth.
inLevel :: (Bound, Bound) -> Integer -> Integer -> Bool
inLevel (lo, hi) p d = lower lo && upper hi
  where
    lower = \case
      Level m | m >= 0 -> p >= m
      Level m -> negate d >= m
      Infinite -> False
    upper = \case
      Level n | n >= 0 -> p <= n
      Level n -> negate d <= n
      Infinite -> True

-- | The first 'Just' of an effectful search, trying no more than it needs.
firstJustM :: (Monad m) => (a -> m (Maybe b)) -> [a] -> m (Maybe b)
firstJustM f = \case
  [] -> pure Nothing
  x : xs -> f x >>= maybe (firstJustM f xs) (pure . Just)
