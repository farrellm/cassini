{-# LANGUAGE PatternSynonyms #-}

-- | Infix output with precedence-driven parenthesization, and message
-- formatting (DESIGN.md §4.10).
--
-- The printer reads "Cassini.Syntax.Parser"'s precedence table, and what it
-- prints reads back as the expression it printed: @parseExpr (pretty e)@ is
-- @Right e@ for every @e@ (§7.3). So it prints an operator form only where
-- the parser would build exactly that expression from it, and the bracket
-- form @h[…]@ everywhere else: @Times[a, Power[b, -1]]@ prints as @a/b@,
-- but @Times[3, Power[2, -1]]@ as @3 2^-1@, since @3/2@ reads as the number.
-- A product inside a product is parenthesized, because the parser splices a
-- product written with operators into the one around it.
--
-- Golden files are FullForm, never this (§7.4), so a change here
-- invalidates no regression case.
module Cassini.Syntax.Pretty
  ( pretty,
    prettyMessage,
  )
where

import Cassini.Core.Expr (Expr, pattern App, pattern Int_, pattern Num, pattern Str, pattern Sym)
import Cassini.Core.Symbol
  ( Symbol,
    isNamePart,
    sBlank,
    sBlankNullSequence,
    sBlankSequence,
    sCompoundExpression,
    sDerivative,
    sFunction,
    sList,
    sNull,
    sOptional,
    sPattern,
    sPlus,
    sPower,
    sSlot,
    sSlotSequence,
    sTimes,
    symContext,
    symName,
    systemSymbol,
  )
import Cassini.Eval.Message (Message (..), MessageTag (..))
import Cassini.Number (Number (NInt, NRat))
import Cassini.Syntax.Lexer (quoteString)
import Cassini.Syntax.Parser (Fixity (..), Operator (..), operators)
import Data.HashMap.Strict qualified as HashMap
import Data.Text qualified as T
import Data.Vector qualified as V

-- $setup
-- >>> import Cassini.Script (resolveName)
-- >>> import Cassini.Syntax.Parser (parseExpr)
-- >>> import Cassini.Core.Expr (mkString)
-- >>> let parsed = either mkString id . parseExpr resolveName

-- | Print in the infix syntax.
--
-- >>> pretty (parsed "a x^2 - b/c + f'[x] /. y_ :> {y, #2 &}")
-- "a x^2 - b/c + f'[x] /. y_ :> {y, #2 &}"
pretty :: Expr -> Text
pretty = snd . doc 0

-- | A printed expression and the precedence of its outermost operator: an
-- atom or a call binds tightest.
type Doc = (Int, Text)

atom :: Text -> Doc
atom t = (1000, t)

-- | Print for a context that needs an operand binding tighter than @ctx@,
-- parenthesizing if it does not.
at :: Int -> Expr -> Text
at ctx e = let (p, t) = doc ctx e in if p > ctx then t else "(" <> t <> ")"

doc :: Int -> Expr -> Doc
doc _ e = case e of
  Num (NInt i) | i < 0 -> (480, show i)
  Num (NInt i) -> atom (show i)
  Num (NRat r) -> (470, show (numerator r) <> "/" <> show (denominator r))
  Str t -> atom (quoteString t)
  Sym s -> atom (name s)
  App (Sym h) as -> fromMaybe (call e) (special h (V.toList as))
  App _ _ | Just t <- derivativeForm e -> (670, t)
  App _ _ -> call e

-- | The bracket form, @h[a, b]@, which every expression has.
call :: Expr -> Doc
call = \case
  App h as -> case derivativeForm h of
    -- @f'[x]@: the call applies to @f'@, so it binds as @'@ does.
    Just t -> (670, t <> arguments as)
    Nothing -> atom (at 999 h <> arguments as)
  e -> doc 0 e
  where
    arguments as = "[" <> T.intercalate ", " (map (at 0) (V.toList as)) <> "]"

-- | An operator form, where one prints exactly this expression.
special :: Symbol -> [Expr] -> Maybe Doc
special h as
  | h == sList = Just (atom ("{" <> T.intercalate ", " (map (at 0) as) <> "}"))
  | h == sPlus, _ : _ : _ <- as = Just (plus as)
  | h == sTimes, _ : _ : _ <- as = Just (times as)
  | h == sPower, [b, x] <- as = Just (590, at 590 b <> "^" <> exponent' x)
  | h == sCompoundExpression, _ : _ : _ <- as = Just (compound as)
  | h == sFunction, [body] <- as = Just (90, at 90 body <> " &")
  | h == sSlot, [Int_ n] <- as, n >= 0 = Just (atom (if n == 1 then "#" else "#" <> show n))
  | h == sSlotSequence, [Int_ n] <- as, n >= 1 = Just (atom (if n == 1 then "##" else "##" <> show n))
  | h == systemSymbol "Part", x : is@(_ : _) <- as = Just (atom (at 999 x <> "[[" <> T.intercalate ", " (map (at 0) is) <> "]]"))
  | h == systemSymbol "Out" = out as
  | h == systemSymbol "MessageName", [Sym s, Str t] <- as, isName t = Just (750, name s <> "::" <> t)
  | Just b <- blank h as = Just (atom b)
  | h == sPattern,
    [Sym x, p] <- as = Just $ case blankOf p of
      Just b -> atom (name x <> b)
      Nothing -> (150, name x <> ":" <> at 150 p)
  | h == sOptional, [p] <- as, Just b <- optionalBlank p = Just (atom b)
  | h == sOptional, [p, v] <- as, not (isSymbol p) = Just (140, at 140 p <> ":" <> at 140 v)
  | otherwise = generic h as
  where
    isSymbol = \case
      Sym _ -> True
      _ -> False

-- | A generic operator from the table, by its head.
generic :: Symbol -> [Expr] -> Maybe Doc
generic h as = case (find (\o -> o.opHead == Just h.symName && h.symContext == "System`") operators, as) of
  _ | h.symName `elem` ["Pattern", "Optional", "MessageName"] -> Nothing
  (Just (Operator t p InfixFlat _), _ : _ : _) -> Just (p, T.intercalate (" " <> t <> " ") (map (at p) as))
  (Just (Operator t p InfixLeft _), [a, b]) -> Just (p, at (p - 1) a <> sep t <> at p b)
  (Just (Operator t p InfixRight _), [a, b]) -> Just (p, at p a <> sep t <> at (p - 1) b)
  (Just (Operator t p Prefix _), [a]) -> Just (p, t <> at p a)
  (Just (Operator t p Postfix _), [a]) -> Just (p, at p a <> postfixSep t <> t)
  _ -> Nothing
  where
    -- @x?f@ and @f::tag@ print tight, as WL prints them.
    sep t = if t `elem` ["?", "::"] then t else " " <> t <> " "
    -- A space keeps @x_. ..@ from reading as @x_...@.
    postfixSep t = if t `elem` ["..", "...", "&", "=."] then " " else ""

-- | A sum: @a + b@, and @a - b@ wherever the parser's negation of @b@ is
-- exactly the term.
plus :: [Expr] -> Doc
plus = \case
  [] -> (310, "")
  t0 : ts -> (310, at 310 t0 <> foldMap term ts)
  where
    term t = case minus t of
      Just rest -> " - " <> rest
      Nothing -> " + " <> at 310 t
    minus t = case t of
      Num n | negative n -> Just (at 310 (numberE (negateN n)))
      App (Sym h) xs | h == sTimes -> case V.toList xs of
        Int_ (-1) : rest@(r : _) | not (isNumber r) -> Just (product' rest)
        Num n : rest@(_ : _) | negative n -> Just (product' (numberE (negateN n) : rest))
        _ -> Nothing
      _ -> Nothing
    -- What the parser reads back as a product with these factors, or the
    -- one factor itself.
    product' = \case
      [x] -> factor 310 x
      xs -> let (p, d) = times xs in if p > 310 then d else "(" <> d <> ")"

-- | A product: factors side by side, a leading @-1@ as @-@, and trailing
-- reciprocals as @/d@.
times :: [Expr] -> Doc
times fs = case fs of
  Int_ (-1) : g : gs | not (isNumber g) -> case gs of
    [] -> (480, "-" <> factor 480 g)
    _ -> let (p, d) = body 480 (g : gs) in (min p 400, "-" <> d)
  _ -> body 400 fs
  where
    body firstCtx xs =
      let (nums, dens) = splitDenominators xs
       in if null nums || null dens || folds nums dens
            then (400, sideBySide firstCtx xs)
            else
              ( if length nums == 1 then 470 else 400,
                sideBySide firstCtx nums <> foldMap (\d -> "/" <> at 470 d) dens
              )
    sideBySide firstCtx = \case
      [] -> ""
      x : xs -> T.unwords (factor firstCtx x : map later xs)
    -- A factor after the first must not start with a minus, or it would
    -- read as a difference.
    later x = let t = factor 400 x in if "-" `T.isPrefixOf` t then "(" <> t <> ")" else t
    -- The trailing reciprocals, as their denominators.
    splitDenominators xs =
      let (ds, ns) = span isReciprocal (reverse xs)
       in (reverse ns, [d | App _ ys <- reverse ds, d : _ <- [V.toList ys]])
    isReciprocal = \case
      App (Sym p) ys | p == sPower, [_, Int_ (-1)] <- V.toList ys -> True
      _ -> False
    -- @3/2@ reads as a number, so an integer before an integer denominator
    -- stays side by side.
    folds nums dens = case (viaNonEmpty last nums, dens) of
      (Just (Int_ _), Int_ q : _) -> q > 0
      _ -> False

-- | A factor of a product: in parentheses if it is a product itself, which
-- the parser would splice, or if it binds looser than @ctx@.
factor :: Int -> Expr -> Text
factor ctx x = case x of
  App (Sym h) _ | h == sTimes -> "(" <> snd (doc 0 x) <> ")"
  _ -> at ctx x

-- | An exponent: a negative integer needs no parentheses (@x^-1@).
exponent' :: Expr -> Text
exponent' = \case
  Int_ n | n < 0 -> show n
  x -> at 589 x

-- | @a; b@, with a trailing @Null@ as a trailing @;@.
compound :: [Expr] -> Doc
compound as = case reverse as of
  Sym n : rest@(_ : _) | n == sNull -> (10, T.intercalate "; " (map (at 10) (reverse rest)) <> ";")
  _ -> (10, T.intercalate "; " (map (at 10) as))

-- | @%@, @%%@ and @%n@. @Out[-1]@ has no short form: @%@ is @Out[]@.
out :: [Expr] -> Maybe Doc
out = \case
  [] -> Just (atom "%")
  [Int_ k] | k < -1 -> Just (atom (T.replicate (fromInteger (negate k)) "%"))
  [Int_ n] | n > 0 -> Just (atom ("%" <> show n))
  _ -> Nothing

-- | @f'@ for @Derivative[1][f]@, @f''@ for @Derivative[2][f]@.
derivativeForm :: Expr -> Maybe Text
derivativeForm = \case
  App (App (Sym d) ns) fs
    | d == sDerivative,
      [Int_ n] <- V.toList ns,
      n >= 1,
      n <= 4,
      [f] <- V.toList fs ->
        Just (at 669 f <> T.replicate (fromInteger n) "'")
  _ -> Nothing

-- | A blank with no name: @_@, @__h@, @___@.
blank :: Symbol -> [Expr] -> Maybe Text
blank h as = do
  n <- snd <$> find ((== h) . fst) [(sBlank, 1), (sBlankSequence, 2), (sBlankNullSequence, 3)]
  constraint <- case as of
    [] -> Just ""
    [Sym c] -> Just (name c)
    _ -> Nothing
  Just (T.replicate n "_" <> constraint)

-- | The blank of a pattern @x_h@, when it is one.
blankOf :: Expr -> Maybe Text
blankOf = \case
  App (Sym h) as -> blank h (V.toList as)
  _ -> Nothing

-- | @x_.@ and @_.@.
optionalBlank :: Expr -> Maybe Text
optionalBlank = \case
  App (Sym p) xs | p == sPattern, [Sym x, App (Sym b) cs] <- V.toList xs, b == sBlank, Just t <- blank b (V.toList cs) -> Just (name x <> t <> ".")
  App (Sym b) cs | b == sBlank, Just t <- blank b (V.toList cs) -> Just (t <> ".")
  _ -> Nothing

isNumber :: Expr -> Bool
isNumber = \case
  Num _ -> True
  _ -> False

negative :: Number -> Bool
negative = \case
  NInt i -> i < 0
  NRat r -> r < 0

negateN :: Number -> Number
negateN = \case
  NInt i -> NInt (negate i)
  NRat r -> NRat (negate r)

numberE :: Number -> Expr
numberE = Num

-- | A symbol's name: bare in @System`@ and @Global`@, in full otherwise.
name :: Symbol -> Text
name s
  | s.symContext `elem` ["System`", "Global`"] = s.symName
  | otherwise = s.symContext <> s.symName

-- | Whether a message tag reads back after @::@ as itself: a name as the
-- lexer's 'Cassini.Syntax.Lexer.nameTok' reads one, without a leading
-- backquote, which the parser does not keep.
isName :: Text -> Bool
isName = all isNamePart . T.splitOn "`"

-- | A message as the front end shows it: @symbol::tag: text@, the template's
-- @`k`@ slots filled with the arguments printed in the infix syntax. A tag
-- with no template shows its arguments.
--
-- >>> prettyMessage (Message (systemSymbol "Power") "infy" [parsed "1/0"])
-- "Power::infy: Infinite expression 1/0 encountered."
prettyMessage :: Message -> Text
prettyMessage m =
  messageText <> ": " <> case HashMap.lookup messageText templates <|> HashMap.lookup tag templates of
    Just tmpl -> fill tmpl
    Nothing -> T.intercalate ", " (map pretty m.msgArgs)
  where
    MessageTag tag = m.msgTag
    messageText = name m.msgSymbol <> "::" <> tag
    fill tmpl = foldl' (\acc (k, a) -> T.replace ("`" <> show k <> "`") (pretty a) acc) tmpl (zip [1 :: Int ..] m.msgArgs)

-- | The templates of the messages the kernel emits, by full name where the
-- arguments differ between symbols, else by tag, as WL's @General@
-- messages read.
templates :: HashMap Text Text
templates =
  HashMap.fromList
    [ ("infy", "Infinite expression `1` encountered."),
      ("indet", "Indeterminate expression `1` encountered."),
      ("partw", "Part `1` of `2` does not exist."),
      ("Set::partw", "Part assignment `1` is out of range."),
      ("partd", "Part specification `1` is longer than depth of object."),
      ("pkspec1", "The expression `1` cannot be used as a part specification."),
      ("itlim", "Iteration limit of `1` exceeded."),
      ("reclim", "Recursion depth of `1` exceeded during evaluation."),
      ("tdlen", "Objects of unequal length in `1` cannot be combined."),
      ("locked", "Symbol `1` is locked."),
      ("wrsym", "Symbol `1` is Protected."),
      ("write", "Tag `1` in `2` is Protected."),
      ("setraw", "Cannot assign to raw object `1`."),
      ("shape", "Lists `1` and `2` are not the same shape."),
      ("noval", "Symbol `1` in part assignment does not have an immediate value."),
      ("norep", "Assignment on `1` not found."),
      ("tagnf", "Tag `1` not found in `2`."),
      ("nosym", "`1` does not contain a symbol to attach a rule to."),
      ("argx", "called with `1` arguments; 1 argument is expected."),
      ("reps", "`1` is neither a list of replacement rules nor a valid dispatch table, and so cannot be used for replacing."),
      ("rrlim", "Exiting after `1` scanned `2` times."),
      ("slotn", "Slot number `1` in `2` cannot be filled."),
      ("slots", "SlotSequence `1` in `2` cannot be filled."),
      ("pssl", "`1` is not a symbol or a string."),
      ("symname", "The string `1` cannot be used for a symbol name."),
      ("innf", "Non-negative integer or Infinity expected at position `1` in `2`."),
      ("fpct", "Too many parameters in `1` to be filled from `2`."),
      ("nocatch", "Uncaught `1` returned to top level.")
    ]
