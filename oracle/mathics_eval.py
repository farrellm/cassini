#!/usr/bin/env python3
"""Evaluate a FullForm script in Mathics3, in Cassini's script format.

DESIGN.md §7.5: cassini-oracle runs Cassini and Mathics3 on the same inputs.
This is the Mathics3 side. It reads a script on stdin (one FullForm input per
line; blank lines and whole-line (* ... *) comments are not inputs), evaluates
the inputs in order in one fresh session, and writes, for input k,

    Out[k]: <FullForm>      or  Out[k]: -   for Null
    Message[k]: symbol::tag

which is cassini's own runScript format (§7.4), so the two compare line by
line. Run it with the Mathics3 interpreter and -I:

    $CASSINI_MATHICS_PYTHON -I oracle/mathics_eval.py < script.in
"""

import contextlib
import io
import sys

with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
    from mathics.core.load_builtin import import_and_load_builtins

    import_and_load_builtins()
    from mathics.core.atoms import Complex, Integer, Rational, Real, String
    from mathics.core.evaluation import Evaluation, Message, Output
    from mathics.core.parser import parse
    from mathics.session import MathicsSession
    from mathics_scanner.feed import SingleLineFeeder


class Collect(Output):
    """Keeps the messages an evaluation emits, in order."""

    def __init__(self):
        self.messages = []

    def max_stored_size(self, output_settings):
        return None

    def out(self, out):
        if isinstance(out, Message):
            self.messages.append("%s::%s" % (out.symbol, out.tag))

    def clear(self, wait):
        pass

    def display(self, data, metadata):
        pass


def short(name):
    for ctx in ("System`", "Global`"):
        if name.startswith(ctx):
            return name[len(ctx):]
    return name


def fullform(e):
    """FullForm text, as Cassini.Syntax.FullForm prints it."""
    if isinstance(e, Integer):
        return str(e.value)
    if isinstance(e, Rational):
        v = e.value
        return "Rational[%d, %d]" % (v.p, v.q)
    if isinstance(e, Real):
        return repr(e.value) if isinstance(e.value, float) else str(e)
    if isinstance(e, Complex):
        return "Complex[%s, %s]" % (fullform(e.real), fullform(e.imag))
    if isinstance(e, String):
        v = e.value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return '"' + v + '"'
    if hasattr(e, "elements"):
        return fullform(e.head) + "[" + ", ".join(fullform(x) for x in e.elements) + "]"
    return short(e.get_name())


def main():
    session = MathicsSession()
    lines = [l.strip() for l in sys.stdin.read().splitlines()]
    inputs = [l for l in lines if l and not (l.startswith("(*") and l.endswith("*)"))]
    out = []
    for k, text in enumerate(inputs, 1):
        collect = Collect()
        evaluation = Evaluation(session.definitions, output=collect, catch_interrupt=True)
        try:
            query = parse(session.definitions, SingleLineFeeder(text, "<oracle>"))
        except Exception:
            out.append("Out[%d]: $Failed" % k)
            out.append("Message[%d]: Syntax::sntx" % k)
            continue
        # Mathics3 can fail with a Python exception (a RecursionError on an
        # endless chain, a bug in a builtin). That is an inconclusive input,
        # not a disagreement; the session goes on with the next one.
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                evaluation.evaluate(query, timeout=30)
        except BaseException as ex:
            out.append("Out[%d]: ?mathics:%s" % (k, type(ex).__name__))
            continue
        result = evaluation.last_eval
        if result is None:
            result = evaluation.exc_result
        name = result.get_name() if hasattr(result, "get_name") and not hasattr(result, "elements") else ""
        out.append("Out[%d]: %s" % (k, "-" if name == "System`Null" else fullform(result)))
        out.extend("Message[%d]: %s" % (k, m) for m in collect.messages)
    sys.stdout.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
