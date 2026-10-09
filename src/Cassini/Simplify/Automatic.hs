{-# LANGUAGE PatternSynonyms #-}

-- | Automatic simplification of sums, products and powers (DESIGN.md §4.6).
--
-- Source: @references/papers/textbooks/cohen2003_*.pdf@ §3.1 (Definition
-- 3.21, the ASAE, with @base@, @exponent@, @term@ and @const@) and §3.2
-- (procedure @Automatic_simplify@ and its subordinate operators: SPOW,
-- SINTPOW, SPRD, SPRDREC, MPRD, and the sum operators the source leaves to
-- its Exercise 7, written here as the product ones are, with @term@ and
-- @const@ in place of @base@ and @exponent@).
--
-- Two departures, each because WL's semantics require it:
--
-- * SPOW-2 calls @0^w@ 'Undefined' for every @w@ that is not a positive
--   number. Here it applies only to numeric @w@, and @0^x@ stays as it is,
--   as in WL: a symbolic exponent is not known to be non-positive. So
--   'isASAE' admits @0^w@ for a non-numeric @w@, against ASAE-6-4, and the
--   source's two contracts hold of the pair.
-- * MPRD-3-2 adjoins a merged factor where the merge happened, so two
--   radicals of one base can merge to a constant behind an existing
--   coefficient (@3·2^(1/2)·2^(1/2)@ gives @[3, 2]@). 'simplifyProduct'
--   multiplies such constants together, which ASAE-4-2 requires.
module Cassini.Simplify.Automatic
  ( -- * The procedure
    simplify,
    Undefined (..),
    isASAE,

    -- * The subordinate operators
    simplifyRNE,
    simplifyRational,
    simplifyPower,
    simplifyIntPower,
    simplifyProduct,
    simplifyProductRec,
    simplifySum,
    simplifySumRec,
    simplifyQuotient,
    simplifyDifference,
    simplifyFactorial,
    simplifyFunction,

    -- * Cohen's operand operators
    powerBase,
    powerExponent,
    term,
    constPart,
  )
where

import Cassini.Core.Expr (Expr, apply, exprArgs, mkApp, mkNumber, pattern App, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Order (compareCanonical)
import Cassini.Core.Symbol (Symbol, sFactorial, sPlus, sPower, sTimes, systemSymbol)
import Cassini.Number (Number (NInt), add, compareNumber, divide, mul, neg, normalize, pow)
import Cassini.Structure (Kind (..), exprKind)
import Data.HashSet qualified as HashSet
import Data.Vector qualified as V

-- $setup
-- >>> import Cassini.Core.Expr (mkSymbol)
-- >>> import Cassini.Core.Symbol (globalSymbol)
-- >>> let a = mkSymbol (globalSymbol "a"); b = mkSymbol (globalSymbol "b")

-- | Why the answer is undefined, so the builtin can choose the result and
-- message (§4.7): @1/0@ is @ComplexInfinity@ with @Power::infy@, @0^0@ is
-- @Indeterminate@ with @Power::indet@. The last four belong to §4.11–§4.12
-- and are not produced here.
data Undefined
  = -- | @0^w@, @w < 0@
    DivisionByZero
  | -- | @0^0@
    ZeroToZero
  | -- | @Tan[π/2]@, @Csc[0]@, … (§4.11)
    Pole
  | -- | @Log[0]@ (§4.11)
    LogOfZero
  | -- | a denominator contracted to 0, numerator not (§4.12)
    ZeroDenominator
  | -- | numerator and denominator both contracted to 0 (§4.12)
    ZeroOverZero
  deriving stock (Eq, Show)

-- | Cohen's @Automatic_simplify@, recursive: simplify the operands, then the
-- node by its kind. @Divide@, @Subtract@ and @Minus@ are Cohen's quotient and
-- difference operators.
--
-- >>> simplify (apply sPlus [a, apply sPlus [b, a]])
-- Right Plus[Times[2, a], b]
simplify :: Expr -> Either Undefined Expr
simplify u = case u of
  Num n -> mkNumber <$> simplifyRational n
  Str _ -> Right u
  Sym _ -> Right u
  App h as -> do
    h' <- case h of
      App _ _ -> simplify h
      _ -> Right h
    vs <- traverse simplify as
    case (h', V.toList vs) of
      (Sym f, [x, y]) | f == sDivide -> simplifyQuotient x y
      (Sym f, _ : _) | f == sSubtract || f == sMinus -> simplifyDifference vs
      _ -> case exprKind (mkApp h' vs) of
        KPower | [v, w] <- V.toList vs -> simplifyPower v w
        KProduct -> simplifyProduct vs
        KSum -> simplifySum vs
        KFactorial | [v] <- V.toList vs -> simplifyFactorial v
        _ -> simplifyFunction h' vs

-- | Cohen's @Simplify_RNE@: the value of a rational number expression (sums,
-- products, differences, quotients and integer powers of numbers).
-- 'Nothing' on division by zero, and on an expression that is not an RNE.
simplifyRNE :: Expr -> Maybe Number
simplifyRNE = \case
  Num n -> Just n
  App (Sym f) as
    | f == sPlus -> foldl' add (NInt 0) <$> traverse simplifyRNE (V.toList as)
    | f == sTimes -> foldl' mul (NInt 1) <$> traverse simplifyRNE (V.toList as)
    | f == sPower, [x, Int_ n] <- V.toList as -> simplifyRNE x >>= (`pow` n)
    | f == sDivide,
      [x, y] <- V.toList as -> do
        x' <- simplifyRNE x
        y' <- simplifyRNE y
        divide x' y'
    | f == sSubtract, [x, y] <- V.toList as -> add <$> simplifyRNE x <*> (neg <$> simplifyRNE y)
    | f == sMinus, [x] <- V.toList as -> neg <$> simplifyRNE x
  _ -> Nothing

-- | Cohen's @Simplify_rational_number@. A 'Number' is already in standard
-- form unless it was built with the raw constructor.
simplifyRational :: Number -> Either Undefined Number
simplifyRational = Right . normalize

-- | Cohen's @Simplify_power@ (SPOW), on a base and an exponent that are
-- already simplified.
simplifyPower :: Expr -> Expr -> Either Undefined Expr
simplifyPower v w
  -- SPOW-2, for numeric exponents only (see the module header)
  | isZero v = case w of
      Num n -> case compareNumber n (NInt 0) of
        GT -> Right (Int_ 0)
        EQ -> Left ZeroToZero
        LT -> Left DivisionByZero
      _ -> Right (apply sPower [v, w])
  -- SPOW-3
  | isOne v = Right (Int_ 1)
  -- SPOW-4
  | Int_ n <- w = simplifyIntPower v n
  -- SPOW-5
  | otherwise = Right (apply sPower [v, w])

-- | Cohen's @Simplify_integer_power@ (SINTPOW).
simplifyIntPower :: Expr -> Integer -> Either Undefined Expr
simplifyIntPower v n = case v of
  -- SINTPOW-1
  Num x -> maybe (Left DivisionByZero) (Right . mkNumber) (pow x n)
  _
    -- SINTPOW-2, 3
    | n == 0 -> Right (Int_ 1)
    | n == 1 -> Right v
  -- SINTPOW-4
  App _ as
    | KPower <- exprKind v,
      [r, s] <- V.toList as -> do
        p <- simplifyProduct (V.fromList [s, Int_ n])
        case p of
          Int_ m -> simplifyIntPower r m
          _ -> Right (apply sPower [r, p])
  -- SINTPOW-5
  App _ as | KProduct <- exprKind v -> traverse (`simplifyIntPower` n) as >>= simplifyProduct
  -- SINTPOW-6
  _ -> Right (apply sPower [v, Int_ n])

-- | Cohen's @Simplify_product@ (SPRD), on operands already simplified.
simplifyProduct :: V.Vector Expr -> Either Undefined Expr
simplifyProduct us
  -- SPRD-2
  | V.any isZero us = Right (Int_ 0)
  -- SPRD-3
  | [u] <- V.toList us = Right u
  -- SPRD-4
  | otherwise = do
      v <- combineConstants <$> simplifyProductRec (V.toList us)
      pure $ case v of
        [] -> Int_ 1
        [x] -> x
        _ -> apply sTimes v

-- | Multiply the constants of a merged operand list into one leading
-- constant, dropped if it is 1. See the module header: MPRD can leave two.
combineConstants :: [Expr] -> [Expr]
combineConstants vs = case [n | Num n <- vs] of
  _ : _ : _ ->
    let c = foldl' mul (NInt 1) [n | Num n <- vs]
        rest = filter (not . isConstant) vs
     in if c == NInt 0 then [Int_ 0] else [mkNumber c | c /= NInt 1] ++ rest
  _ -> vs

-- | Cohen's @Simplify_product_rec@ (SPRDREC): merge the operands of a
-- product into an ordered list of admissible factors, collecting like bases.
simplifyProductRec :: [Expr] -> Either Undefined [Expr]
simplifyProductRec = \case
  [u1, u2]
    -- SPRDREC-1
    | not (isProduct u1) && not (isProduct u2) -> productPair u1 u2
    -- SPRDREC-2
    | otherwise -> mergeProducts (factors u1) (factors u2)
  -- SPRDREC-3
  u1 : rest@(_ : _ : _) -> simplifyProductRec rest >>= mergeProducts (factors u1)
  us -> Right us

-- | SPRDREC-1: two operands, neither a product.
productPair :: Expr -> Expr -> Either Undefined [Expr]
productPair u1 u2
  -- 1
  | Num a <- u1, Num b <- u2 = Right [mkNumber p | let p = mul a b, p /= NInt 1]
  -- 2
  | isOne u1 = Right [u2]
  | isOne u2 = Right [u1]
  -- 3
  | Just b1 <- powerBase u1,
    Just b2 <- powerBase u2,
    b1 == b2 = do
      s <- simplifySum (V.fromList (catMaybes [powerExponent u1, powerExponent u2]))
      p <- simplifyPower b1 s
      Right [p | not (isOne p)]
  -- 4
  | compareCanonical u2 u1 == LT = Right [u2, u1]
  -- 5
  | otherwise = Right [u1, u2]

-- | Cohen's @Merge_products@ (MPRD): two ordered operand lists into one.
mergeProducts :: [Expr] -> [Expr] -> Either Undefined [Expr]
mergeProducts p q = case (p, q) of
  -- MPRD-1, 2
  (_, []) -> Right p
  ([], _) -> Right q
  -- MPRD-3
  (p1 : ps, q1 : qs) ->
    simplifyProductRec [p1, q1] >>= \case
      [] -> mergeProducts ps qs
      [h1] -> (h1 :) <$> mergeProducts ps qs
      [h1, _] | h1 == p1 -> (p1 :) <$> mergeProducts ps q
      _ -> (q1 :) <$> mergeProducts p qs

-- | Cohen's @Simplify_sum@, the counterpart of SPRD (Exercise 7).
simplifySum :: V.Vector Expr -> Either Undefined Expr
simplifySum us
  | [u] <- V.toList us = Right u
  | otherwise = do
      v <- simplifySumRec (V.toList us)
      pure $ case v of
        [] -> Int_ 0
        [x] -> x
        _ -> apply sPlus v

-- | Cohen's @Simplify_sum_rec@: merge the operands of a sum into an ordered
-- list of admissible terms, collecting like terms.
simplifySumRec :: [Expr] -> Either Undefined [Expr]
simplifySumRec = \case
  [u1, u2]
    | not (isSum u1) && not (isSum u2) -> sumPair u1 u2
    | otherwise -> mergeSums (summands u1) (summands u2)
  u1 : rest@(_ : _ : _) -> simplifySumRec rest >>= mergeSums (summands u1)
  us -> Right us

-- | The counterpart of SPRDREC-1: two operands, neither a sum. Like terms
-- (equal 'term') are collected by adding their 'constPart's.
sumPair :: Expr -> Expr -> Either Undefined [Expr]
sumPair u1 u2
  | Num a <- u1, Num b <- u2 = Right [mkNumber s | let s = add a b, s /= NInt 0]
  | isZero u1 = Right [u2]
  | isZero u2 = Right [u1]
  | Just t1 <- term u1,
    Just t2 <- term u2,
    t1 == t2 = do
      s <- simplifySum (V.fromList (catMaybes [constPart u1, constPart u2]))
      p <- simplifyProduct (V.fromList (s : t1))
      Right [p | not (isZero p)]
  | compareCanonical u2 u1 == LT = Right [u2, u1]
  | otherwise = Right [u1, u2]

-- | The counterpart of MPRD for sums.
mergeSums :: [Expr] -> [Expr] -> Either Undefined [Expr]
mergeSums p q = case (p, q) of
  (_, []) -> Right p
  ([], _) -> Right q
  (p1 : ps, q1 : qs) ->
    simplifySumRec [p1, q1] >>= \case
      [] -> mergeSums ps qs
      [h1] -> (h1 :) <$> mergeSums ps qs
      [h1, _] | h1 == p1 -> (p1 :) <$> mergeSums ps q
      _ -> (q1 :) <$> mergeSums p qs

-- | Cohen's @Simplify_quotient@: @u · v^(-1)@.
simplifyQuotient :: Expr -> Expr -> Either Undefined Expr
simplifyQuotient u v = do
  r <- simplifyPower v (Int_ (-1))
  simplifyProduct (V.fromList [u, r])

-- | Cohen's @Simplify_difference@: unary minus is @(-1)·u@, and @u - v@ is
-- @u + (-1)·v@ (n-ary: every operand after the first is subtracted).
simplifyDifference :: V.Vector Expr -> Either Undefined Expr
simplifyDifference us = case V.toList us of
  [u] -> negateE u
  u : rest -> traverse negateE rest >>= simplifySum . V.fromList . (u :)
  [] -> Right (Int_ 0)
  where
    negateE x = simplifyProduct (V.fromList [Int_ (-1), x])

-- | Cohen's @Simplify_factorial@: a non-negative integer operand is
-- computed; any other stays.
simplifyFactorial :: Expr -> Either Undefined Expr
simplifyFactorial = \case
  Int_ n | n >= 0 -> Right (Int_ (product [1 .. n]))
  u -> Right (apply sFactorial [u])

-- | Cohen's @Simplify_function@: a function of simplified operands is
-- simplified; the elementary functions' rules are §4.11's, not Cohen's.
simplifyFunction :: Expr -> V.Vector Expr -> Either Undefined Expr
simplifyFunction f vs = Right (mkApp f vs)

-- | Cohen's @base@: a power's base, any other non-constant itself, and
-- 'Nothing' (Cohen's @Undefined@) for a number.
powerBase :: Expr -> Maybe Expr
powerBase u = case u of
  Num _ -> Nothing
  App _ as | KPower <- exprKind u, [v, _] <- V.toList as -> Just v
  _ -> Just u

-- | Cohen's @exponent@: a power's exponent, 1 for any other non-constant.
powerExponent :: Expr -> Maybe Expr
powerExponent u = case u of
  Num _ -> Nothing
  App _ as | KPower <- exprKind u, [_, w] <- V.toList as -> Just w
  _ -> Just (Int_ 1)

-- | Cohen's @term@, as the operand list of the product it denotes: a
-- product's operands without its leading constant, and @[u]@ for any other
-- non-constant (Cohen's unary product @·u@).
term :: Expr -> Maybe [Expr]
term u = case u of
  Num _ -> Nothing
  App _ as | isProduct u -> case V.toList as of
    Num _ : rest -> Just rest
    xs -> Just xs
  _ -> Just [u]

-- | Cohen's @const@: a product's leading constant, or 1.
constPart :: Expr -> Maybe Expr
constPart u = case u of
  Num _ -> Nothing
  App _ as | isProduct u, Just c@(Num _) <- as V.!? 0 -> Just c
  _ -> Just (Int_ 1)

-- | Definition 3.21, transcribed: whether the expression is an automatically
-- simplified algebraic expression. The postcondition of 'simplify', and
-- exported for the property tests to assert. Strings, and Cohen's quotient
-- and difference operators, are not ASAEs.
--
-- >>> isASAE (apply sPower [apply sTimes [a, b], Int_ 2])
-- False
isASAE :: Expr -> Bool
isASAE u = case u of
  -- ASAE-1, 2
  Num _ -> True
  -- ASAE-3
  Sym _ -> True
  Str _ -> False
  App h as -> case exprKind u of
    -- ASAE-4
    KProduct ->
      V.length as >= 2
        && all admissibleFactor as
        && atMostOneConstant as
        && distinct (mapMaybe powerBase (V.toList as))
        && ordered as
    -- ASAE-5
    KSum ->
      V.length as >= 2
        && all admissibleTerm as
        && atMostOneConstant as
        && distinct (map (apply sTimes) (mapMaybe term (V.toList as)))
        && ordered as
    -- ASAE-6
    KPower
      | [v, w] <- V.toList as ->
          isASAE v
            && isASAE w
            && not (isZero w || isOne w)
            && case w of
              Int_ _ -> exprKind v `elem` [KSymbol, KSum, KFactorial, KFunction]
              Num _ -> not (isZero v || isOne v)
              -- 0^w for a non-numeric w: the SPOW-2 departure's counterpart
              _ -> not (isOne v)
    -- ASAE-7
    KFactorial | [v] <- V.toList as -> isASAE v && not (isNonNegativeInteger v)
    -- ASAE-8
    _ ->
      not (isOperatorHead h)
        && not (V.null as)
        && (case h of Sym _ -> True; _ -> isASAE h)
        && all isASAE as
  where
    admissibleFactor x = isASAE x && not (isZero x || isOne x) && not (isProduct x)
    admissibleTerm x = isASAE x && not (isZero x) && not (isSum x)
    atMostOneConstant xs = V.length (V.filter isConstant xs) <= 1
    distinct xs = HashSet.size (HashSet.fromList xs) == length xs
    ordered xs = and (V.zipWith (\x y -> compareCanonical x y == LT) xs (V.drop 1 xs))
    isNonNegativeInteger = \case
      Int_ n -> n >= 0
      _ -> False
    isOperatorHead = \case
      Sym f -> f `elem` [sDivide, sSubtract, sMinus]
      _ -> False

-- Kinds and constants.

isProduct :: Expr -> Bool
isProduct u = exprKind u == KProduct

isSum :: Expr -> Bool
isSum u = exprKind u == KSum

isConstant :: Expr -> Bool
isConstant = \case
  Num _ -> True
  _ -> False

isZero :: Expr -> Bool
isZero = \case
  Int_ 0 -> True
  _ -> False

isOne :: Expr -> Bool
isOne = \case
  Int_ 1 -> True
  _ -> False

factors :: Expr -> [Expr]
factors u
  | isProduct u = V.toList (exprArgs u)
  | otherwise = [u]

summands :: Expr -> [Expr]
summands u
  | isSum u = V.toList (exprArgs u)
  | otherwise = [u]

sDivide, sSubtract, sMinus :: Symbol
sDivide = systemSymbol "Divide"
sSubtract = systemSymbol "Subtract"
sMinus = systemSymbol "Minus"
