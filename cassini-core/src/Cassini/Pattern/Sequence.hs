{-# LANGUAGE PatternSynonyms #-}

-- | Matching an argument list whose patterns take runs of arguments
-- (DESIGN.md §4.5.3, step 2): @__@, @___@, @Repeated@, @Optional@, and any
-- blank under a @Flat@ head.
--
-- Source: @references/papers/pattern-matching/krebber2017_ac_matching_thesis.pdf@
-- §3.2 (Algorithm 3.2's distribution of subject arguments over the pattern's,
-- with its pruning on the remaining patterns' minimum lengths).
--
-- The pattern arguments are matched left to right. Each takes a run of the
-- subject's arguments, as a 'V.slice', so a candidate distribution copies
-- nothing; the run's length is bounded by what the patterns after it need at
-- least and can take at most. Shorter runs are tried first, as WL's @__@
-- does, except for @Optional@, which matches an argument when it can.
--
-- 'matchRun' matches one pattern element against one run, and is shared with
-- "Cassini.Pattern.Commutative", which chooses runs as sub-multisets instead.
module Cassini.Pattern.Sequence
  ( ArgContext (..),
    matchArgs,
    matchRun,
  )
where

import Cassini.Core.Expr (Expr, exprHead, mkApp, pattern App, pattern Sym)
import Cassini.Pattern
  ( Binding (..),
    MatchOps (..),
    PatternView (..),
    Subst,
    applySubst,
    argRange,
    bindName,
    builtinDefault,
    isTrue,
    prefersLong,
  )
import Data.List (zip4)
import Data.Vector qualified as V

-- | What matching an argument list needs to know of the subject's head: the
-- head itself, to group a @Flat@ run under it, and the two attributes that
-- change what one pattern argument may take.
data ArgContext = ArgContext
  { acHead :: !Expr,
    acFlat :: !Bool,
    acOneIdentity :: !Bool
  }

-- | Match a pattern's arguments against a subject's, every way they match,
-- in WL's order: earlier patterns take shorter runs first.
matchArgs :: (MonadPlus m) => MatchOps m -> ArgContext -> V.Vector PatternView -> V.Vector Expr -> Subst -> m Subst
matchArgs ops ctx ps ss = go elements 0
  where
    m = V.length ps
    n = V.length ss
    ranges = map (argRange ctx.acFlat) (V.toList ps)
    -- Each pattern with its position, its range, and what the patterns
    -- after it take at least and at most.
    elements = zip4 [1 ..] (V.toList ps) ranges (drop 1 (scanr restOf (0, Just 0) ranges))
    restOf (lo, hi) (accLo, accHi) = (lo + accLo, (+) <$> hi <*> accHi)
    go es start sigma = case es of
      [] -> sigma <$ guard (start == n)
      (i, p, (lo, hi), (restLo, restHi)) : rest -> do
        let avail = n - start
            longest = maybe id min hi (avail - restLo)
            shortest = max lo (maybe 0 (avail -) restHi)
            lengths = if prefersLong p then [longest, longest - 1 .. shortest] else [shortest .. longest]
        asum
          [ matchRun ops ctx i m p (V.slice start k ss) sigma >>= \(sigma', _) -> go rest (start + k) sigma'
          | k <- lengths
          ]

-- | Match one pattern element against a run of arguments, giving the
-- extended substitution and what the element binds: one expression, or the
-- run as a sequence. The position (1-based) and the number of pattern
-- arguments locate a built-in default for @Optional@.
matchRun :: (MonadPlus m) => MatchOps m -> ArgContext -> Int -> Int -> PatternView -> V.Vector Expr -> Subst -> m (Subst, Binding)
matchRun ops ctx pos arity = run
  where
    run p xs sigma = do
      let (lo, hi) = argRange ctx.acFlat p
          k = V.length xs
      guard (k >= lo && maybe True (k <=) hi)
      case p of
        PNamed x q -> do
          (sigma', b) <- run q xs sigma
          (,b) <$> bindName x b sigma'
        -- Only True admits a match; the test sees the run's bindings.
        PCondition q test -> do
          r@(sigma', _) <- run q xs sigma
          decided <- ops.evalM (applySubst sigma' test)
          r <$ guard (isTrue decided)
        -- On a run, the test applies to each argument of it.
        PTest q f -> do
          r@(_, b) <- run q xs sigma
          r <$ forM_ (values b) (\v -> ops.evalM (App f (V.singleton v)) >>= guard . isTrue)
        PHold q -> run q xs sigma
        PAlternative qs -> asum [run q xs sigma | q <- qs]
        PBlankSeq c -> (sigma, BSeq xs) <$ guard (all (headMatches c) xs)
        PBlankNull c -> (sigma, BSeq xs) <$ guard (all (headMatches c) xs)
        PBlank c | ctx.acFlat -> flatBlank c xs sigma
        PRepeated q _ -> (,BSeq xs) <$> V.foldM (flip (ops.recur q)) sigma xs
        POptional q d
          | k == 0 -> case d <|> defaultHere of
              Just v -> (,BOne v) <$> run' q v sigma
              Nothing -> empty
          | otherwise -> run q xs sigma
        PExcept c (Just q) | k /= 1 -> do
          excluded <- or <$> mapM (\a -> ops.matchesM c a sigma) (V.toList xs)
          guard (not excluded)
          run q xs sigma
        _ -> case V.toList xs of
          [a] -> (,BOne a) <$> ops.recur p a sigma
          _ -> empty
    -- A default stands for one argument.
    run' q v = fmap fst . run q (V.singleton v)
    defaultHere = case ctx.acHead of
      Sym f -> builtinDefault f pos arity
      _ -> Nothing
    -- A blank under a Flat head: a longer run is the head over the run. One
    -- argument is the argument itself, tried after the head over it unless
    -- the head has OneIdentity, which makes f[a] and a the same to matching.
    flatBlank c xs sigma
      | V.length xs == 1 =
          asum [(sigma, BOne v) <$ guard (headMatches c v) | v <- [grouped | not ctx.acOneIdentity] <> V.toList xs]
      | otherwise = (sigma, BOne grouped) <$ guard (headMatches c grouped)
      where
        grouped = mkApp ctx.acHead xs
    values = \case
      BOne v -> [v]
      BSeq vs -> V.toList vs

headMatches :: Maybe Expr -> Expr -> Bool
headMatches c x = maybe True (== exprHead x) c
