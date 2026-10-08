-- | Shared generators and expression-building shorthand (DESIGN.md §7.3).
--
-- 'genExpr' draws symbols from a small fixed pool, so that generated terms
-- share subterms; with fresh symbols everywhere, no two subterms would be equal
-- and every law about equal subterms would pass vacuously.
module Test.Gen
  ( -- * Generators
    genNumber,
    genExpr,
    genSubterm,
    shrinkExpr,
    subterms,
    everyKind,

    -- * Shorthand
    sym,
    int,
    rat,
    str,
    plus,
    times,
    power,
    factorial,
    fn,
  )
where

import Cassini.Core.Expr
import Cassini.Core.Symbol (globalSymbol, sFactorial, sPlus, sPower, sTimes)
import Cassini.Number (Number (NInt, NRat), fromRational')
import Data.Ratio ((%))
import Data.Vector qualified as V
import Test.QuickCheck (Gen, arbitrary, chooseInt, chooseInteger, elements, frequency, oneof, shrink, vectorOf)

-- | A global symbol.
sym :: Text -> Expr
sym = mkSymbol . globalSymbol

-- | An integer.
int :: Integer -> Expr
int = Int_

-- | A rational, normalized.
rat :: Rational -> Expr
rat = mkNumber . fromRational'

-- | A string.
str :: Text -> Expr
str = mkString

-- | @Plus[xs]@.
plus :: [Expr] -> Expr
plus = apply sPlus

-- | @Times[xs]@.
times :: [Expr] -> Expr
times = apply sTimes

-- | @Power[b, e]@.
power :: Expr -> Expr -> Expr
power b e = apply sPower [b, e]

-- | @Factorial[x]@.
factorial :: Expr -> Expr
factorial x = apply sFactorial [x]

-- | @f[xs]@ for a global @f@.
fn :: Text -> [Expr] -> Expr
fn f = apply (globalSymbol f)

-- | Small integers and fractions, both signs.
genNumber :: Gen Number
genNumber =
  oneof
    [ NInt <$> chooseInteger (-5, 5),
      fromRational' <$> ((%) <$> chooseInteger (-6, 6) <*> chooseInteger (1, 4)),
      NInt <$> arbitrary
    ]

genAtom :: Gen Expr
genAtom =
  frequency
    [ (3, mkNumber <$> genNumber),
      (1, str <$> elements ["", "a", "b"]),
      (6, sym <$> elements ["a", "b", "c", "x", "y"])
    ]

-- | A size-bounded expression; the size budget is split among the arguments.
-- Heads include @Plus@, @Times@, @Power@ (usually binary, sometimes not),
-- @Factorial@, plain functions and curried heads, so every kind and every
-- malformed variant is reached.
genExpr :: Int -> Gen Expr
genExpr n
  | n <= 1 = genAtom
  | otherwise =
      frequency
        [ (2, genAtom),
          (3, plus <$> args 0 3),
          (3, times <$> args 0 3),
          (3, power <$> sub 2 <*> sub 2),
          (1, apply sPower <$> args 0 3),
          (1, factorial <$> sub 1),
          (1, apply sFactorial <$> args 0 2),
          (3, fn <$> elements ["f", "g", "x"] <*> args 0 3),
          (1, mkApp . fn "f" <$> args 1 1 <*> (V.fromList <$> args 0 2))
        ]
  where
    sub k = genExpr ((n - 1) `div` k)
    args lo hi = do
      k <- chooseInt (lo, hi)
      vectorOf k (genExpr ((n - 1) `div` max 1 k))

-- | A subterm of the given term, heads included, uniformly.
genSubterm :: Expr -> Gen Expr
genSubterm u = elements (u : subterms u)

-- | Every proper subterm, heads included.
subterms :: Expr -> [Expr]
subterms = \case
  App h as -> concatMap (\c -> c : subterms c) (h : V.toList as)
  _ -> []

-- | Replace a node by a child, shrink numbers toward zero, drop arguments, or
-- shrink one argument.
shrinkExpr :: Expr -> [Expr]
shrinkExpr = \case
  Num (NInt i) -> Int_ <$> shrink i
  Num (NRat r) -> Int_ (truncate r) : (rat <$> shrink r)
  Str t -> [str "" | t /= ""]
  Sym _ -> []
  App h as ->
    h
      : V.toList as
      ++ [mkApp h (V.ifilter (\j _ -> j /= i) as) | i <- [0 .. V.length as - 1]]
      ++ [mkApp h' as | h' <- shrinkExpr h]
      ++ [mkApp h (as V.// [(i, a')]) | (i, a) <- V.toList (V.indexed as), a' <- shrinkExpr a]

-- | One hand-written value of every kind, and of every malformed variant: the
-- pairs O-13 must never be the only rule for (§3.5, §7.3).
everyKind :: [(String, Expr)]
everyKind =
  [ ("integer", int 3),
    ("fraction", rat (1 % 2)),
    ("string", str "s"),
    ("symbol", sym "x"),
    ("product", times [int 2, sym "x"]),
    ("power", power (sym "x") (int 2)),
    ("sum", plus [sym "x", sym "y"]),
    ("factorial", factorial (sym "x")),
    ("function", fn "f" [sym "x"]),
    ("function named by its argument", fn "x" [sym "t"]),
    ("curried-head function", mkApp (fn "f" [sym "x"]) (V.singleton (sym "y"))),
    ("malformed power", apply sPower [sym "x"]),
    ("malformed factorial", apply sFactorial []),
    ("empty sum", plus []),
    ("one-operand product", times [sym "x"])
  ]
