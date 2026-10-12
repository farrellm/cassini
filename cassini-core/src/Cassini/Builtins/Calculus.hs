{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ViewPatterns #-}

-- | Differentiation: @D@ and @Derivative@ (DESIGN.md §4.9).
--
-- @D@ is a rule table, not a Haskell @case@ on the shape of an expression:
-- each rule below is its own built-in downvalue on @D@, tried in order, and
-- each answers 'Nothing' when it does not apply. A rule's result is a new
-- expression with @D@ inside it, which the fixed point evaluates, so the sum,
-- product and chain rules recurse through the evaluator and not through
-- Haskell. The chain rule's result is @Derivative[…][f][…]@, whose value
-- comes from @Derivative@'s subvalues: a user's (@Derivative[1][f] = …@ or
-- @f'[x_] := …@), the elementary functions' when that track lands (§4.11),
-- or the one built-in subvalue below that differentiates a function given by
-- a user's definitions or a pure function. @Derivative@ is not @Protected@,
-- as in WL, so a user's derivative is an ordinary subvalue.
--
-- Not yet: an exponent that depends on the variable needs @Log@ (§4.11), so
-- @D[x^x, x]@ stays unevaluated until the elementary-functions track.
module Cassini.Builtins.Calculus (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, sub)
import Cassini.Core.Expr (Expr, apply, mkApp, pattern App, pattern Int_, pattern Num, pattern Sym)
import Cassini.Core.Symbol (Symbol, sDerivative, sFunction, sList, sNull, sPlus, sPower, sSlot, sTimes, symbol, systemSymbol)
import Cassini.Eval.Kernel (Kernel, evaluate, lookupSymbol)
import Cassini.Rules (Origin (..), Rule (..), ValueKind (..), ruleSetToList, rulesOf)
import Cassini.Structure (Binding (..), Scoping (Shielding), freeOf, substituteAll, substituteFree)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | @D@ and @Derivative@, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define
      "D"
      [Protected, ReadProtected]
      [ down (pure . noVariable),
        down (pure . severalVariables),
        down (pure . repeated),
        down (pure . overList),
        down (pure . constant),
        down (pure . variable),
        down (pure . sumRule),
        down (pure . productRule),
        down (pure . powerRule),
        down (pure . chainRule)
      ],
    define "Derivative" [NHoldAll, ReadProtected] [sub (pure . derivativeOrder), sub derivativeOfDefinition]
  ]

sD :: Symbol
sD = systemSymbol "D"

-- | @D[f, x]@, the one form the rules after 'overList' differentiate.
dOf :: Expr -> Expr -> Expr
dOf f x = apply sD [f, x]

-- | @D[f, x]@, read: 'Nothing' unless there is exactly one variable, and it
-- is not a number or a list (those are 'repeated''s).
single :: Expr -> Maybe (Expr, Expr)
single e = case args e of
  [f, x] | variableLike x -> Just (f, x)
  _ -> Nothing
  where
    variableLike = \case
      Num _ -> False
      App (Sym l) _ -> l /= sList
      _ -> True

-- | @D[f]@ is @f@.
noVariable :: Expr -> Maybe Expr
noVariable e = case args e of
  [f] -> Just f
  _ -> Nothing

-- | @D[f, x, y, …]@ is @D[D[f, x], y, …]@.
severalVariables :: Expr -> Maybe Expr
severalVariables e = case args e of
  f : x : rest@(_ : _) -> Just (apply sD (apply sD [f, x] : rest))
  _ -> Nothing

-- | @D[f, {x, n}]@ is the @n@th derivative, taken one at a time so that
-- each is evaluated before the next is taken, and @D[f, {x}]@ the first.
-- @D[f, {{x, y, …}}]@ is the gradient, the derivatives in each variable,
-- and for a list of functions the list of their gradients, so a row is a
-- function; @D[f, {{x, y, …}, n}]@ takes it @n@ times
-- (@wolfram/D/Scope/BasicUses/10@).
repeated :: Expr -> Maybe Expr
repeated e = case args e of
  [f, App (Sym l) spec] | l == sList -> case V.toList spec of
    [vs] | isList vs -> Just $ case f of
      App (Sym l') fs | l' == sList -> apply sList [apply sD [g, apply sList [vs]] | g <- V.toList fs]
      _ -> apply sList [dOf f v | v <- argsOf vs]
    [vs, Int_ 0] | isList vs -> Just f
    [vs, Int_ n] | isList vs, n > 0 -> Just (apply sD [apply sD [f, apply sList [vs]], apply sList [vs, Int_ (n - 1)]])
    [x] -> Just (dOf f x)
    [_, Int_ 0] -> Just f
    [x, Int_ n] | n > 0 -> Just (apply sD [dOf f x, apply sList [x, Int_ (n - 1)]])
    _ -> Nothing
  _ -> Nothing
  where
    argsOf =
      V.toList . \case
        App _ xs -> xs
        _ -> V.empty
    isList = \case
      App (Sym l) _ -> l == sList
      _ -> False

-- | @D[{f, g, …}, x]@ is @{D[f, x], D[g, x], …}@.
overList :: Expr -> Maybe Expr
overList e = do
  (f, x) <- single e
  case f of
    App (Sym l) fs | l == sList -> Just (apply sList [dOf g x | g <- V.toList fs])
    _ -> Nothing

-- | An expression free of the variable has derivative 0.
constant :: Expr -> Maybe Expr
constant e = do
  (f, x) <- single e
  guard (freeOf f x)
  Just (Int_ 0)

-- | The variable's derivative is 1.
variable :: Expr -> Maybe Expr
variable e = do
  (f, x) <- single e
  guard (f == x)
  Just (Int_ 1)

-- | The sum rule: the derivative of a sum is the sum of the derivatives.
sumRule :: Expr -> Maybe Expr
sumRule e = do
  (f, x) <- single e
  App (Sym p) us <- Just f
  guard (p == sPlus)
  Just (apply sPlus [dOf u x | u <- V.toList us])

-- | The product rule: one term per factor that depends on the variable,
-- that factor differentiated and the others kept.
productRule :: Expr -> Maybe Expr
productRule e = do
  (f, x) <- single e
  App (Sym t) us <- Just f
  guard (t == sTimes)
  let factors = V.toList us
  Just (apply sPlus [apply sTimes (before <> [dOf u x] <> after) | (before, u, after) <- splits factors, not (freeOf u x)])

-- | The power rule, for an exponent free of the variable:
-- @D[u^n, x]@ is @n u^(n-1) D[u, x]@. An exponent that depends on the
-- variable needs @Log@, which arrives with §4.11; until then 'chainRule'
-- leaves it alone too, and @D@ stays unevaluated.
powerRule :: Expr -> Maybe Expr
powerRule e = do
  (f, x) <- single e
  App (Sym p) bv <- Just f
  guard (p == sPower)
  [u, n] <- Just (V.toList bv)
  guard (freeOf n x)
  Just (apply sTimes [n, apply sPower [u, apply sPlus [n, Int_ (-1)]], dOf u x])

-- | The chain rule, for any other head @h@:
-- @D[h[g1, …, gn], x]@ is the sum, over each @gi@ that depends on the
-- variable, of @Derivative[0, …, 1, …, 0][h][g1, …, gn] D[gi, x]@. When @h@
-- is itself @Derivative[ns][f]@, the order goes up in place, so
-- @D[f'[x], x]@ is @f''[x]@. The arithmetic heads are the rules above.
--
-- A compound head that depends on the variable adds one more term,
-- @D[h, x][g1, …, gn]@, so @D[f[x][y], x]@ is @f'[x][y]@. A symbol head is
-- a function's name, not an occurrence of the variable, so @D[x[t], x]@ and
-- @D[x[y][z], x]@ are 0 (WL 15.0.1, through the Wolfram Cloud MCP).
chainRule :: Expr -> Maybe Expr
chainRule e = do
  (f, x) <- single e
  App h gs <- Just f
  guard (h `notElem` map Sym [sPlus, sTimes, sPower])
  let n = V.length gs
      term i g = apply sTimes [mkApp (derivativeHead h n i) gs, dOf g x]
      headTerm = [mkApp (dOf h x) gs | isApp h, dependsOn h]
      dependsOn u =
        u == x || case u of
          App hu us -> (isApp hu && dependsOn hu) || any dependsOn us
          _ -> False
      isApp = \case
        App _ _ -> True
        _ -> False
  Just (apply sPlus (headTerm <> [term i g | (i, g) <- zip [0 ..] (V.toList gs), not (freeOf g x)]))

-- | The head of the derivative of @h@ in its @i@th of @n@ arguments.
derivativeHead :: Expr -> Int -> Int -> Expr
derivativeHead h n i = case h of
  App (App (Sym d) ns) (V.toList -> [f])
    | d == sDerivative,
      V.length ns == n,
      Just orders <- traverse order (V.toList ns) ->
        derivative (zipWith (+) orders (unit i)) f
  _ -> derivative (unit i) h
  where
    unit j = [if k == j then 1 else 0 | k <- [0 .. n - 1]]

-- | @Derivative[ns][f]@.
derivative :: [Integer] -> Expr -> Expr
derivative ns f = mkApp (apply sDerivative (map Int_ ns)) (V.singleton f)

-- | A derivative order: a non-negative integer.
order :: Expr -> Maybe Integer
order = \case
  Int_ k | k >= 0 -> Just k
  _ -> Nothing

-- | @Derivative[0, …, 0][f]@ is @f@, and
-- @Derivative[ms][Derivative[ns][f]]@ is @Derivative[ms + ns][f]@.
derivativeOrder :: Expr -> Maybe Expr
derivativeOrder = \case
  App (App (Sym d) ms) (V.toList -> [f])
    | d == sDerivative,
      Just outer <- traverse order (V.toList ms) -> case f of
        _ | all (== 0) outer -> Just f
        App (App (Sym d') ns) (V.toList -> [g])
          | d' == sDerivative,
            V.length ns == V.length ms,
            Just inner <- traverse order (V.toList ns) ->
              Just (derivative (zipWith (+) outer inner) g)
        _ -> Nothing
  _ -> Nothing

-- | @Derivative[ns][f]@, for a pure function @f@ or a symbol with user
-- downvalues, is the pure function its definition differentiates to, as in
-- WL, where @f[x_] := x Cos[x]@ makes @f'@ @Cos[#1] - #1 Sin[#1] &@
-- (@wolfram/Derivative/Scope/1@). A pure function with named parameters
-- keeps them: @Function[x, x^2]'@ is @Function[x, 2 x]@
-- (@wolfram/Function/Scope/ReturnAPureFunctionAsAResult/1@). A number's
-- derivative is @0 &@, and @List@, @Plus@, @Times@ and @Power@, whose
-- derivatives are D's own rules, differentiate too: @List'@ is @{1} &@.
-- Otherwise it
-- applies @f@ to fresh variables and differentiates the result. It does not
-- apply when @f@ applied to them stays as it is, because no definition
-- matched them: the chain rule would then produce @Derivative[ns][f]@
-- again, and this rule would recur on it. Nor when the derivative still
-- mentions @Derivative[ns][f]@ or @D@.
derivativeOfDefinition :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
derivativeOfDefinition e = case e of
  App (App (Sym d) ns) (V.toList -> [App (Sym fn) (V.toList -> ps : body : attrs)])
    | d == sDerivative,
      fn == sFunction,
      Just orders <- traverse order (V.toList ns),
      Just xs <- params ps,
      length xs == length orders -> do
        -- Differentiate in fresh variables, not the parameters themselves,
        -- which may have global values that D's evaluation would read.
        let vars = freshVars (length xs)
            body' = substituteFree Shielding (Map.fromList (zip xs (map BOne vars))) Nothing body
        result <- evaluate (apply sD (body' : [apply sList [v, Int_ k] | (v, k) <- zip vars orders, k > 0]))
        pure $
          if noD result
            then Just (apply sFunction (ps : substituteAll result (zip vars (map Sym xs)) : attrs))
            else Nothing
  App (App (Sym d) ns) (V.toList -> [Num _])
    | d == sDerivative,
      Just _ <- traverse order (V.toList ns) ->
        pure (Just (apply sFunction [Int_ 0]))
  App (App (Sym d) ns) (V.toList -> [f])
    | d == sDerivative,
      Just orders <- traverse order (V.toList ns) ->
        differentiable f >>= \case
          False -> pure Nothing
          True -> do
            let vars = freshVars (length orders)
                applied = mkApp f (V.fromList vars)
            value <- evaluate applied
            if value == applied && not (structural f)
              then pure Nothing
              else do
                result <- evaluate (apply sD (value : [apply sList [v, Int_ k] | (v, k) <- zip vars orders, k > 0]))
                pure $
                  if not (freeOf result e) || not (noD result)
                    then Nothing
                    else Just (apply sFunction [substituteAll result [(v, apply sSlot [Int_ k]) | (v, k) <- zip vars [1 ..]]])
  _ -> pure Nothing
  where
    freshVars n = [Sym (symbol "Cassini`Private`" ("d" <> show k)) | k <- [1 .. n]]
    params = \case
      Sym x | x /= sNull -> Just [x]
      App (Sym l) xs | l == sList -> traverse (\case Sym x -> Just x; _ -> Nothing) (V.toList xs)
      _ -> Nothing
    differentiable = \case
      App (Sym h) _ -> pure (h == sFunction)
      f | structural f -> pure True
      Sym s -> any (\r -> r.ruleOrigin == User) . ruleSetToList . rulesOf DownValue <$> lookupSymbol s
      _ -> pure False
    -- The heads D's own rules differentiate: List' is {1} &, Plus' is 1 &.
    structural = (`elem` map Sym [sList, sPlus, sTimes, sPower])
    -- An unevaluated D means the derivative could not be found.
    noD = \case
      App (Sym h) xs -> h /= sD && all noD xs
      App h xs -> noD h && all noD xs
      _ -> True

-- | Each element with what precedes and follows it.
splits :: [a] -> [([a], a, [a])]
splits = go []
  where
    go _ [] = []
    go before (y : ys) = (reverse before, y, ys) : go (y : before) ys
