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
rewriteM :: (Monad m) => (Expr -> m (Maybe Expr)) -> Expr -> m Expr
rewriteM f = go
  where
    go e = do
      e' <- embed <$> traverse go (project e)
      f e' >>= maybe (pure e') go
