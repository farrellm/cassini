-- | Shared generators and expression-building shorthand (DESIGN.md §7.3).
--
-- 'genExpr' draws symbols from a small fixed pool, so that generated terms
-- share subterms; with fresh symbols everywhere, no two subterms would be equal
-- and every law about equal subterms would pass vacuously.
module Test.Gen
  ( -- * Generators
    genNumber,
    genExpr,
    genBAE,
    genRNE,
    genPattern,
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
import Cassini.Core.Symbol (globalSymbol, sBlank, sFactorial, sPattern, sPlus, sPower, sTimes)
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

-- | A basic algebraic expression (Cohen §3.1): numbers, symbols, and sums,
-- products, binary powers, unary factorials and functions of them. The
-- domain of 'Cassini.Simplify.Automatic.simplify'\'s contracts. Exponents
-- stay small, so numbers stay small.
genBAE :: Int -> Gen Expr
genBAE n
  | n <= 1 = leaf
  | otherwise =
      frequency
        [ (2, leaf),
          (3, plus <$> args 2 3),
          (3, times <$> args 2 3),
          (3, power <$> genBAE (n `div` 2) <*> exponentE),
          (1, factorial <$> genBAE (n `div` 2)),
          (2, fn <$> elements ["f", "g"] <*> args 1 2)
        ]
  where
    leaf =
      frequency
        [ (2, mkNumber <$> smallNumber),
          (5, sym <$> elements ["a", "b", "c", "x", "y"])
        ]
    smallNumber =
      oneof
        [ NInt <$> chooseInteger (-3, 3),
          fromRational' <$> ((%) <$> chooseInteger (-3, 3) <*> chooseInteger (1, 3))
        ]
    exponentE =
      frequency
        [ (4, int <$> chooseInteger (-2, 3)),
          (2, rat <$> elements [1 % 2, -(1 % 2), 1 % 3]),
          (1, sym <$> elements ["m", "n"])
        ]
    args lo hi = do
      k <- chooseInt (lo, hi)
      vectorOf k (genBAE ((n - 1) `div` k))

-- | A rational number expression (Cohen §2.2): numbers under sums,
-- products and integer powers.
genRNE :: Int -> Gen Expr
genRNE n
  | n <= 1 = mkNumber <$> genNumberSmall
  | otherwise =
      frequency
        [ (2, mkNumber <$> genNumberSmall),
          (2, plus <$> vectorOf 2 (genRNE (n `div` 2))),
          (2, times <$> vectorOf 2 (genRNE (n `div` 2))),
          (1, power <$> genRNE (n `div` 2) <*> (int <$> chooseInteger (-2, 2)))
        ]
  where
    genNumberSmall =
      oneof
        [ NInt <$> chooseInteger (-4, 4),
          fromRational' <$> ((%) <$> chooseInteger (-4, 4) <*> chooseInteger (1, 4))
        ]

-- | A pattern derived from a subject by replacing subterms with named
-- blanks, sometimes head-constrained, so it matches by construction
-- (DESIGN.md §7.3). Each blank's name is its position, so no two share one.
-- It builds no side conditions (§4.5.2).
genPattern :: Expr -> Gen Expr
genPattern = go "pv"
  where
    go path e = frequency [(1, blank path e), (3, descend path e)]
    blank path e = do
      constrained <- arbitrary
      let b = if constrained then apply sBlank [exprHead e] else apply sBlank []
      pure (apply sPattern [sym path, b])
    descend path e = case e of
      App h as -> do
        h' <- go (path <> "h") h
        as' <- V.imapM (\i a -> go (path <> "a" <> show i) a) as
        pure (mkApp h' as')
      _ -> pure e
