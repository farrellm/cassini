-- | "Cassini.Builtins.Message": message control, with §7.3's @Message@ row
-- (DESIGN.md §4.7, D42).
module Test.Cassini.Message (tests) where

import Cassini.Core.Expr (Expr, apply)
import Cassini.Core.Symbol (systemSymbol)
import Cassini.Eval.Kernel (KernelState)
import Test.Gen (genExpr, shrinkExpr, sym)
import Test.Kernel (eval, evalStd, ff, messageNames, parse, stateWith, std)
import Test.QuickCheck (Property, counterexample, elements, forAll, forAllShrink, sized, (===))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "Message"
    [ testCase "Quiet hides the messages and keeps the value" $
        let (r, st) = eval std (parse "Quiet[Power[0, -1]]") in (ff r, messageNames st) @?= ("DirectedInfinity[]", []),
      testCase "a message's text resolves to General's when the symbol has none" $
        evalStd ["Set[MessageName[General, \"zz\"], \"shared\"]", "MessageName[General, \"zz\"]"] @?= "\"shared\"",
      testProperty "Quiet[e] evaluates to what e does (§7.3)" quietValue,
      testProperty "Check[e, f] is f exactly when e generates a message (§7.3)" checkSees,
      testProperty "a frame left by a value, a Throw or an Abort[] leaks nothing (§7.3)" framesEnd
    ]

-- | An expression that may generate messages: a generated one, or one
-- with a division by zero or a bad part inside.
genNoisy :: Int -> Expr -> Expr
genNoisy k u = case k `mod` 3 of
  0 -> u
  1 -> apply (systemSymbol "Plus") [u, apply (systemSymbol "Power") [apply (systemSymbol "Times") [u, sym "zero"], sym "minus"]]
  _ -> apply (systemSymbol "List") [u, apply (systemSymbol "Part") [apply (systemSymbol "List") [u], sym "two"]]

-- | The state the noisy expressions read: zero is 0, minus is -1, two is 2.
noisy :: KernelState
noisy = stateWith ["Set[zero, 0]", "Set[minus, -1]", "Set[two, 2]"]

quietValue :: Property
quietValue =
  forAllShrink (sized (genExpr . min 20)) shrinkExpr $ \u ->
    forAll (elements [0, 1, 2]) $ \k ->
      let e = genNoisy k u
          (plain, _) = eval noisy e
          (quiet, st) = eval noisy (apply (systemSymbol "Quiet") [e])
       in counterexample (toString (ff e)) $ (ff quiet, messageNames st) === (ff plain, [])

checkSees :: Property
checkSees =
  forAllShrink (sized (genExpr . min 20)) shrinkExpr $ \u ->
    forAll (elements [0, 1, 2]) $ \k ->
      let e = genNoisy k u
          (plain, st) = eval noisy e
          failed = sym "failed"
          (checked, _) = eval noisy (apply (systemSymbol "Check") [e, failed])
          expected = if null (messageNames st) then plain else failed
       in counterexample (toString (ff e)) $ ff checked === ff expected

-- | After a Quiet or Check exits by a value, a Throw or an Abort[], the next
-- message is shown, and an enclosing Check sees it.
framesEnd :: Property
framesEnd =
  forAll (elements ["Quiet", "Check"]) $ \frame ->
    forAll (elements ["v", "Throw[v]", "Abort[]"]) $ \exit ->
      let inner = frame <> "[" <> exit <> (if frame == "Check" then ", failed" else "") <> "]"
          (_, st) = eval std (parse ("Catch[" <> inner <> "]"))
          (r, st') = eval st (parse "Check[Power[0, -1], seen]")
       in counterexample (toString inner) $ (ff r, messageNames st') === ("seen", ["Power::infy"])
