{-# LANGUAGE DerivingVia #-}

-- | The attribute set as a bitmask, and the predicates the evaluator asks it
-- (DESIGN.md §4.1).
--
-- A bitmask, because the evaluator asks several attribute questions per step
-- and a @Set@ allocation per question is not acceptable in that loop. The
-- evaluator calls the named predicates, not raw bit tests, so the
-- @HoldFirst@/@HoldRest@ index arithmetic lives in 'holdsArgument' alone.
module Cassini.Attributes
  ( AttributeSet,
    Attribute (..),
    attributeSet,
    attributeList,
    member,
    insert,
    delete,
    attributeName,
    attributeFromName,

    -- * Predicates
    holdsArgument,
    isFlat,
    isOrderless,
    isListable,
    isNumericFunction,
    isProtected,
    sequenceHold,
    holdAllComplete,
  )
where

import Data.Bits (Ior (..), complement, setBit, testBit, (.&.))
import Text.Show (Show (showsPrec))

-- | A set of attributes. The monoid is union.
newtype AttributeSet = AttributeSet Word32
  deriving newtype (Eq)
  deriving (Semigroup, Monoid) via (Ior Word32)

instance Show AttributeSet where
  showsPrec d s = showsPrec d (attributeList s)

-- | The language's whole attribute table, including the attributes nothing
-- reads yet: @Attributes[Plus]@ must report what the language reports, and an
-- attribute without a bit is a @SetAttributes@ that silently drops it.
data Attribute
  = Orderless
  | Flat
  | OneIdentity
  | Listable
  | NumericFunction
  | HoldFirst
  | HoldRest
  | HoldAll
  | HoldAllComplete
  | SequenceHold
  | Protected
  | Constant
  | ReadProtected
  | NHoldFirst
  | NHoldRest
  | NHoldAll
  | Locked
  | Stub
  | Temporary
  deriving stock (Eq, Ord, Show, Enum, Bounded)

bit :: Attribute -> Word32
bit = setBit 0 . fromEnum

-- | The set of the given attributes.
attributeSet :: [Attribute] -> AttributeSet
attributeSet = foldMap (AttributeSet . bit)

-- | The attributes in the set, in the order WL prints them: by name.
--
-- >>> attributeList (attributeSet [Orderless, Flat, Listable])
-- [Flat,Listable,Orderless]
attributeList :: AttributeSet -> [Attribute]
attributeList s = sortOn attributeName (filter (`member` s) universe)

-- | Whether the set holds the attribute.
member :: Attribute -> AttributeSet -> Bool
member a (AttributeSet w) = testBit w (fromEnum a)

-- | The set with the attribute added.
insert :: Attribute -> AttributeSet -> AttributeSet
insert a s = s <> attributeSet [a]

-- | The set with the attribute removed.
delete :: Attribute -> AttributeSet -> AttributeSet
delete a (AttributeSet w) = AttributeSet (w .&. complement (bit a))

-- | The attribute's name in the language: its constructor's name.
attributeName :: Attribute -> Text
attributeName = show

-- | The attribute with this name, if there is one.
--
-- >>> attributeFromName "HoldRest"
-- Just HoldRest
attributeFromName :: Text -> Maybe Attribute
attributeFromName t = find ((== t) . attributeName) universe

-- | Whether the argument at a 1-based index, of the given arity, is held
-- unevaluated (step 4 of §4.4). @HoldFirst@ holds the first argument,
-- @HoldRest@ every other one, and @HoldAll@ and @HoldAllComplete@ every one.
--
-- >>> map (\i -> holdsArgument (attributeSet [HoldRest]) i 3) [1, 2, 3]
-- [False,True,True]
holdsArgument :: AttributeSet -> Int -> Int -> Bool
holdsArgument s i n
  | i < 1 || i > n = False
  | member HoldAll s || member HoldAllComplete s = True
  | i == 1 = member HoldFirst s
  | otherwise = member HoldRest s

-- | @Flat@: step 7.
isFlat :: AttributeSet -> Bool
isFlat = member Flat

-- | @Orderless@: step 9.
isOrderless :: AttributeSet -> Bool
isOrderless = member Orderless

-- | @Listable@: step 8.
isListable :: AttributeSet -> Bool
isListable = member Listable

-- | @NumericFunction@: the @Indeterminate@ step between 9 and 10.
isNumericFunction :: AttributeSet -> Bool
isNumericFunction = member NumericFunction

-- | @Protected@: assignments refuse the symbol.
isProtected :: AttributeSet -> Bool
isProtected = member Protected

-- | Whether @Sequence@ arguments stay unspliced (step 5): @SequenceHold@ or
-- @HoldAllComplete@.
sequenceHold :: AttributeSet -> Bool
sequenceHold s = member SequenceHold s || member HoldAllComplete s

-- | @HoldAllComplete@, which also switches off steps 5, 6 and the upvalue
-- rungs.
holdAllComplete :: AttributeSet -> Bool
holdAllComplete = member HoldAllComplete
