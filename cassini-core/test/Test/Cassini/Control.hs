-- | "Cassini.Builtins.Control": pure-function application and
-- @CompoundExpression@, with the @Function@ half of §7.3's @Control@ row
-- (DESIGN.md §4.13). The rest of the row is the control-flow track's.
module Test.Cassini.Control (tests) where

import Cassini.Core.Expr (Expr, apply, mkApp)
import Cassini.Core.Symbol (sFunction, sList)
import Cassini.Structure (substituteAll)
import Data.Vector qualified as V
import Test.Gen (genExpr, shrinkExpr, sym)
import Test.Kernel (eval, evalStd, ff, messageNames, parse, std)
import Test.QuickCheck (Property, counterexample, forAllShrink, sized, (===))
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
        ]
    ]

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
