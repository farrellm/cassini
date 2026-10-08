-- | The base functor of 'Expr', its @recursion-schemes@ instances, and
-- 'rewriteM' (DESIGN.md §3.6).
--
-- Both instances are written out, and 'embed' rebuilds through the smart
-- constructors, so every @cata@, @ana@ and @para@ maintains the cached hash and
-- the intern id. They are defined with the type in
-- "Cassini.Core.Expr.Internal", to avoid orphans, and are in scope wherever
-- 'Expr' is.
module Cassini.Core.Traversal
  ( ExprF (..),
    rewriteM,
  )
where

import Cassini.Core.Expr (Expr)
import Cassini.Core.Expr.Internal (ExprF (..))
import Data.Functor.Foldable (Corecursive (embed), Recursive (project))

-- | Rewrite bottom-up until no rule applies anywhere: children first, then the
-- node, and a rewritten node is rewritten again from its children.
--
-- Direct recursion over 'project' and 'embed', because the step is monadic:
-- the callers that want this are the ones whose rewrite step evaluates (§4.3).
--
-- Subtrees in which nothing is rewritten are returned as they are, not
-- rebuilt, as in "Cassini.Structure"'s substitutions.
rewriteM :: (Monad m) => (Expr -> m (Maybe Expr)) -> Expr -> m Expr
rewriteM f e0 = fromMaybe e0 <$> go e0
  where
    -- 'Nothing' means unchanged, so unchanged subtrees keep their nodes.
    go e = do
      children <- traverse (\c -> (c,) <$> go c) (project e)
      let rebuilt
            | all (isNothing . snd) children = Nothing
            | otherwise = Just (embed (uncurry fromMaybe <$> children))
          e' = fromMaybe e rebuilt
      f e' >>= \case
        Nothing -> pure rebuilt
        Just r -> Just . fromMaybe r <$> go r
