-- | "Cassini.Builtins.Control": pure functions, sequencing, conditionals,
-- scoping, non-local exits, loops and iterators, with §7.3's @Control@ row
-- (DESIGN.md §4.13).
module Test.Cassini.Control (tests) where

import Cassini.Attributes (attributeList)
import Cassini.Core.Expr (Expr, apply, mkApp)
import Cassini.Core.Symbol (globalSymbol, sFunction, sList, systemSymbol)
import Cassini.Eval.Kernel (EvalConfig (..), KernelState (..), defaultConfig)
import Cassini.Rules (Rule (..), SymbolInfo (..), ValueKind (..), emptyInfo, ruleSetToList, rulesOf)
import Cassini.Structure (substituteAll)
import Data.Map.Strict qualified as Map
import Data.Vector qualified as V
import Test.Gen (genExpr, shrinkExpr, sym)
import Test.Kernel (eval, evalStd, evalWith, ff, messageNames, parse, stateWith, std)
import Test.QuickCheck (Property, chooseInt, counterexample, elements, forAll, forAllShrink, sized, sublistOf, (.&&.), (===))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "Control"
    [ testGroup
        "Function"
        [ testCase "slots take the arguments" $ evalStd ["Function[Plus[Slot[1], Times[2, Slot[2]]]][a, b]"] @?= "Plus[a, Times[2, b]]",
          testCase "arguments beyond the highest slot are ignored" $ evalStd ["Function[Slot[1]][a, b, c]"] @?= "a",
          testCase "## is every argument, ##2 the rest" $
            evalStd ["Function[List[SlotSequence[1], SlotSequence[2]]][a, b]"] @?= "List[a, b, b]",
          testCase "#0 is the function itself" $ evalStd ["Function[f[Slot[0]]][1]"] @?= "f[Function[f[Slot[0]]]]",
          -- wolfram/Slot/PossibleIssues/2
          testCase "a slot with no argument stays, with Function::slotn" $
            let (r, st) = eval std (parse "Function[f[Slot[4]]][a, b, c]")
             in (ff r, messageNames st) @?= ("f[Slot[4]]", ["Function::slotn"]),
          testCase "named parameters take the arguments" $ evalStd ["Function[List[x, y], Plus[x, Times[2, y]]][a, b]"] @?= "Plus[a, Times[2, b]]",
          testCase "a single parameter" $ evalStd ["Function[x, Power[x, 2]][a]"] @?= "Power[a, 2]",
          testCase "too few arguments is Function::fpct" $
            let (r, st) = eval std (parse "Function[List[x, y], x][a]")
             in (ff r, messageNames st) @?= ("Function[List[x, y], x][a]", ["Function::fpct"]),
          testCase "Function[Null, body, attrs] is slot form" $ evalStd ["Function[Null, Hold[Slot[1]], HoldAll][Plus[1, 1]]"] @?= "Hold[Plus[1, 1]]",
          testCase "a slot-form function inside keeps its own slots" $
            evalStd ["Function[Function[Slot[1]][Slot[2]]][a, b]"] @?= "b"
        ],
      -- Source: wolfram_ref_modularity_and_naming.html, "Variables in Pure
      -- Functions and Rules", whose outputs are images; these are read off
      -- its prose.
      testGroup
        "renaming (WL, Variables in Pure Functions and Rules)"
        [ testCase "the inner parameter y is renamed when the body changes" $
            evalStd ["Function[List[x], Function[List[y], Plus[x, y]]][Times[2, y]]"] @?= "Function[List[y$], Plus[Times[2, y], y$]]",
          testCase "the renamed function behaves as it should" $
            evalStd ["Function[List[x], Function[List[y], Plus[x, y]]][Times[2, y]][a]"] @?= "Plus[a, Times[2, y]]",
          testCase "an inner body that does not change is not renamed" $
            evalStd ["Function[List[x], Plus[x, Function[List[y], Power[y, 2]]]][a]"] @?= "Plus[Function[List[y], Power[y, 2]], a]",
          testCase "an inner parameter of the same name shields its body" $
            evalStd ["Function[List[x], Function[List[x], Plus[x, y]]][a]"] @?= "Function[List[x], Plus[x, y]]",
          testCase "both inner functions of three are renamed" $
            evalStd ["Function[List[x], Function[List[y], Function[List[z], Plus[x, y, z]]]][a]"]
              @?= "Function[List[y$], Function[List[z$], Plus[a, y$, z$]]]",
          testCase "a rule's right-hand side is substituted as /. would, the parameter included" $
            evalStd ["SetDelayed[mkfun[Pattern[var, Blank[]], Pattern[body, Blank[]]], Function[List[var], body]]", "mkfun[x, Power[x, 2]]"]
              @?= "Function[List[x], Power[x, 2]]",
          testCase "and renames a construct's other names when it changes the inside" $
            evalStd ["SetDelayed[f[Pattern[x, Blank[]]], Function[List[y], Plus[x, y]]]", "f[y]"] @?= "Function[List[y$], Plus[y, y$]]",
          testCase "a rule inside is a scoping construct for its pattern names" $
            evalStd ["Function[List[w], Rule[f[Pattern[x, Blank[]]], Plus[w, x]]][x]"] @?= "Rule[f[Pattern[x$, Blank[]]], Plus[x, x$]]"
        ],
      testProperty "Function[x, Function[y, b]][a][v] is b with x and y replaced at once, capture-free (§7.3)" capture,
      testGroup
        "CompoundExpression"
        [ testCase "evaluates in turn and gives the last" $ evalStd ["CompoundExpression[Set[a, 1], Plus[a, 1]]"] @?= "2",
          testCase "a trailing Null gives Null" $ evalStd ["CompoundExpression[Set[a, 1], Null]"] @?= "Null",
          testCase "nothing is Null" $ evalStd ["CompoundExpression[]"] @?= "Null",
          testCase "the last argument's message is emitted once" $
            messageNames (snd (eval std (parse "CompoundExpression[a, Part[List[1, 2], 3]]"))) @?= ["Part::partw"]
        ],
      testGroup
        "conditionals"
        [ testCase "an undecided If stays" $ evalStd ["If[x, a, b]"] @?= "If[x, a, b]",
          testCase "If's fourth argument takes an undecided test" $ evalStd ["If[x, a, b, c]"] @?= "c",
          testCase "If[False, t] is Null" $ evalStd ["If[False, a]"] @?= "Null",
          testCase "Which stops at an undecided test" $ evalStd ["Which[False, a, x, b, True, c]"] @?= "Which[x, b, True, c]",
          testCase "Switch matches its forms in turn" $ evalStd ["Switch[f[1], g[Blank[]], a, f[Blank[]], b]"] @?= "b",
          testCase "With substitutes the evaluated value" $ evalStd ["With[List[Set[x, Plus[1, 1]]], Hold[x]]"] @?= "Hold[2]",
          testCase "With[x := v] substitutes it unevaluated" $ evalStd ["With[List[SetDelayed[x, Plus[1, 1]]], Hold[x]]"] @?= "Hold[Plus[1, 1]]",
          testCase "With with two lists nests" $ evalStd ["With[List[Set[x, 1]], List[Set[y, x]], List[x, y]]"] @?= "List[1, 1]"
        ],
      testGroup
        "iterators"
        [ testCase "Table over a list" $ evalStd ["Table[Power[i, 2], List[i, List[a, b]]]"] @?= "List[Power[a, 2], Power[b, 2]]",
          testCase "Table with a step" $ evalStd ["Table[i, List[i, 1, 2, Rational[1, 2]]]"] @?= "List[1, Rational[3, 2], 2]",
          testCase "Table with symbolic bounds a whole number of steps apart" $ evalStd ["Table[i, List[i, x, Plus[x, 2]]]"] @?= "List[x, Plus[1, x], Plus[2, x]]",
          testCase "the iteration variable is restored" $ evalStd ["Set[i, 7]", "CompoundExpression[Table[i, List[i, 3]], i]"] @?= "7",
          testCase "Sum with a symbolic bound stays, for §6.3" $ evalStd ["Sum[i, List[i, 1, n]]"] @?= "Sum[i, List[i, 1, n]]",
          testCase "Product" $ evalStd ["Product[i, List[i, 5]]"] @?= "120",
          testCase "FixedPoint compares with SameQ" $ evalStd ["FixedPoint[Function[Floor[Times[Slot[1], Rational[1, 2]]]], 100]"] @?= "0",
          testCase "FoldList" $ evalStd ["FoldList[f, x, List[a, b]]"] @?= "List[x, f[x, a], f[f[x, a], b]]"
        ],
      testProperty "Block leaves a localized symbol as it found it, however its body exits (§7.3)" blockRestores,
      testProperty "Module's names depend only on the initial state (§7.3)" moduleDeterministic,
      testCase "the recursion the next law runs fits the low limit, and one twice as deep does not" $
        map (\k -> ff (fst (evalWith limited std (parse ("CompoundExpression[SetDelayed[r[0], 0], SetDelayed[r[Pattern[k, Blank[]]], Plus[1, r[Plus[k, -1]]]], r[" <> k <> "]]"))))) ["60", "70"]
          @?= ["60", "Plus[1, TerminatedEvaluation[\"RecursionLimit\"]]"],
      testProperty "caught unwinds leave the recursion depth and fuel as they were (§7.3)" caughtUnwinds,
      testCase "an Abort[] leaves the next input its full depth (§7.3)" $
        let deep = parse "CompoundExpression[SetDelayed[r[0], 0], SetDelayed[r[Pattern[k, Blank[]]], Plus[1, r[Plus[k, -1]]]], r[60]]"
            (_, aborted) = evalWith limited std (parse "Block[List[x], Abort[]]")
         in ff (fst (evalWith limited aborted deep)) @?= ff (fst (evalWith limited std deep)),
      testProperty "an uncaught exit comes back held, and evaluating it raises nothing (§7.3)" heldExits
    ]

-- | A low recursion limit, so that a leaked depth would show.
limited :: EvalConfig
limited = defaultConfig {recursionLimit = 128, iterationLimit = 64}

-- | What @Block@ must restore of @f@: its attributes and its four kinds of
-- values.
snapshot :: KernelState -> Text
snapshot st =
  let info = Map.findWithDefault emptyInfo (globalSymbol "f") st.ksSymbols
   in show (attributeList info.siAttributes, [[(r.ruleLhs, show r.ruleBody :: Text) | r <- ruleSetToList (rulesOf k info)] | k <- [OwnValue, DownValue, UpValue, SubValue]])

-- | @f@ with some of an own value, a down value, an up value and attributes;
-- a @Block@ on it whose body redefines all four and then exits by a value, a
-- @Throw@, a @Break@ or an @Abort[]@.
blockRestores :: Property
blockRestores =
  forAll (sublistOf ["Set[f, a]", "SetDelayed[f[Pattern[x, Blank[]]], b]", "UpSetDelayed[g[f], c]", "SetAttributes[f, List[Listable, Orderless]]"]) $ \defs ->
    forAll (elements ["v", "Throw[1]", "Break[]", "Abort[]"]) $ \exit ->
      let st = stateWith defs
          body = "CompoundExpression[Set[f, 9], SetDelayed[f[Pattern[y, Blank[]]], 8], SetAttributes[f, Flat], " <> exit <> "]"
          wrap = case exit of
            "Throw[1]" -> \b -> "Catch[" <> b <> "]"
            "Break[]" -> \b -> "Do[" <> b <> ", List[1]]"
            _ -> id
          (_, after) = eval st (parse (wrap ("Block[List[f], " <> body <> "]")))
       in counterexample (toString exit) (snapshot after === snapshot st)

-- | The same input from the same state gives the same @Module@ names.
moduleDeterministic :: Property
moduleDeterministic =
  forAll (chooseInt (0, 5)) $ \k ->
    let st = foldl' (\acc _ -> snd (eval acc (parse "Module[List[x], x]"))) std [1 .. k]
        once = ff (fst (eval st (parse "Module[List[x, y], List[x, y]]")))
     in once === ff (fst (eval st (parse "Module[List[x, y], List[x, y]]")))

-- | A loop of caught @Throw@s, @Break@s, @Continue@s or @Return@s, then a
-- recursion that needs most of the depth: it evaluates as it does with no
-- loop before it.
caughtUnwinds :: Property
caughtUnwinds =
  forAll (chooseInt (1, 300)) $ \n ->
    forAll (elements ["Catch[Throw[i]]", "Do[Break[], List[2]]", "Do[Continue[], List[2]]", "Do[Return[i], List[2]]", "Catch[Do[Throw[i], List[2]]]"]) $ \u ->
      let deep = "CompoundExpression[SetDelayed[r[0], 0], SetDelayed[r[Pattern[k, Blank[]]], Plus[1, r[Plus[k, -1]]]], r[60]]"
          looped = "CompoundExpression[Do[" <> u <> ", List[i, " <> show n <> "]], " <> deep <> "]"
       in ff (fst (evalWith limited std (parse looped))) === ff (fst (evalWith limited std (parse deep)))

-- | @Throw@, @Break@, @Continue@ and @Return@ at the top come back
-- @Hold@-wrapped, and the result evaluated again is itself.
heldExits :: Property
heldExits =
  forAllShrink (sized (genExpr . min 8)) shrinkExpr $ \v ->
    forAll (elements ["Throw", "Return", "Break", "Continue"]) $ \name ->
      let exit = apply (systemSymbol name) [v | name `elem` ["Throw", "Return"]]
          (r, st) = eval std exit
       in counterexample (toString (ff r)) $
            (take 5 (toString (ff r)) === "Hold[") .&&. (ff (fst (eval st r)) === ff r)

-- | Two nested pure functions applied in turn agree with substituting both
-- parameters at once, whatever free symbols the arguments carry: a value
-- that mentions the inner parameter @y@ is not captured by it.
capture :: Property
capture =
  forAllShrink (sized (genExpr . min 30)) shrinkExpr $ \b ->
    forAllShrink (sized (genExpr . min 8)) shrinkExpr $ \a ->
      forAllShrink (sized (genExpr . min 8)) shrinkExpr $ \v ->
        let x = sym "x"
            y = sym "y"
            fn p body = apply sFunction [apply sList [p], body]
            applied = mkApp (mkApp (fn x (fn y b)) (V.singleton a)) (V.singleton v)
            direct = substituteAll b [(x, a), (y, v)]
            value :: Expr -> Expr
            value = fst . eval std
         in counterexample (toString (ff applied)) (ff (value applied) === ff (value direct))
