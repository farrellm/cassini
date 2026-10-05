{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ViewPatterns #-}

-- | The 'Expr' API: smart constructors, pattern synonyms and accessors
-- (DESIGN.md §3.3). The representation is in "Cassini.Core.Expr.Internal" and
-- is not exported past @Cassini.Core.*@.
--
-- Match with the synonyms, which are @COMPLETE@:
--
-- > case e of
-- >   Num n -> ...
-- >   Str t -> ...
-- >   Sym s -> ...
-- >   App h args -> ...
--
-- and build through them or the @mk*@ functions, which compute the hash and
-- consult the intern table. That is the point: the interning decision (§3.4)
-- lives in four constructors, not at every call site.
module Cassini.Core.Expr
  ( Expr,
    pattern Num,
    pattern Str,
    pattern Sym,
    pattern App,
    pattern Int_,
    pattern Rat_,
    mkNumber,
    mkString,
    mkSymbol,
    mkApp,
    apply,
    exprHead,
    exprArgs,
    exprArity,
  )
where

import Cassini.Core.Expr.Internal (Expr (exprShape), Shape (..))
import Cassini.Core.Intern (intern)
import Cassini.Core.Symbol (Symbol, systemSymbol)
import Cassini.Number (Number (NInt, NRat))
import Data.Vector qualified as V

-- | A number.
pattern Num :: Number -> Expr
pattern Num n <- (exprShape -> SNumber n)
  where
    Num n = mkNumber n

-- | A string.
pattern Str :: Text -> Expr
pattern Str t <- (exprShape -> SString t)
  where
    Str t = mkString t

-- | A symbol.
pattern Sym :: Symbol -> Expr
pattern Sym s <- (exprShape -> SSymbol s)
  where
    Sym s = mkSymbol s

-- | An application: head and arguments.
pattern App :: Expr -> V.Vector Expr -> Expr
pattern App h as <- (exprShape -> SApp h as)
  where
    App h as = mkApp h as

{-# COMPLETE Num, Str, Sym, App #-}

-- | An integer.
pattern Int_ :: Integer -> Expr
pattern Int_ i <- (exprShape -> SNumber (NInt i))
  where
    Int_ i = mkNumber (NInt i)

-- | A fraction that is not an integer. Match-only: build fractions with
-- 'mkNumber' and 'Cassini.Number.fromRational'', which normalizes.
pattern Rat_ :: Rational -> Expr
pattern Rat_ r <- (exprShape -> SNumber (NRat r))

-- | A number node.
mkNumber :: Number -> Expr
mkNumber = intern . SNumber

-- | A string node.
mkString :: Text -> Expr
mkString = intern . SString

-- | A symbol node.
mkSymbol :: Symbol -> Expr
mkSymbol = intern . SSymbol

-- | An application node.
mkApp :: Expr -> V.Vector Expr -> Expr
mkApp h as = intern (SApp h as)

-- | @apply f xs@ is @f[xs]@ with a symbol head.
apply :: Symbol -> [Expr] -> Expr
apply f xs = mkApp (mkSymbol f) (V.fromList xs)

-- | The head, as WL's @Head@ gives it: an application's head, or for an atom
-- the symbol naming its type (@Integer@, @Rational@, @String@, @Symbol@).
exprHead :: Expr -> Expr
exprHead = \case
  Int_ _ -> mkSymbol (systemSymbol "Integer")
  Num _ -> mkSymbol (systemSymbol "Rational")
  Str _ -> mkSymbol (systemSymbol "String")
  Sym _ -> mkSymbol (systemSymbol "Symbol")
  App h _ -> h

-- | An application's arguments; empty for an atom.
exprArgs :: Expr -> V.Vector Expr
exprArgs = \case
  App _ as -> as
  _ -> V.empty

-- | The number of arguments; 0 for an atom.
exprArity :: Expr -> Int
exprArity = V.length . exprArgs
