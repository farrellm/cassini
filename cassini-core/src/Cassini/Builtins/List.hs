{-# LANGUAGE PatternSynonyms #-}

-- | List construction and manipulation (DESIGN.md §2.2, D44): the first set,
-- chosen by measured corpus scope — @Flatten@, @Partition@, @Array@,
-- @ReplacePart@, @Range@, @MapAt@, @Extract@, @Take@, @Drop@, @Thread@,
-- @MapThread@, @Position@, @MapIndexed@, @Riffle@, @Select@, @Sort@ — and
-- the basics they are used with: @First@, @Last@, @Rest@, @Most@, @Join@,
-- @Append@, @Prepend@, @Reverse@. @Table@ is §4.13's iterator, in
-- "Cassini.Builtins.Control".
--
-- Each works on any head where WL's does (@Rest[f[a, b]]@ is @f[b]@), and
-- leaves a call it cannot carry out unevaluated, with WL's message where
-- the corpus shows one. Positions are WL's: 1-based, negative from the end,
-- 0 the head.
module Cassini.Builtins.List (definitions) where

import Cassini.Attributes (Attribute (..))
import Cassini.Builtins.Define (Definition, args, define, down, inLevel, isList, levelSpec, message, sTrueE)
import Cassini.Core.Expr (Expr, apply, mkApp, mkNumber, pattern App, pattern Call, pattern Int_, pattern Num, pattern Sym)
import Cassini.Core.Order (compareCanonical)
import Cassini.Core.Symbol (sList, sRule, sRuleDelayed, systemSymbol)
import Cassini.Eval.Kernel (Kernel, evaluate)
import Cassini.Number (fromRational', toRational')
import Cassini.Pattern.Match (matchOne)
import Data.Vector qualified as V
import Effectful (Eff, (:>))

-- | The list builtins, with WL's attributes.
definitions :: [Definition]
definitions =
  [ define "First" [Protected] [down (end "First" "nofirst" V.head)],
    define "Last" [Protected] [down (end "Last" "nolast" V.last)],
    define "Rest" [Protected] [down (shorten "Rest" "norest" V.tail)],
    define "Most" [Protected] [down (shorten "Most" "nomost" V.init)],
    define "Join" [Flat, OneIdentity, Protected] [down joinRule],
    define "Append" [Protected] [down (add (flip V.snoc))],
    define "Prepend" [Protected] [down (add V.cons)],
    define "Reverse" [Protected] [down reverseRule],
    define "Range" [Listable, Protected] [down rangeRule],
    define "Take" [NHoldRest, Protected] [down (sequenceSpec "Take" True)],
    define "Drop" [NHoldRest, Protected] [down (sequenceSpec "Drop" False)],
    define "Flatten" [Protected] [down flattenRule],
    define "Partition" [Protected] [down partitionRule],
    define "Array" [Protected] [down arrayRule],
    define "ReplacePart" [Protected] [down replacePartRule],
    define "MapAt" [Protected] [down mapAtRule],
    define "Extract" [NHoldRest, Protected] [down extractRule],
    define "Thread" [Protected] [down threadRule],
    define "MapThread" [Protected] [down mapThreadRule],
    define "Position" [Protected] [down positionRule],
    define "MapIndexed" [Protected] [down mapIndexedRule],
    define "Riffle" [Protected] [down riffleRule],
    define "Select" [Protected] [down selectRule],
    define "Sort" [Protected] [down sortRule]
  ]

-- | The arguments of an expression, if it is not an atom.
partsOf :: Expr -> Maybe (Expr, V.Vector Expr)
partsOf = \case
  App h as -> Just (h, as)
  _ -> Nothing

-- | A list of expressions.
list :: [Expr] -> Expr
list = apply sList

-- | @First@ and @Last@: the part at that end; an expression with none stays,
-- with @First::nofirst@ (@Last::nolast@).
end :: (Kernel :> es) => Text -> Text -> (V.Vector Expr -> Expr) -> Expr -> Eff es (Maybe Expr)
end name tag pick e = case args e of
  [x] | Just (_, as) <- partsOf x -> if V.null as then Nothing <$ message name tag [x] else pure (Just (pick as))
  [x] -> Nothing <$ message name tag [x]
  _ -> pure Nothing

-- | @Rest@ and @Most@: the expression without that end, head kept; one
-- with no parts stays, with @Rest::norest@ (@Most::nomost@).
shorten :: (Kernel :> es) => Text -> Text -> (V.Vector Expr -> V.Vector Expr) -> Expr -> Eff es (Maybe Expr)
shorten name tag cut e = case args e of
  [x] | Just (h, as) <- partsOf x, not (V.null as) -> pure (Just (mkApp h (cut as)))
  [x] -> Nothing <$ message name tag [x]
  _ -> pure Nothing

-- | @Join[l₁, l₂, …]@: the parts of expressions with one head, in order.
-- @Join[]@ is @{}@; heads that differ stay, with @Join::heads@.
joinRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
joinRule e = case traverse partsOf (args e) of
  Just [] -> pure (Just (list []))
  Just ps@((h, _) : _)
    | all ((== h) . fst) ps -> pure (Just (mkApp h (V.concat (map snd ps))))
    | otherwise -> Nothing <$ message "Join" "heads" [h, e]
  Nothing -> pure Nothing

-- | @Append[expr, x]@ and @Prepend[expr, x]@.
add :: (Expr -> V.Vector Expr -> V.Vector Expr) -> Expr -> Eff es (Maybe Expr)
add f e = pure $ case args e of
  [x, y] | Just (h, as) <- partsOf x -> Just (mkApp h (f y as))
  _ -> Nothing

-- | @Reverse[expr]@: its parts in reverse order.
reverseRule :: Expr -> Eff es (Maybe Expr)
reverseRule e = pure $ case args e of
  [x] | Just (h, as) <- partsOf x -> Just (mkApp h (V.reverse as))
  _ -> Nothing

-- | @Range[n]@, @Range[a, b]@ and @Range[a, b, d]@ over rationals.
rangeRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
rangeRule e = case traverse rational (args e) of
  Just [n] -> pure (Just (steps 1 n 1))
  Just [a, b] -> pure (Just (steps a b 1))
  Just [_, _, 0] -> Nothing <$ message "Range" "range" [e]
  Just [a, b, d] -> pure (Just (steps a b d))
  _ -> pure Nothing
  where
    steps a b d =
      let k = floor ((b - a) / d) :: Integer
       in list [number (a + fromInteger i * d) | i <- [0 .. k]]

rational :: Expr -> Maybe Rational
rational = \case
  Num n -> Just (toRational' n)
  _ -> Nothing

number :: Rational -> Expr
number = mkNumber . fromRational'

-- | A sequence specification of @Take@ and @Drop@: @n@ (the first @n@, or the
-- last @-n@), @{m}@, @{m, n}@, @{m, n, s}@, @All@ or @None@, as 0-based
-- positions into @k@ parts; 'Nothing' when out of range.
spanOf :: Int -> Expr -> Maybe [Int]
spanOf k = \case
  Int_ n
    | n >= 0, n <= toInteger k -> Just [0 .. fromInteger n - 1]
    | n < 0, negate n <= toInteger k -> Just [k + fromInteger n .. k - 1]
  Call l [m] | l == sList -> (: []) <$> index m
  Call l [m, n] | l == sList -> (\i j -> [i .. j]) <$> index m <*> index n
  Call l [m, n, Int_ s]
    | l == sList,
      s /= 0 -> do
        i <- index m
        j <- index n
        Just [i, i + fromInteger s .. j]
  Sym a | a == systemSymbol "All" -> Just [0 .. k - 1]
  Sym a | a == systemSymbol "None" -> Just []
  _ -> Nothing
  where
    index = \case
      Int_ i
        | i >= 1, i <= toInteger k -> Just (fromInteger i - 1)
        | i < 0, negate i <= toInteger k -> Just (k + fromInteger i)
      _ -> Nothing

-- | @Take[expr, spec, …]@ and @Drop[expr, spec, …]@: the parts the
-- specification names, or all but them, one specification per level. Out
-- of range is @Take::take@ (@Drop::drop@), and the call stays.
sequenceSpec :: (Kernel :> es) => Text -> Bool -> Expr -> Eff es (Maybe Expr)
sequenceSpec name keep e = case args e of
  x : specs@(_ : _) -> case go x specs of
    Just r -> pure (Just r)
    Nothing -> Nothing <$ message name (if keep then "take" else "drop") [e]
  _ -> pure Nothing
  where
    go x = \case
      [] -> Just x
      spec : rest -> do
        (h, as) <- partsOf x
        is <- spanOf (V.length as) spec
        let chosen = if keep then is else [i | i <- [0 .. V.length as - 1], i `notElem` is]
        ys <- traverse ((as V.!?) >=> (`go` rest)) chosen
        Just (mkApp h (V.fromList ys))

-- | @Flatten[expr]@, @Flatten[expr, n]@ and @Flatten[expr, n, h]@: parts
-- with the expression's head (or @h@) spliced into it, to depth @n@.
flattenRule :: Expr -> Eff es (Maybe Expr)
flattenRule e = pure $ case args e of
  [x] | Just (h, _) <- partsOf x -> Just (flat h (Nothing :: Maybe Integer) x)
  [x, n] | Just (h, _) <- partsOf x, Just d <- depth n -> Just (flat h d x)
  [x, n, h] | Just d <- depth n -> Just (flat h d x)
  _ -> Nothing
  where
    depth = \case
      Int_ n | n >= 0 -> Just (Just n)
      Call d [Int_ 1] | d == systemSymbol "DirectedInfinity" -> Just Nothing
      _ -> Nothing
    flat h d x = case partsOf x of
      Just (hx, as) -> mkApp hx (V.concatMap (splice h d) as)
      Nothing -> x
    splice h d a = case partsOf a of
      Just (ha, bs) | ha == h, d /= Just 0 -> V.concatMap (splice h (subtract 1 <$> d)) bs
      _ -> V.singleton a

-- | @Partition[list, n]@ and @Partition[list, n, d]@: runs of @n@ parts at
-- offsets @d@ apart (@n@ by default), incomplete runs dropped.
partitionRule :: Expr -> Eff es (Maybe Expr)
partitionRule e = pure $ case args e of
  [x, Int_ n] -> go x n n
  [x, Int_ n, Int_ d] -> go x n d
  _ -> Nothing
  where
    go x n d
      | n <= 0 || d <= 0 = Nothing
      | Just (h, as) <- partsOf x =
          let k = V.length as
              n' = fromInteger n
              starts = takeWhile (\i -> i + n' <= k) [0, fromInteger d ..]
           in Just (mkApp h (V.fromList [mkApp h (V.slice i n' as) | i <- starts]))
      | otherwise = Nothing

-- | @Array[f, n]@ is @{f[1], …, f[n]}@; @Array[f, {n, m, …}]@ nests;
-- @Array[f, n, r]@ starts from @r@.
arrayRule :: Expr -> Eff es (Maybe Expr)
arrayRule e = pure $ case args e of
  [f, dims] -> build f 1 <$> sizes dims
  [f, dims, Int_ r] -> build f r <$> sizes dims
  _ -> Nothing
  where
    sizes = \case
      Int_ n | n >= 0 -> Just [n]
      Call l ns | l == sList -> traverse (\case Int_ n | n >= 0 -> Just n; _ -> Nothing) ns
      _ -> Nothing
    build f r ns = go ns []
      where
        go [] idx = mkApp f (V.fromList (map Int_ (reverse idx)))
        go (n : rest) idx = list [go rest (i : idx) | i <- [r .. r + n - 1]]

-- | A position: @i@ or @{i, j, …}@.
position :: Expr -> Maybe [Integer]
position = \case
  Int_ i -> Just [i]
  Call l is | l == sList -> traverse (\case Int_ i -> Just i; _ -> Nothing) is
  _ -> Nothing

-- | Several positions: one position, or a list of them @{{i, …}, …}@.
positions :: Expr -> Maybe [[Integer]]
positions = \case
  Call l ps@(Call l' _ : _) | l == sList, l' == sList -> traverse position ps
  p -> pure <$> position p

-- | The part at a position, if it exists.
partAt :: [Integer] -> Expr -> Maybe Expr
partAt = \case
  [] -> Just
  i : rest -> \x -> case partsOf x of
    Just (h, as)
      | i == 0 -> partAt rest h
      | otherwise -> index as i >>= partAt rest
    Nothing -> Nothing
  where
    index as i
      | i > 0 = as V.!? (fromInteger i - 1)
      | otherwise = as V.!? (V.length as + fromInteger i)

-- | Change the part at a position, if it exists.
modifyAt :: (Expr -> Expr) -> [Integer] -> Expr -> Maybe Expr
modifyAt f = \case
  [] -> Just . f
  i : rest -> \x -> case partsOf x of
    Just (h, as)
      | i == 0 -> (`mkApp` as) <$> modifyAt f rest h
      | otherwise -> do
          let k = if i > 0 then fromInteger i - 1 else V.length as + fromInteger i
          a <- as V.!? k
          a' <- modifyAt f rest a
          Just (mkApp h (as V.// [(k, a')]))
    Nothing -> Nothing

-- | @ReplacePart[expr, pos -> new]@, or a list of such rules: each part
-- replaced, @:>@'s right-hand side as written. A position that does not
-- exist is skipped, as WL skips it.
replacePartRule :: Expr -> Eff es (Maybe Expr)
replacePartRule e = pure $ case args e of
  [x, Call l rs] | l == sList, Just rules <- traverse rule rs -> Just (foldl' apply1 x rules)
  [x, r] | Just ru <- rule r -> Just (apply1 x ru)
  _ -> Nothing
  where
    rule = \case
      Call r [p, v] | r == sRule || r == sRuleDelayed -> (,v) <$> positions p
      _ -> Nothing
    apply1 x (ps, v) = foldl' (\acc p -> fromMaybe acc (modifyAt (const v) p acc)) x ps

-- | @MapAt[f, expr, pos]@: @f@ applied to the part at each position given.
-- A position that does not exist leaves the call, with @MapAt::partw@.
mapAtRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
mapAtRule e = case args e of
  [f, x, p] | Just ps <- positions p -> case foldlM (flip (modifyAt (mkApp f . V.singleton))) x ps of
    Just r -> pure (Just r)
    Nothing -> Nothing <$ message "MapAt" "partw" [p, x]
  _ -> pure Nothing

-- | @Extract[expr, pos]@, @Extract[expr, {pos, …}]@ and
-- @Extract[expr, pos, h]@, which wraps each part in @h@ before evaluating.
extractRule :: Expr -> Eff es (Maybe Expr)
extractRule e = case args e of
  [x, p] -> pure (pick x p id)
  [x, p, h] -> pure (pick x p (mkApp h . V.singleton))
  _ -> pure Nothing
  where
    pick x p wrap = case p of
      Call l ps@(Call l' _ : _) | l == sList, l' == sList -> list <$> traverse (position >=> (fmap wrap . (`partAt` x))) ps
      _ -> position p >>= fmap wrap . (`partAt` x)

-- | @Thread[f[args]]@: @f@ threaded over the lists among its arguments, which
-- must have one length; other arguments are repeated. @Thread[expr, h]@
-- threads over parts with head @h@ instead.
threadRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
threadRule e = case args e of
  [x] -> thread x (Sym sList)
  [x, h] -> thread x h
  _ -> pure Nothing
  where
    thread x h = case partsOf x of
      Just (f, as) -> case ordNub [V.length bs | a <- V.toList as, Just (h', bs) <- [partsOf a], h' == h] of
        [] -> pure (Just x)
        [k] -> pure (Just (mkApp h (V.fromList [mkApp f (V.map (nth h i) as) | i <- [0 .. k - 1]])))
        _ -> Nothing <$ message "Thread" "tdlen" [x]
      Nothing -> pure (Just x)
    nth h i a = case partsOf a of
      Just (h', bs) | h' == h, Just b <- bs V.!? i -> b
      _ -> a

-- | @MapThread[f, {{a₁, a₂, …}, {b₁, b₂, …}, …}]@ is
-- @{f[a₁, b₁, …], f[a₂, b₂, …], …}@; lists of different lengths stay, with
-- @MapThread::mptc@.
mapThreadRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
mapThreadRule e = case args e of
  [f, Call l ls]
    | l == sList,
      all isList ls -> case ordNub (map (length . args) ls) of
        [] -> pure (Just (list []))
        [k] -> pure (Just (list [mkApp f (V.fromList [a | x <- ls, Just a <- [V.fromList (args x) V.!? i]]) | i <- [0 .. k - 1]]))
        _ -> Nothing <$ message "MapThread" "mptc" [e]
  _ -> pure Nothing

-- | @Position[expr, pattern]@: the positions of the parts that match, heads
-- included, each part's after the parts inside it, as @Level@ orders them;
-- @Position[expr, pattern, levelspec]@ only at those levels.
positionRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
positionRule e = case args e of
  [x, p] -> Just <$> found p (\_ _ -> True) x
  [x, p, spec] | Just ls <- levelSpec spec -> Just <$> found p (inLevel ls) x
  _ -> pure Nothing
  where
    found p keep x = list . map (list . map Int_) <$> go p keep (0 :: Integer) [] x
    go p keep lvl path x = do
      (inner, d) <- case partsOf x of
        Just (h, as) -> do
          hs <- go p keep (lvl + 1) (0 : path) h
          rs <- forM (zip [1 ..] (V.toList as)) $ \(i, a) -> go p keep (lvl + 1) (i : path) a
          pure (hs <> concat rs, 1 + foldl' max 0 (map depthOf (V.toList as)))
        Nothing -> pure ([], 1)
      here <- if keep lvl d then isJust <$> matchOne p x else pure False
      pure (inner <> [reverse path | here])
    depthOf a = case partsOf a of
      Just (_, as) -> 1 + foldl' max 0 (map depthOf (V.toList as))
      Nothing -> 1 :: Integer

-- | @MapIndexed[f, expr]@: @f[part, {i}]@ for each part at level 1.
mapIndexedRule :: Expr -> Eff es (Maybe Expr)
mapIndexedRule e = pure $ case args e of
  [f, x] | Just (h, as) <- partsOf x -> Just (mkApp h (V.imap (\i a -> mkApp f (V.fromList [a, list [Int_ (toInteger i + 1)]])) as))
  _ -> Nothing

-- | @Riffle[{a, b, c}, x]@ is @{a, x, b, x, c}@; with a list of separators
-- the same length as the list, or one shorter, they alternate.
riffleRule :: Expr -> Eff es (Maybe Expr)
riffleRule e = pure $ case args e of
  [x, y] | Just (h, as) <- partsOf x -> case y of
    Call l ys
      | l == sList,
        length ys == V.length as || length ys + 1 == V.length as ->
          Just (mkApp h (V.fromList (interleave (V.toList as) ys)))
    _ -> Just (mkApp h (V.fromList (intersperse' y (V.toList as))))
  _ -> Nothing
  where
    interleave (a : as) (b : bs) = a : b : interleave as bs
    interleave as [] = as
    interleave [] bs = bs
    intersperse' s = \case
      a : rest@(_ : _) -> a : s : intersperse' s rest
      as -> as

-- | @Select[list, crit]@: the parts for which @crit[part]@ is @True@, head
-- kept; @Select[list, crit, n]@, at most the first @n@.
selectRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
selectRule e = case args e of
  [x, crit] | Just (h, as) <- partsOf x -> Just . mkApp h . V.fromList <$> go crit maxBound (V.toList as)
  [x, crit, Int_ n] | Just (h, as) <- partsOf x -> Just . mkApp h . V.fromList <$> go crit (fromInteger n) (V.toList as)
  _ -> pure Nothing
  where
    go :: (Kernel :> es) => Expr -> Int -> [Expr] -> Eff es [Expr]
    go crit n = \case
      a : rest | n > 0 -> do
        ok <- evaluate (mkApp crit (V.singleton a))
        if ok == sTrueE then (a :) <$> go crit (n - 1) rest else go crit n rest
      _ -> pure []

-- | @Sort[list]@ in canonical order, the order @Orderless@ sorts by
-- (§3.5); @Sort[list, p]@ puts @a@ before @b@ when @p[a, b]@ is @True@, by
-- a stable merge sort.
sortRule :: (Kernel :> es) => Expr -> Eff es (Maybe Expr)
sortRule e = case args e of
  [x] | Just (h, as) <- partsOf x -> pure (Just (mkApp h (V.fromList (sortBy compareCanonical (V.toList as)))))
  [x, p] | Just (h, as) <- partsOf x -> Just . mkApp h . V.fromList <$> mergeSort p (V.toList as)
  _ -> pure Nothing
  where
    mergeSort p = \case
      [] -> pure []
      [a] -> pure [a]
      xs -> do
        let (l, r) = splitAt (length xs `div` 2) xs
        l' <- mergeSort p l
        r' <- mergeSort p r
        merge p l' r'
    merge p l r = case (l, r) of
      ([], _) -> pure r
      (_, []) -> pure l
      (a : as, b : bs) -> do
        -- b goes first only when it must: p[b, a] is True and p[a, b] not.
        ba <- evaluate (mkApp p (V.fromList [b, a]))
        ab <- if ba == sTrueE then evaluate (mkApp p (V.fromList [a, b])) else pure sTrueE
        if ba == sTrueE && ab /= sTrueE then (b :) <$> merge p l bs else (a :) <$> merge p as r
