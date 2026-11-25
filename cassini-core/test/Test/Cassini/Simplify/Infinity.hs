-- | §4.15's infinity pass: the extended-real and Riemann-sphere tables, and
-- the guards on infinity-bearing terms, with the infinity half of §7.3's
-- @Simplify.Numeric@ row (DESIGN.md §4.15, D25).
module Test.Cassini.Simplify.Infinity (tests) where

import Test.Kernel (evalStd)
import Test.QuickCheck (Gen, Property, counterexample, elements, forAll, oneof, sized, (===))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "Simplify.Infinity"
    [ testProperty "Plus, Times and Power agree with the tables on every pair (§7.3)" tables,
      testProperty "u - u, 2u - u, u/u and u^0 are Indeterminate for infinity-bearing u (§7.3)" noCancellation
    ]

-- | The fixed set of values: rationals of each sign and size, and the
-- three infinities.
data V = F Rational | Inf Integer | CInf
  deriving stock (Eq, Show)

values :: [V]
values = [F (-2), F (-1), F (-(1 / 2)), F 0, F (1 / 2), F 1, F 2, Inf 1, Inf (-1), CInf]

fullForm :: V -> Text
fullForm = \case
  F r
    | denominator r == 1 -> show (numerator r)
    | otherwise -> "Rational[" <> show (numerator r) <> ", " <> show (denominator r) <> "]"
  Inf d -> "DirectedInfinity[" <> show d <> "]"
  CInf -> "DirectedInfinity[]"

-- | What the table says, when it says anything: 'Nothing' for two finite
-- operands (Cohen's) and for the forms the table leaves unevaluated.
plusT, timesT, powerT :: V -> V -> Maybe Text
plusT a b = case (a, b) of
  (F _, F _) -> Nothing
  (F _, y) -> Just (fullForm y)
  (x, F _) -> Just (fullForm x)
  (Inf d, Inf e) | d == e -> Just (fullForm (Inf d))
  _ -> Just "Indeterminate"
timesT a b = case (a, b) of
  (F _, F _) -> Nothing
  (F 0, _) -> Just "Indeterminate"
  (_, F 0) -> Just "Indeterminate"
  (F c, Inf d) -> Just (fullForm (Inf (signum (numerator c) * d)))
  (Inf d, F c) -> Just (fullForm (Inf (signum (numerator c) * d)))
  (Inf d, Inf e) -> Just (fullForm (Inf (d * e)))
  _ -> Just (fullForm CInf)
powerT a b = case (a, b) of
  (Inf _, F 0) -> Just "Indeterminate"
  (CInf, F 0) -> Just "Indeterminate"
  (_, F e) | e < 0, a `elem` [Inf 1, Inf (-1), CInf] -> Just "0"
  (Inf d, F e) | denominator e == 1 -> Just (fullForm (Inf (d ^ numerator e)))
  (Inf 1, F _) -> Just (fullForm (Inf 1))
  (CInf, F _) -> Just (fullForm CInf)
  (F c, Inf 1) -> toward c
  (F 0, Inf (-1)) -> Just (fullForm CInf)
  (F c, Inf (-1)) -> toward (recip c)
  (F _, CInf) -> Just "Indeterminate"
  (Inf 1, Inf 1) -> Just (fullForm CInf)
  (Inf 1, Inf (-1)) -> Just "0"
  _ -> Nothing
  where
    toward c
      | c > 1 = Just (fullForm (Inf 1))
      | c < -1 = Just (fullForm CInf)
      | abs c < 1 = Just "0"
      | otherwise = Just "Indeterminate"

tables :: Property
tables =
  forAll (elements ["Plus", "Times", "Power" :: Text]) $ \op ->
    forAll (elements values) $ \a ->
      forAll (elements values) $ \b ->
        case (if op == "Plus" then plusT else if op == "Times" then timesT else powerT) a b of
          Nothing -> counterexample "no row" True
          Just expected ->
            let input = op <> "[" <> fullForm a <> ", " <> fullForm b <> "]"
             in counterexample (toString input) $ evalStd [input] === expected

-- | Infinity-bearing expressions: an infinity, a sum or product with one, a
-- numeric multiple, and a square.
genBearing :: Int -> Gen Text
genBearing n
  | n <= 1 = elements ["DirectedInfinity[1]", "DirectedInfinity[-1]", "DirectedInfinity[]"]
  | otherwise =
      oneof
        [ genBearing 1,
          (\u -> "Plus[x, " <> u <> "]") <$> genBearing (n `div` 2),
          (\u -> "Times[y, " <> u <> "]") <$> genBearing (n `div` 2),
          (\u c -> "Times[" <> c <> ", " <> u <> "]") <$> genBearing (n `div` 2) <*> elements ["2", "-3", "Rational[1, 2]"],
          (\u -> "Power[" <> u <> ", 2]") <$> genBearing (n `div` 2)
        ]

noCancellation :: Property
noCancellation =
  forAll (sized (genBearing . min 16)) $ \u ->
    forAll (elements ["Plus[U, Times[-1, U]]", "Plus[Times[2, U], Times[-1, U]]", "Times[U, Power[U, -1]]", "Power[U, 0]" :: Text]) $ \form ->
      let input = replaceU form
          replaceU = toText . go . toString
          go = \case
            'U' : rest -> toString u <> go rest
            c : rest -> c : go rest
            [] -> []
       in counterexample (toString input) $ evalStd [input] === "Indeterminate"
