-- | The tokens of the surface syntax (DESIGN.md §4.10), as @megaparsec@
-- parsers over 'Text' that "Cassini.Syntax.Parser" composes.
--
-- Each token parser consumes the whitespace and comments after it, so the
-- grammar never mentions whitespace. A comment is WL's @(* … *)@, which
-- nests. Operators are read longest first, so @//.@ is never @//@ then @.@,
-- and @!=@ is never @!@ then @=@.
module Cassini.Syntax.Lexer
  ( Parser,
    space,
    lexeme,
    symbolTok,
    operatorTok,
    operatorTokens,
    integerTok,
    stringTok,
    nameTok,
    Name (..),
    BlankTok (..),
    blankTok,
    slotTok,
    Slot (..),
    outTok,
    startsAtom,
  )
where

import Data.Char (isAlphaNum, isDigit, isLetter)
import Data.Text qualified as T
import Text.Megaparsec (Parsec, choice, lookAhead, manyTill, notFollowedBy, satisfy, takeWhile1P, takeWhileP, try, (<?>))
import Text.Megaparsec.Char (char, space1, string)
import Text.Megaparsec.Char.Lexer qualified as L

-- | The parser type of the surface syntax.
type Parser = Parsec Void Text

-- | Whitespace and comments.
space :: Parser ()
space = L.space space1 empty comment
  where
    comment = string "(*" *> body
    body = void (manyTill (comment <|> void (satisfy (const True))) (string "*)"))

-- | A token, with the whitespace after it.
lexeme :: Parser a -> Parser a
lexeme = L.lexeme space

-- | A fixed piece of punctuation: a bracket, a brace, a comma.
symbolTok :: Text -> Parser Text
symbolTok = L.symbol space

-- | Every operator token, longest first, so that a prefix of a longer
-- operator is never read in its place.
operatorTokens :: [Text]
operatorTokens =
  sortOn
    (negate . T.length)
    [ ";",
      "=",
      ":=",
      "^=",
      "^:=",
      "=.",
      "/:",
      "//",
      "&",
      "/.",
      "//.",
      "->",
      ":>",
      "/;",
      ":",
      "|",
      "..",
      "...",
      "||",
      "&&",
      "!",
      "==",
      "!=",
      "<",
      ">",
      "<=",
      ">=",
      "===",
      "=!=",
      "+",
      "-",
      "*",
      "/",
      "^",
      "<>",
      "@@",
      "/@",
      "@",
      "~",
      "'",
      "?",
      "++",
      "--",
      "+=",
      "-=",
      "*=",
      "/=",
      "::",
      ";;",
      "@@@",
      "//@"
    ]

-- | One operator token, longest match. @..@ is not read where it would split
-- a number, and @.@ alone is not an operator here (@Dot@ is not in the
-- Stage 1 subset).
operatorTok :: Parser Text
operatorTok = lexeme (choice [try (string t) | t <- operatorTokens]) <?> "an operator"

-- | A non-negative integer literal. A real is refused, since inexact numbers
-- are absent (D9): @1.5@, @1.@, @1`@ and @1*^3@ are errors, while @1..@ is
-- @Repeated[1]@.
integerTok :: Parser Integer
integerTok = lexeme $ do
  digits <- takeWhile1P (Just "digit") isDigit
  notFollowedBy (real <|> void (char '`') <|> void (string "*^") <|> void (string "^^")) <?> "an exact number (inexact numbers are absent, D9)"
  pure (T.foldl' (\acc d -> acc * 10 + toInteger (ord d - ord '0')) 0 digits)
  where
    real = try (char '.' *> notFollowedBy (char '.'))

-- | A string literal, with WL's escapes.
stringTok :: Parser Text
stringTok = lexeme (toText <$> (char '"' *> manyTill L.charLiteral (char '"'))) <?> "a string"

-- | A name as written: its context parts and its last part. @a`b`c@ is
-- @Name False ["a", "b"] "c"@, and a leading backquote, @`c@, marks a
-- context relative to @Global`@.
data Name = Name
  { nameRelative :: !Bool,
    nameContexts :: ![Text],
    nameBase :: !Text
  }
  deriving stock (Eq, Show)

-- | A name, without the whitespace after it: a pattern may follow it
-- directly (@x_@).
nameTok :: Parser Name
nameTok = do
  relative <- isJust <$> optional (char '`')
  first' <- part
  rest <- many (try (char '`' *> part))
  let parts = first' : rest
  pure (Name relative (take (length parts - 1) parts) (fromMaybe first' (viaNonEmpty last parts)))
  where
    part = T.cons <$> satisfy (\c -> isLetter c || c == '$') <*> takeWhileP (Just "name") (\c -> isAlphaNum c || c == '$')

-- | A blank as written: how many underscores, the head name after them, and
-- whether a @.@ makes it optional (@x_.@).
data BlankTok = BlankTok
  { blankCount :: !Int,
    blankHead :: !(Maybe Name),
    blankOptional :: !Bool
  }

-- | The blank part of a pattern, @_@, @__h@, @___@ or @_.@, with the
-- whitespace after it.
blankTok :: Parser BlankTok
blankTok = lexeme $ do
  n <- T.length <$> takeWhile1P (Just "_") (== '_')
  h <- optional nameTok
  opt <- isJust <$> optional (try (char '.' *> notFollowedBy (char '.')))
  pure (BlankTok n h opt)

-- | A slot: @#n@ (@#@ is @#1@), or @##n@ (@##@ is @##1@).
data Slot = SlotOne !Integer | SlotRun !Integer

-- | A slot.
slotTok :: Parser Slot
slotTok = lexeme $ do
  _ <- char '#'
  run <- isJust <$> optional (char '#')
  n <- optional (T.foldl' (\acc d -> acc * 10 + toInteger (ord d - ord '0')) 0 <$> takeWhile1P (Just "digit") isDigit)
  pure (if run then SlotRun (fromMaybe 1 n) else SlotOne (fromMaybe 1 n))

-- | @%@ (the last output, 'Just' 1 back), @%%…@ (@k@ back), or @%n@
-- (output @n@): 'Left' a count back, 'Right' a number.
outTok :: Parser (Either Int Integer)
outTok = lexeme $ do
  k <- T.length <$> takeWhile1P (Just "%") (== '%')
  n <- optional (T.foldl' (\acc d -> acc * 10 + toInteger (ord d - ord '0')) 0 <$> takeWhile1P (Just "digit") isDigit)
  pure (maybe (Left k) Right n)

-- | Whether what follows starts an operand that juxtaposition would
-- multiply: a number, a name, a string, a blank, a slot, an output, an
-- opening parenthesis or brace. Not an operator, so @a -b@ is a
-- difference and @a !b@ is not a product.
startsAtom :: Parser ()
startsAtom = void (lookAhead (satisfy (\c -> isAlphaNum c || c `elem` ("$`\"_#%({" :: String))))
