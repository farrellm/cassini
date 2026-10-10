{-# LANGUAGE PatternSynonyms #-}

-- | Matching the arguments of an @Orderless@ head (DESIGN.md §4.5.3, step 3,
-- and §4.5.4).
--
-- Source: @references/papers/pattern-matching/krebber2017_ac_matching_thesis.pdf@
-- §3.3, §3.3.1 (the five matching steps, in their order) and §3.3.2 (each
-- distribution of the subject multiset over the sequence variables once).
--
-- The subject's arguments are a multiset, and the pattern's are matched in
-- Krebber's order, cheapest first, so the expensive steps face what is left:
--
-- 1. constant patterns, removed by equality;
-- 2. variables already bound, their bindings removed as multisets;
-- 3. the other single-argument patterns, each tried against every subject
--    with its head, the submatches chained, so that a binding one makes
--    constrains the next, and step 2 repeated after each;
-- 4. regular variables, one subject each;
-- 5. sequence variables, and everything else that takes a run, each given a
--    sub-multiset of what remains.
--
-- Every step stays in the monad and none commits to a first submatch: a
-- step that did would leave the later steps nothing to backtrack into
-- (§4.5.4's @{g[x_], x_, y_}@ example). Equal subjects are interchangeable,
-- so of several equal subjects only the first is tried for a pattern, and a
-- sub-multiset is chosen by how many of each value it takes: each distinct
-- mapping is enumerated once, never once per permutation.
module Cassini.Pattern.Commutative (matchCommutative) where

import Cassini.Core.Expr (Expr, exprHead, pattern App)
import Cassini.Core.Symbol (Symbol)
import Cassini.Pattern
  ( Binding (..),
    MatchOps,
    PatternView (..),
    Subst,
    argRange,
    prefersLong,
  )
import Cassini.Pattern.Sequence (ArgContext (..), matchRun)
import Data.List (partition)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V

-- | Which step matches a pattern argument.
data Step = Constant | NonVariable | Regular | Run
  deriving stock (Eq)

-- | A pattern argument: its 1-based position (for @Optional@'s default),
-- the pattern, and its step.
data Element = Element
  { elPos :: !Int,
    elPattern :: !PatternView,
    elStep :: !Step
  }

-- | Match a pattern's arguments against an @Orderless@ subject's, every way
-- they match, each distinct mapping once. The flag turns steps 1 and 2 on;
-- off, constants are matched as step 3 matches and bound variables as
-- unbound ones are, which is correct and slower, and is there to measure
-- what the two steps prune (§8.3).
matchCommutative :: (MonadPlus m) => Bool -> MatchOps m -> ArgContext -> V.Vector PatternView -> V.Vector Expr -> Subst -> m Subst
matchCommutative prune ops ctx ps ss sigma0 = do
  remaining <- if prune then removeConstants constants subjects else pure subjects
  solve remaining others sigma0
  where
    arity = V.length ps
    subjects = zip [0 :: Int ..] (V.toList ss)
    elements = zipWith classify [1 ..] (V.toList ps)
    (constants, others)
      | prune = partition ((== Constant) . (.elStep)) elements
      | otherwise = ([], [e {elStep = if e.elStep == Constant then NonVariable else e.elStep} | e <- elements])

    classify i p = Element i p $ case argRange ctx.acFlat p of
      (1, Just 1)
        | PLiteral _ <- p -> Constant
        | PVerbatim _ <- p -> Constant
        | isVariable p -> Regular
        | otherwise -> NonVariable
      _ -> Run

    -- Step 1: each constant takes an equal subject, or nothing matches.
    removeConstants cs rest = case cs of
      [] -> pure rest
      Element _ p _ : cs' -> case p of
        PLiteral e -> maybe empty (removeConstants cs') (removeValue e rest)
        PVerbatim e -> maybe empty (removeConstants cs') (removeValue e rest)
        _ -> empty

    solve rest pending sigma = case boundElement sigma pending of
      -- Step 2, and its repetition after every binding.
      Just (el, b, pending') -> do
        let vs = unrun b
        rest' <- maybe empty pure (foldlM (flip removeValue) rest vs)
        (sigma', _) <- matchRun ops ctx el.elPos arity el.elPattern (V.fromList vs) sigma
        solve rest' pending' sigma'
      Nothing -> do
        guard (fits pending (length rest))
        case pickNext pending of
          Nothing -> sigma <$ guard (null rest)
          Just (el, pending')
            | el.elStep == Run -> runStep el pending' rest sigma
            | otherwise -> asum [one el pending' (i, s) rest sigma | (i, s) <- distinctFirst rest, headFits el.elPattern s]

    -- Steps 3 and 4: one subject.
    one el pending' (i, s) rest sigma = do
      (sigma', _) <- matchRun ops ctx el.elPos arity el.elPattern (V.singleton s) sigma
      solve (filter ((/= i) . fst) rest) pending' sigma'

    -- Step 5: a sub-multiset of what remains, shortest first.
    runStep el pending' rest sigma = do
      let (lo, hi) = argRange ctx.acFlat el.elPattern
          (restLo, restHi) = totals pending'
          avail = length rest
          longest = maybe id min hi (avail - restLo)
          shortest = max lo (maybe 0 (avail -) restHi)
          sizes = if prefersLong el.elPattern then [longest, longest - 1 .. shortest] else [shortest .. longest]
      asum
        [ do
            (sigma', _) <- matchRun ops ctx el.elPos arity el.elPattern (V.fromList (map snd chosen)) sigma
            solve (filter ((`notElem` map fst chosen) . fst) rest) pending' sigma'
        | k <- sizes,
          chosen <- sortOn fst <$> combinations k (groups rest)
        ]

    -- The first pending element whose name is bound, with its binding: only
    -- when steps 1 and 2 are on.
    boundElement sigma pending
      | not prune = Nothing
      | otherwise = case break (isJust . boundIn sigma) pending of
          (before, el : after) | Just b <- boundIn sigma el -> Just (el, b, before <> after)
          _ -> Nothing
    boundIn sigma el = nameOf el.elPattern >>= (`Map.lookup` sigma)

    -- Step 3 before step 4 before step 5; in pattern order within a step.
    pickNext pending =
      asum [takeFirst ((== st) . (.elStep)) pending | st <- [NonVariable, Regular, Run]]

    -- What the remaining patterns take, at least and at most.
    totals = foldl' (\(lo, hi) el -> let (l, h) = argRange ctx.acFlat el.elPattern in (lo + l, (+) <$> hi <*> h)) (0, Just 0)
    fits pending k = let (lo, hi) = totals pending in lo <= k && maybe True (k <=) hi

    -- A binding as the run of subjects it stands for: a sequence's
    -- elements, and under a Flat head, the head's arguments.
    unrun = \case
      BSeq xs -> V.toList xs
      BOne (App h as) | ctx.acFlat, h == ctx.acHead -> V.toList as
      BOne v -> [v]

    -- Step 3 groups by head: a compound pattern with a literal head is tried
    -- only against subjects with that head.
    headFits p s = case core p of
      PCompound (PLiteral h) _ -> exprHead s == h
      _ -> True

-- | A pattern seen through its side conditions and @HoldPattern@.
core :: PatternView -> PatternView
core = \case
  PCondition q _ -> core q
  PTest q _ -> core q
  PHold q -> core q
  p -> p

-- | Whether a pattern is a variable, named or not: a blank.
isVariable :: PatternView -> Bool
isVariable p = case core p of
  PBlank _ -> True
  PNamed _ q -> isVariable q
  _ -> False

-- | The name a pattern binds as a whole, if any.
nameOf :: PatternView -> Maybe Symbol
nameOf p = case core p of
  PNamed x _ -> Just x
  _ -> Nothing

-- | Remove one subject equal to the value, the first.
removeValue :: Expr -> [(Int, Expr)] -> Maybe [(Int, Expr)]
removeValue v rest = case break ((== v) . snd) rest of
  (before, _ : after) -> Just (before <> after)
  _ -> Nothing

-- | The subjects not equal to an earlier one.
distinctFirst :: [(Int, Expr)] -> [(Int, Expr)]
distinctFirst = go []
  where
    go seen = \case
      [] -> []
      x@(_, s) : xs
        | s `elem` seen -> go seen xs
        | otherwise -> x : go (s : seen) xs

-- | The subjects grouped by value, in order of first occurrence.
groups :: [(Int, Expr)] -> [[(Int, Expr)]]
groups = \case
  [] -> []
  x@(_, s) : xs -> let (same, other) = partition ((== s) . snd) xs in (x : same) : groups other

-- | Every sub-multiset of size @k@, each once, in lexicographic order: as
-- many of the first value as possible first.
combinations :: Int -> [[a]] -> [[a]]
combinations 0 _ = [[]]
combinations _ [] = []
combinations k (g : gs) =
  [take t g <> c | t <- [min k (length g), min k (length g) - 1 .. 0], c <- combinations (k - t) gs]

-- | The first element satisfying the predicate, and the rest in order.
takeFirst :: (a -> Bool) -> [a] -> Maybe (a, [a])
takeFirst f xs = case break f xs of
  (before, x : after) -> Just (x, before <> after)
  _ -> Nothing
