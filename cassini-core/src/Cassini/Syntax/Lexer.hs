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
    stringLiteral,
    quoteString,
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

import Cassini.Core.Symbol (isNameChar, isNameStart)
import Data.Char (digitToInt, isAlphaNum, isDigit, isHexDigit, isOctDigit)
import Data.Text qualified as T
import Numeric (showHex)
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

-- | A string literal, with WL's escapes, and the whitespace after it.
stringTok :: Parser Text
stringTok = lexeme stringLiteral <?> "a string"

-- | A string literal, quotes included, with WL's escapes: @\\\"@, @\\\\@,
-- @\\b@, @\\f@, @\\n@, @\\r@, @\\t@; exactly three octal digits, @\\101@;
-- @\\.hh@, @\\:hhhh@ and @\\|hhhhhh@ in hexadecimal. @\\'@ is the two
-- characters as written. Any other escape is an error, as in WL
-- (@Syntax::stresc@), and so are the ones Stage 1 does not have: named
-- characters, @\\[Alpha]@ (D36), and the box escapes @\\\<@, @\\\>@, @\\!@,
-- @\\&@ and their kin. These are WL 15.0.1's readings, evaluated through the
-- Wolfram Cloud MCP. "Cassini.Syntax.FullForm" reads strings with it too.
stringLiteral :: Parser Text
stringLiteral = T.concat <$> (char '"' *> manyTill piece (char '"'))
  where
    piece = (char '\\' *> escape) <|> takeWhile1P (Just "a character") (`notElem` ['"', '\\'])
    escape =
      choice
        [ T.singleton <$> choice [c <$ char e | (e, c) <- simple],
          "\\'" <$ char '\'',
          code 8 3 "3 octal digits are required after \\ to construct an 8-bit character" (pure ()),
          code 16 2 "2 hexadecimal digits are required after \\. to construct an 8-bit character" (void (char '.')),
          code 16 4 "4 hexadecimal digits are required after \\: to construct a 16-bit character" (void (char ':')),
          code 16 6 "6 hexadecimal digits are required after \\| to construct a character" (void (char '|')),
          char '[' *> fail "named characters (\\[Name]) are not in the Stage 1 syntax (D36)",
          satisfy (`elem` ("<>!&*@^%`+_/=," :: String)) *> fail "box escapes are not in the Stage 1 syntax",
          satisfy (const True) >>= \c -> fail ("unknown string escape \\" <> [c])
        ]
    simple = [('"', '"'), ('\\', '\\'), ('b', '\b'), ('f', '\f'), ('n', '\n'), ('r', '\r'), ('t', '\t')]
    code :: Int -> Int -> String -> Parser () -> Parser Text
    code base n err lead =
      try lead *> do
        ds <- takeWhileP (Just "a digit") (isDigitIn base)
        when (T.length ds < n) (fail err)
        let (here, rest) = T.splitAt n ds
            value = T.foldl' (\acc d -> acc * base + digitToInt d) 0 here
        when (value > ord maxBound) (fail "the character code is beyond Unicode")
        pure (T.cons (chr value) rest)
    isDigitIn base c = if base == 8 then isOctDigit c else isHexDigit c

-- | A string as a literal 'stringLiteral' reads back: quotes and
-- backslashes escaped, and the control characters as their escapes.
quoteString :: Text -> Text
quoteString t = "\"" <> T.concatMap escape t <> "\""
  where
    escape = \case
      '"' -> "\\\""
      '\\' -> "\\\\"
      '\b' -> "\\b"
      '\f' -> "\\f"
      '\n' -> "\\n"
      '\r' -> "\\r"
      '\t' -> "\\t"
      c
        | c < ' ' || c == '\DEL' -> "\\." <> T.justifyRight 2 '0' (toText (showHex (ord c) ""))
        | otherwise -> T.singleton c

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
    part = T.cons <$> satisfy isNameStart <*> takeWhileP (Just "name") isNameChar

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
