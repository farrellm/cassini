{-# LANGUAGE PatternSynonyms #-}

-- | The infix surface syntax, read into 'Expr' (DESIGN.md §4.10).
--
-- A precedence-climbing (Pratt) parser over 'operators', the precedence
-- table, which is data, in one place: "Cassini.Syntax.Pretty" prints from
-- the same table, so the two cannot disagree about how @a /. b -> c@
-- parses, and §7.3's round-trip property checks that they do not.
--
-- The precedences are WL's (@Precedence@), and the parse is WL's as
-- Mathics3 reproduces it, with two departures that let every expression be
-- printed in a form that reads back as itself:
--
-- * An integer literal divided by a positive integer literal is the
--   rational number: @1/2@ reads as @Rational[1, 2]@, not
--   @Times[1, Power[2, -1]]@, just as FullForm's @Rational[1, 2]@ reads as
--   the number. The two differ only where evaluation is held.
-- * Negating a product whose first factor is a positive number negates that
--   number:
--   @a - 2 b@ reads as @Plus[a, Times[-2, b]]@, not
--   @Plus[a, Times[-1, 2, b]]@, which is again what evaluation gives.
--
-- A product written with operators is flattened into the product around
-- it, as WL's parser does, so @-a b@ is @Times[-1, a, b]@ and @a b/c@ is
-- @Times[a, b, Power[c, -1]]@; one written in parentheses is not, so
-- @(a b) c@ is @Times[Times[a, b], c]@. A name without a context resolves
-- through the caller's function, as in "Cassini.Syntax.FullForm".
--
-- The Stage 1 subset: numbers, strings, symbols with contexts, @f[…]@,
-- @{…}@, @a[[i]]@, arithmetic and comparison, @=@ @:=@ @^=@ @^:=@ @=.@ @/:@,
-- @->@ @:>@, @/.@ @//.@, @/;@, @?@, @|@, @..@, blanks with names, heads and
-- @.@, @x:p@ and @p:v@, @&@ and slots, @\@@ @//@ @~f~@ @\@\@@ @\@\@\@@ @/\@@, @'@,
-- @!@ (both), @&&@ @||@, @<>@, @::@, @++@ @--@ @+=@ and their kin, @%@,
-- and @;@. Not: @Span@, @Dot@, string patterns, boxes, associations,
-- named characters, and inexact numbers (D9), each a parse error.
module Cassini.Syntax.Parser
  ( -- * Parsing
    parseExpr,
    parseExprs,
    incomplete,

    -- * The precedence table
    Operator (..),
    Fixity (..),
    operators,
    precedence,
  )
where

import Cassini.Core.Expr (Expr, apply, mkApp, mkNumber, pattern App, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Symbol (Symbol, qualifiedName, sBlank, sBlankNullSequence, sBlankSequence, sDerivative, sList, sNull, sOptional, sPattern, sPlus, sPower, sSlot, sSlotSequence, sTimes, symbol)
import Cassini.Number (Number (NInt, NRat), fromRational')
import Cassini.Syntax.Lexer
import Data.Ratio ((%))
import Data.Text qualified as T
import Data.Vector qualified as V
import Text.Megaparsec (eof, errorBundlePretty, lookAhead, parse, sepBy, try, (<?>))
import Text.Megaparsec qualified as M
import Text.Megaparsec.Char (char, string)

-- | How an operator stands to its operands.
data Fixity
  = -- | @a op b op c@ is one application, @h[a, b, c]@.
    InfixFlat
  | InfixLeft
  | InfixRight
  | Prefix
  | Postfix
  deriving stock (Eq, Show)

-- | One operator: its token, its precedence (WL's @Precedence@), its
-- fixity, and the head it builds when it builds one generically ('Nothing'
-- where the parse is particular, as @-@, @/@ and @\@@ are).
data Operator = Operator
  { opToken :: !Text,
    opPrecedence :: !Int,
    opFixity :: !Fixity,
    opHead :: !(Maybe Text)
  }
  deriving stock (Show)

-- | The precedence table. @&&@ is given 217 against @||@'s 215 so that it
-- binds tighter, as WL's parser has it, though WL's @Precedence@ reports
-- 215 for both.
operators :: [Operator]
operators =
  [ Operator ";" 10 InfixFlat (Just "CompoundExpression"),
    Operator "=" 40 InfixRight (Just "Set"),
    Operator ":=" 40 InfixRight (Just "SetDelayed"),
    Operator "^=" 40 InfixRight (Just "UpSet"),
    Operator "^:=" 40 InfixRight (Just "UpSetDelayed"),
    Operator "/:" 40 InfixRight Nothing,
    Operator "=." 670 Postfix (Just "Unset"),
    Operator "//" 70 InfixLeft Nothing,
    Operator "&" 90 Postfix (Just "Function"),
    Operator "+=" 100 InfixRight (Just "AddTo"),
    Operator "-=" 100 InfixRight (Just "SubtractFrom"),
    Operator "*=" 100 InfixRight (Just "TimesBy"),
    Operator "/=" 100 InfixRight (Just "DivideBy"),
    Operator "/." 110 InfixLeft (Just "ReplaceAll"),
    Operator "//." 110 InfixLeft (Just "ReplaceRepeated"),
    Operator "->" 120 InfixRight (Just "Rule"),
    Operator ":>" 120 InfixRight (Just "RuleDelayed"),
    Operator "/;" 130 InfixLeft (Just "Condition"),
    Operator ":" 140 InfixLeft (Just "Optional"),
    Operator ":" 150 InfixLeft (Just "Pattern"),
    Operator "|" 160 InfixFlat (Just "Alternatives"),
    Operator ".." 170 Postfix (Just "Repeated"),
    Operator "..." 170 Postfix (Just "RepeatedNull"),
    Operator "||" 215 InfixFlat (Just "Or"),
    Operator "&&" 217 InfixFlat (Just "And"),
    Operator "!" 230 Prefix (Just "Not"),
    Operator "==" 290 InfixFlat (Just "Equal"),
    Operator "!=" 290 InfixFlat (Just "Unequal"),
    Operator "<" 290 InfixFlat (Just "Less"),
    Operator ">" 290 InfixFlat (Just "Greater"),
    Operator "<=" 290 InfixFlat (Just "LessEqual"),
    Operator ">=" 290 InfixFlat (Just "GreaterEqual"),
    Operator "===" 290 InfixFlat (Just "SameQ"),
    Operator "=!=" 290 InfixFlat (Just "UnsameQ"),
    Operator "+" 310 InfixFlat (Just "Plus"),
    Operator "-" 310 InfixLeft Nothing,
    Operator "+" 480 Prefix Nothing,
    Operator "*" 400 InfixFlat (Just "Times"),
    Operator "/" 470 InfixLeft Nothing,
    Operator "-" 480 Prefix Nothing,
    Operator "^" 590 InfixRight (Just "Power"),
    Operator "<>" 600 InfixFlat (Just "StringJoin"),
    Operator "!" 610 Postfix (Just "Factorial"),
    Operator "@@" 620 InfixRight (Just "Apply"),
    Operator "/@" 620 InfixRight (Just "Map"),
    Operator "//@" 620 InfixRight (Just "MapAll"),
    Operator "@@@" 620 InfixRight Nothing,
    Operator "~" 630 InfixLeft Nothing,
    Operator "@" 640 InfixRight Nothing,
    Operator "++" 660 Postfix (Just "Increment"),
    Operator "--" 660 Postfix (Just "Decrement"),
    Operator "++" 660 Prefix (Just "PreIncrement"),
    Operator "--" 660 Prefix (Just "PreDecrement"),
    Operator "'" 670 Postfix Nothing,
    Operator "?" 680 InfixLeft (Just "PatternTest"),
    Operator "::" 750 InfixLeft (Just "MessageName")
  ]

-- | An operator's precedence by token and fixity; 0 for none.
precedence :: Text -> Fixity -> Int
precedence t f = maybe 0 (.opPrecedence) (find (\o -> o.opToken == t && sameSide o.opFixity) operators)
  where
    sameSide g = case (f, g) of
      (Prefix, Prefix) -> True
      (Postfix, Postfix) -> True
      (Prefix, _) -> False
      (_, Prefix) -> False
      (Postfix, _) -> False
      (_, Postfix) -> False
      _ -> True

-- | An operand as the grammar built it. A product written with operators
-- ('Written') is spliced into the product around it; an integer written as
-- digits ('Literal'), with or without a minus, divides into a rational
-- number.
data Origin = Plain | Written | Literal
  deriving stock (Eq)

data Term = Term {tExpr :: !Expr, tOrigin :: !Origin}

plain :: Expr -> Term
plain e = Term e Plain

-- | Read one expression, with surrounding whitespace and comments. The
-- function resolves names written without a context.
--
-- >>> import Cassini.Syntax.FullForm (fullForm, resolveDefault)
-- >>> fullForm <$> parseExpr resolveDefault "f[x_] := a x^2 - 1/2 /; x > 0"
-- Right "SetDelayed[f[Pattern[x, Blank[]]], Condition[Plus[Times[a, Power[x, 2]], Rational[-1, 2]], Greater[x, 0]]]"
parseExpr :: (Text -> Symbol) -> Text -> Either Text Expr
parseExpr resolve src = first (toText . errorBundlePretty) (parse (space *> (tExpr <$> expr resolve 0) <* eof) "input" src)

-- | Read a sequence of expressions separated by commas, as the arguments of
-- a call: what a file of definitions joined by @;@ is not, but what a
-- list of test cases is.
parseExprs :: (Text -> Symbol) -> Text -> Either Text [Expr]
parseExprs resolve src = first (toText . errorBundlePretty) (parse (space *> (map tExpr <$> (expr resolve 0 `sepBy` symbolTok ",")) <* eof) "input" src)

-- | Whether the input failed only because it ended too soon: an unclosed
-- bracket, or an operator still waiting for its operand. The interactive
-- loop then reads another line.
incomplete :: (Text -> Symbol) -> Text -> Bool
incomplete resolve src = case parse (space *> expr resolve 0 *> eof) "input" src of
  Left bundle -> all ((>= T.length src) . M.errorOffset) (M.bundleErrors bundle) && not (T.null (T.strip src))
  Right _ -> False

-- | An expression whose operators all bind tighter than @rbp@.
expr :: (Text -> Symbol) -> Int -> Parser Term
expr resolve = go
  where
    go rbp = prefix >>= loop rbp

    loop rbp left =
      optional (lookAhead (infixOrPostfix left)) >>= \case
        Just (lbp, act) | lbp > rbp -> act >>= loop rbp
        _ -> pure left

    -- The operator after an operand, its binding power, and what it does.
    -- Juxtaposition is multiplication.
    infixOrPostfix :: Term -> Parser (Int, Parser Term)
    infixOrPostfix left =
      (try (string "[[") $> (1000, part left))
        <|> (char '[' $> (1000, call left))
        <|> (operatorTok >>= \t -> pure (operatorAfter left t))
        <|> (startsAtom $> (400, times left))

    -- One of these operator tokens, or nothing consumed.
    opIs ts = try (operatorTok >>= \t -> if t `elem` ts then pure t else fail ("expected " <> toString (T.intercalate " or " ts)))

    -- What an operator token does after an operand. Consumes the token.
    operatorAfter :: Term -> Text -> (Int, Parser Term)
    operatorAfter left t = case t of
      ";" -> (10, compound left)
      "+" -> (310, plusChain left)
      "-" -> (310, plusChain left)
      "*" -> (400, times left)
      "/" -> (470, operatorTok *> (divide left <$> go 470))
      "^" -> (590, operatorTok *> (binary "Power" left <$> go 589))
      "//" -> (70, operatorTok *> ((\f -> plain (mkApp f.tExpr (V.singleton left.tExpr))) <$> go 70))
      "@" -> (640, operatorTok *> ((\x -> plain (mkApp left.tExpr (V.singleton x.tExpr))) <$> go 639))
      "~" -> (630, operatorTok *> infixCall left)
      -- f @@@ x is Apply[f, x, {1}], as Mathics3 reads it (and WL did
      -- before MapApply).
      "@@@" -> (620, operatorTok *> ((\x -> plain (sys "Apply" [left.tExpr, x.tExpr, apply sList [Int_ 1]])) <$> go 619))
      "'" -> (670, derivative left)
      "/:" -> (40, operatorTok *> tagSet left)
      ":" -> case left.tExpr of
        Sym _ -> (150, operatorTok *> (binary "Pattern" left <$> go 150))
        _ -> (140, operatorTok *> (binary "Optional" left <$> go 140))
      "::" -> (750, operatorTok *> ((\n -> plain (sys "MessageName" [left.tExpr, Str (nameText n)])) <$> lexeme nameTok))
      _ | t `elem` comparisons -> (290, comparison left)
      _ -> case find (\o -> o.opToken == t && o.opFixity /= Prefix) operators of
        Just (Operator _ p fx (Just h)) -> case fx of
          InfixFlat -> (p, flat h t left)
          InfixLeft -> (p, operatorTok *> (binary h left <$> go p))
          InfixRight -> (p, operatorTok *> (binary h left <$> go (p - 1)))
          Postfix -> (p, operatorTok $> plain (sys h [left.tExpr]))
          Prefix -> (0, empty)
        _ -> (0, fail ("the operator " <> toString t <> " is not in the Stage 1 syntax"))

    -- An operand: an atom, a bracketed expression, or a prefix operator.
    prefix :: Parser Term
    prefix =
      (Term . Int_ <$> integerTok <*> pure Literal)
        <|> (plain . Str <$> stringTok)
        <|> nameOrPattern
        <|> (plain <$> blankExpr Nothing)
        <|> (plain . slot <$> slotTok)
        <|> (plain . out <$> outTok)
        <|> (plain . (.tExpr) <$> (symbolTok "(" *> go 0 <* symbolTok ")"))
        <|> (plain . apply sList <$> (symbolTok "{" *> arguments <* symbolTok "}"))
        <|> prefixOperator
        <?> "an expression"

    prefixOperator =
      operatorTok >>= \case
        "-" -> negateTerm <$> go 480
        "+" -> go 480
        "!" -> plain . sys "Not" . pure . (.tExpr) <$> go 230
        "++" -> plain . sys "PreIncrement" . pure . (.tExpr) <$> go 660
        "--" -> plain . sys "PreDecrement" . pure . (.tExpr) <$> go 660
        t -> fail ("the operator " <> toString t <> " needs an operand before it")

    nameOrPattern = do
      n <- nameTok
      let s = Sym (resolveName n)
      optional (blankExpr (Just s)) >>= \case
        Just p -> pure (plain p)
        Nothing -> plain s <$ space

    -- A blank, named or not: @x_@, @x__h@, @_.@.
    blankExpr named = do
      b <- blankTok
      let kind = case b.blankCount of
            1 -> Just sBlank
            2 -> Just sBlankSequence
            3 -> Just sBlankNullSequence
            _ -> Nothing
      k <- maybe (fail "a blank has one to three underscores") pure kind
      let blank = apply k (maybeToList (Sym . resolveName <$> b.blankHead))
          pat = maybe blank (\x -> apply sPattern [x, blank]) named
      pure (if b.blankOptional then apply sOptional [pat] else pat)

    slot = \case
      SlotOne n -> apply sSlot [Int_ n]
      SlotRun n -> apply sSlotSequence [Int_ n]

    out = \case
      Left 1 -> sys "Out" []
      Left k -> sys "Out" [Int_ (negate (toInteger k))]
      Right n -> sys "Out" [Int_ n]

    -- Arguments separated by commas; an empty one is @Null@.
    arguments = do
      args <- optional (go 0) `sepBy` symbolTok ","
      pure $ case args of
        [Nothing] -> []
        _ -> map (maybe (Sym sNull) (.tExpr)) args

    call left = do
      _ <- symbolTok "["
      as <- arguments
      _ <- symbolTok "]"
      pure (plain (mkApp left.tExpr (V.fromList as)))

    part left = do
      _ <- lexeme (string "[[")
      as <- arguments
      _ <- symbolTok "]" *> symbolTok "]"
      pure (plain (sys "Part" (left.tExpr : as)))

    -- @a ~f~ b@ is @f[a, b]@.
    infixCall left = do
      f <- go 630
      _ <- opIs ["~"]
      b <- go 630
      pure (plain (mkApp f.tExpr (V.fromList [left.tExpr, b.tExpr])))

    -- @f'@ is @Derivative[1][f]@, @f''@ @Derivative[2][f]@.
    derivative left = do
      primes <- some (opIs ["'"])
      pure (plain (mkApp (apply sDerivative [Int_ (toInteger (length primes))]) (V.singleton left.tExpr)))

    -- @f /: lhs = rhs@ and @f /: lhs := rhs@.
    tagSet left = do
      lhs <- go 40
      op <- operatorTok
      h <- case op of
        "=" -> pure "TagSet"
        ":=" -> pure "TagSetDelayed"
        _ -> fail "expected = or := after f /: lhs"
      rhs <- go 39
      pure (plain (sys h [left.tExpr, lhs.tExpr, rhs.tExpr]))

    -- @a; b; c@, and a trailing @;@ is followed by @Null@.
    compound left = do
      rest <- some $ do
        _ <- opIs [";"]
        optional (go 10)
      pure (plain (sys "CompoundExpression" (left.tExpr : map (maybe (Sym sNull) (.tExpr)) rest)))

    -- A sum: each @+ t@ adds @t@ and each @- t@ its negation.
    plusChain left = do
      rest <- some $ do
        op <- opIs ["+", "-"]
        t <- go 310
        pure (if op == "-" then (negateTerm t).tExpr else t.tExpr)
      pure (plain (apply sPlus (left.tExpr : rest)))

    -- A product: @*@ or juxtaposition, each operand at Times's precedence,
    -- products written with operators spliced in.
    times left = do
      rest <- some $ do
        void (opIs ["*"]) <|> startsAtom
        go 400
      pure (Term (apply sTimes (concatMap factors (left : rest))) Written)

    flat h t left = do
      rest <- some (opIs [t] *> go (precedence t InfixFlat))
      pure (plain (sys h (map (.tExpr) (left : rest))))

    binary h left right = plain (sys h [left.tExpr, right.tExpr])

    -- A chain of comparisons: all one operator is that head over every
    -- operand; mixed, it is @Inequality[a, op, b, op, c, …]@.
    comparison left = do
      rest <- some $ do
        op <- opIs comparisons
        (op,) <$> go 290
      let ops = ordNub (map fst rest)
      pure . plain $ case ops of
        [op] -> sys (headOf op) (left.tExpr : map ((.tExpr) . snd) rest)
        _ -> sys "Inequality" (left.tExpr : concat [[sys0 (headOf op), t.tExpr] | (op, t) <- rest])
      where
        headOf op = maybe "" (fromMaybe "" . (.opHead)) (find (\o -> o.opToken == op) operators)

    resolveName (Name relative ctxs base) = qualifiedName resolve relative ctxs base

    sys h = apply (symbol "System`" h)
    sys0 h = Sym (symbol "System`" h)

    comparisons = ["==", "!=", "<", ">", "<=", ">=", "===", "=!="]

    nameText (Name _ ctxs base) = T.intercalate "`" (ctxs <> [base])

-- | The factors a product operand contributes: its own factors when it is
-- a product written with operators, else itself.
factors :: Term -> [Expr]
factors t = case (t.tOrigin, t.tExpr) of
  (Written, App (Sym h) as) | h == sTimes -> V.toList as
  _ -> [t.tExpr]

-- | @-t@: a number negated, a product written with operators with its
-- leading number negated if it is positive or @-1@ put in front if not, and
-- anything else times @-1@. So @a - 2 b@ is @Plus[a, Times[-2, b]]@, and
-- @- -a@ is WL's @Times[-1, -1, a]@.
negateTerm :: Term -> Term
negateTerm t = case t.tExpr of
  Num n -> Term (mkNumber (negateNumber n)) t.tOrigin
  App (Sym h) as
    | t.tOrigin == Written,
      h == sTimes -> case V.toList as of
        Num n : rest | positive n -> Term (apply sTimes (mkNumber (negateNumber n) : rest)) Written
        xs -> Term (apply sTimes (Int_ (-1) : xs)) Written
  e -> Term (apply sTimes [Int_ (-1), e]) Written
  where
    negateNumber = \case
      NInt i -> NInt (negate i)
      NRat r -> fromRational' (negate r)
    positive = \case
      NInt i -> i > 0
      NRat r -> r > 0

-- | @n / d@: the rational number when both are integer literals and @d@ is
-- positive, else @Times[n, Power[d, -1]]@, a product written with
-- operators.
divide :: Term -> Term -> Term
divide n d = case (n, d) of
  (Term (Int_ p) Literal, Term (Int_ q) Literal) | q > 0 -> Term (mkNumber (fromRational' (p % q))) Plain
  _ -> Term (apply sTimes (factors n <> [apply sPower [d.tExpr, Int_ (-1)]])) Written
