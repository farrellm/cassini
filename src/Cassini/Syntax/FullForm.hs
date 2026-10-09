{-# LANGUAGE PatternSynonyms #-}

-- | FullForm, read and printed: @Plus[a, Times[2, b]]@ (DESIGN.md §4.10).
--
-- The canonical machine-readable form, and the golden-file format: printer
-- improvements in "Cassini.Syntax.Pretty" must not invalidate regression
-- cases, so every golden file is FullForm.
--
-- A name without a context resolves through the caller's function; the
-- front end resolves to @System`@ the names the builtin registry defines,
-- and everything else to @Global`@. @Rational[p, q]@ of two integers reads
-- as the number, so printing and reading round-trip. Inexact numbers are not
-- in the system (D9), and a real literal is a parse error saying so.
module Cassini.Syntax.FullForm
  ( parseFullForm,
    fullForm,
    resolveDefault,
  )
where

import Cassini.Core.Expr (Expr, mkApp, mkNumber, pattern App, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Symbol (Symbol, globalSymbol, sRational, symContext, symName, symbol)
import Cassini.Number (Number (NInt, NRat), fromRational')
import Data.Char (isAlphaNum, isLetter)
import Data.Ratio ((%))
import Data.Text qualified as T
import Data.Text.Lazy qualified as TL
import Data.Text.Lazy.Builder qualified as B
import Data.Vector qualified as V
import Text.Megaparsec (Parsec, between, eof, errorBundlePretty, manyTill, notFollowedBy, parse, satisfy, sepBy, takeWhileP, try, (<?>))
import Text.Megaparsec.Char (char, digitChar, space)
import Text.Megaparsec.Char.Lexer qualified as L

-- $setup
-- >>> import Cassini.Core.Symbol (globalSymbol)

type Parser = Parsec Void Text

-- | Resolve every unqualified name to @Global`@.
resolveDefault :: Text -> Symbol
resolveDefault = globalSymbol

-- | Read one FullForm expression, with surrounding whitespace. The function
-- resolves names written without a context.
--
-- >>> fullForm <$> parseFullForm resolveDefault "f[x, -3, Rational[1, 2], \"s\"][y]"
-- Right "f[x, -3, Rational[1, 2], \"s\"][y]"
parseFullForm :: (Text -> Symbol) -> Text -> Either Text Expr
parseFullForm resolve src = first (toText . errorBundlePretty) (parse (space *> expr <* eof) "FullForm" src)
  where
    expr :: Parser Expr
    expr = do
      a <- lexeme atom
      calls <- many (lexeme (between (symbolP '[') (char ']') (lexeme expr `sepBy` symbolP ',')))
      pure (foldl' (\h as -> rational (mkApp h (V.fromList as))) a calls)

    atom = number <|> stringLit <|> symbolLit

    number = do
      sign <- optional (char '-')
      digits <- some digitChar
      notFollowedBy (char '.' <|> char '`' <|> char '*') <?> "an exact number (inexact numbers are absent, D9)"
      let n = readInteger digits
      pure (Int_ (if isJust sign then negate n else n))

    stringLit = Str . toText <$> (char '"' *> manyTill L.charLiteral (char '"'))

    symbolLit = do
      leading <- optional (char '`')
      parts <- namePart `sepBy1'` char '`'
      pure $ case (leading, parts) of
        (Nothing, [n]) -> Sym (resolve n)
        (Just _, _) -> Sym (symbol (T.concat (map (<> "`") ("Global" : init' parts))) (last' parts))
        (Nothing, _) -> Sym (symbol (T.concat (map (<> "`") (init' parts))) (last' parts))

    namePart = do
      c <- satisfy (\x -> isLetter x || x == '$')
      rest <- takeWhileP (Just "name") (\x -> isAlphaNum x || x == '$')
      pure (T.cons c rest)

    sepBy1' p s = (:) <$> p <*> many (try (s *> p))
    lexeme p = p <* space
    symbolP c = lexeme (char c)

    -- Rational[p, q] of two integers is the number.
    rational e = case e of
      App (Sym r) as | r == sRational, [Int_ p, Int_ q] <- V.toList as, q /= 0 -> mkNumber (fromRational' (p % q))
      _ -> e

    readInteger = foldl' (\acc d -> acc * 10 + toInteger (ord d - ord '0')) 0

    init' xs = take (length xs - 1) xs
    last' xs = fromMaybe "" (viaNonEmpty last xs)

-- | Print as FullForm. Symbols in @System`@ and @Global`@ print bare;
-- any other context prints in full.
--
-- >>> fullForm (Sym (globalSymbol "x"))
-- "x"
fullForm :: Expr -> Text
fullForm = TL.toStrict . B.toLazyText . go
  where
    go = \case
      Num (NInt i) -> B.fromString (show i)
      Num (NRat r) -> "Rational[" <> B.fromString (show (numerator r)) <> ", " <> B.fromString (show (denominator r)) <> "]"
      Str t -> B.fromText (quote t)
      Sym s
        | s.symContext `elem` ["System`", "Global`"] -> B.fromText s.symName
        | otherwise -> B.fromText s.symContext <> B.fromText s.symName
      App h as -> go h <> "[" <> mconcat (intersperse ", " (map go (V.toList as))) <> "]"
    quote t = "\"" <> T.concatMap escape t <> "\""
    escape = \case
      '"' -> "\\\""
      '\\' -> "\\\\"
      '\n' -> "\\n"
      '\t' -> "\\t"
      c -> T.singleton c
