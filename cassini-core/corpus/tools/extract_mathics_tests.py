#!/usr/bin/env python3
"""Turn Mathics3's test suite into sessions (DESIGN.md §7.8, milestone 1c).

Mathics3 tests the language with calls of test/helper.py's

    check_evaluation(str_expr, str_expected, failure_message, hold_expected, ...)

mostly from tables under @pytest.mark.parametrize, through one session that
check_evaluation(None) resets. The test files are read with Python's ast, never
imported or run. Each test function's cases become one session, in order, split
where a case resets; a case is one input, with its expected output.

    extract_mathics_tests.py MATHICS_CORE_DIR OUT_DIR

writes OUT_DIR/<file>/<function>/<k>.in and .expected and OUT_DIR/index.tsv, in
the format of extract_expreduce.py. OUT_DIR is under corpus/fetched/, which is
gitignored: Mathics3's suite is GPL, so it is fetched, and the repository holds
only case IDs (D26).

The expected string is evaluated by Mathics3 once, as check_evaluation does
unless hold_expected is set, and written as FullForm; a held one has its
arithmetic normalized, since check_evaluation compares it by its printed
form. A case's symbols, for the scope rule, are those of every input up to
its own, since the session's state carries. It is evaluated in a
session where no input has run, since the inputs are not run here: some create
and delete files.
So an expected value that depends on the session's definitions is wrong, and
triage finds it. An expected string that names an operation with side effects
(files, processes, the environment) is not evaluated, and its case is
unusable. Cases are dropped where check_evaluation does not compare an
expression: a regular expression, check_evaluation_as_in_cli's printed text,
to_string_expected=None's raw string, a pytest skip or xfail, a function that
also evaluates outside check_evaluation, whose state the session lacks; and
where the
failure message notes that Mathics3 departs from WMA, since such a case
documents Mathics3 rather than the language. Messages are given as text
without their symbol::tag, so they are not compared.
"""

import ast
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import extract_wolfram_docs as W  # noqa: E402

UNSAFE = re.compile(
    r"\b(Run|RunProcess|StartProcess|DeleteFile|DeleteDirectory|CreateFile|CreateDirectory|CopyFile|"
    r"RenameFile|CopyDirectory|RenameDirectory|SetDirectory|ResetDirectory|Put|PutAppend|Get|Needs|"
    r"OpenWrite|OpenAppend|OpenRead|Write|WriteString|Export|Import|Save|DumpSave|SetEnvironment|"
    r"Install|LinkLaunch|URLFetch|URLSave|Exit|Quit|Pause|FileNames|SetFileDate|Encode|Splice)\b"
)

DEPARTS = re.compile(r"\bWMA\b|Mathematica|Wolfram", re.I)


def literal(node):
    """The Python value of a literal node, or a marker for anything else."""
    try:
        return ast.literal_eval(node)
    except Exception:
        return NotLiteral


class NotLiteral:
    pass


def decorators(fn):
    """The parametrize names and rows of a test function, and whether it is
    skipped."""
    params, skipped = None, False
    for d in fn.decorator_list:
        text = ast.unparse(d)
        if "skip" in text or "xfail" in text:
            if "skipif" not in text:
                skipped = True
        if isinstance(d, ast.Call) and text.startswith("pytest.mark.parametrize") and len(d.args) >= 2:
            names = literal(d.args[0])
            if isinstance(names, str):
                names = [n.strip() for n in names.split(",")]
            rows = d.args[1]
            if isinstance(names, (list, tuple)) and isinstance(rows, (ast.List, ast.Tuple)):
                params = (list(names), rows.elts)
    return params, skipped


SIGNATURE = [
    "str_expr",
    "str_expected",
    "failure_message",
    "hold_expected",
    "to_string_expr",
    "to_string_expected",
    "to_python_expected",
    "expected_messages",
]


def bind(call):
    """check_evaluation's arguments by name, as nodes."""
    bound = {}
    for name, arg in zip(SIGNATURE, call.args):
        bound[name] = arg
    for kw in call.keywords:
        if kw.arg:
            bound[kw.arg] = kw.value
    return bound


def checks(fn):
    """The check_evaluation calls in a function's body, in source order
    (ast.walk is breadth first)."""
    found = [
        node
        for node in ast.walk(fn)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "check_evaluation"
    ]
    return sorted(found, key=lambda n: (n.lineno, n.col_offset))


SETUP = {"evaluate", "evaluate_value", "session", "reset_session", "check_evaluation_as_in_cli"}


def sets_up(fn):
    """Whether a function evaluates anything but through check_evaluation:
    its cases then depend on state the sessions here do not have."""
    for node in ast.walk(fn):
        if isinstance(node, ast.Call):
            f = node.func
            name = f.id if isinstance(f, ast.Name) else (f.value.id if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) else None)
            if name in SETUP:
                return True
    return False


def cases(fn):
    """The function's cases in order: (input, expected, hold, note), or None
    for a reset; or ("drop", reason)."""
    params, skipped = decorators(fn)
    if skipped:
        return
    if sets_up(fn):
        yield ("drop", "setup-outside-check")
        return
    calls = list(checks(fn))
    if params is None:
        for c in calls:
            yield case(bind(c), {})
        return
    names, rows = params
    for row in rows:
        values = literal(row)
        if not isinstance(values, (list, tuple)) or len(values) != len(names):
            yield ("drop", "row")
            continue
        env = dict(zip(names, values))
        for c in calls:
            yield case(bind(c), env)


def case(bound, env):
    def value(name, default=None):
        if name not in bound:
            return default
        node = bound[name]
        if isinstance(node, ast.Name) and node.id in env:
            return env[node.id]
        v = literal(node)
        return NotLiteral if v is NotLiteral else v

    expr = value("str_expr")
    if expr is None:
        return None
    expected = value("str_expected", "Null")
    if expected is None:
        expected = "Null"
    note = value("failure_message", "") or ""
    if not isinstance(expr, str) or not isinstance(expected, str):
        return ("drop", "not-a-string")
    if value("to_string_expected", True) is None or value("to_python_expected", False) is True:
        return ("drop", "not-an-expression")
    if isinstance(note, str) and DEPARTS.search(note):
        return ("drop", "departs-from-wma")
    return (expr, expected, bool(value("hold_expected", False)))


def expected_fullform(text, hold, flags, symbols):
    """The expected value as FullForm, "-" for Null. Unless held, it is
    evaluated once, as check_evaluation evaluates it. A held one is compared
    there by its printed form, which hides arithmetic's spelling (34 / 15
    prints as Rational[34, 15] does), so its arithmetic is normalized as the
    Wolfram corpus's outputs are (§7.9 step 6)."""
    if UNSAFE.search(text):
        raise W.Unusable("side-effects")
    if hold:
        out = W.normalize_output(text, flags, symbols)
    else:
        e = W.mparse(text)
        try:
            e = W.with_timeout(W.evaluate, e)
        except W.Unusable:
            raise
        except Exception as ex:
            raise W.Unusable("normalizer-error:" + type(ex).__name__)
        out = W.fullform(e, symbols, flags)
    return "-" if out == "Null" else out


def one_line(text):
    return " ".join(text.replace("\r", "").split("\n")).strip()


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    root, out = sys.argv[1], sys.argv[2]
    docs = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "wolfram-docs")
    if os.path.isdir(docs):
        W.SYSTEM_NAMES.update(n for n in os.listdir(docs) if not n.endswith((".tsv", ".txt")))
    rows, dropped = [], {}
    tests = os.path.join(root, "test")
    for dirpath, _, files in sorted(os.walk(tests)):
        for name in sorted(files):
            if not (name.startswith("test") and name.endswith(".py")):
                continue
            path = os.path.join(dirpath, name)
            module = os.path.relpath(path, tests)[:-3].replace(os.sep, "/")
            try:
                tree = ast.parse(open(path, encoding="utf-8").read())
            except SyntaxError:
                dropped["file-syntax"] = dropped.get("file-syntax", 0) + 1
                continue
            for fn in tree.body:
                if not (isinstance(fn, ast.FunctionDef) and fn.name.startswith("test")):
                    continue
                n, k, current = 0, 0, []
                groups = []
                # After an input that cannot be read, the session lacks its
                # effect, so the cases after it, up to a reset, are dropped.
                unread = False
                for c in cases(fn):
                    if c is None:
                        if current:
                            groups.append(current)
                        current, unread = [], False
                    elif c[0] == "drop":
                        dropped[c[1]] = dropped.get(c[1], 0) + 1
                        unread = unread or c[1] == "not-a-string"
                    elif unread:
                        dropped["after-unread-input"] = dropped.get("after-unread-input", 0) + 1
                    else:
                        current.append(c)
                if current:
                    groups.append(current)
                for group in groups:
                    k += 1
                    session = "%s/%s/%d" % (module, fn.name, k)
                    ins, outs = [], []
                    # A case depends on every input before it in its session.
                    before, before_flags = set(), set()
                    for j, (expr, expected, hold) in enumerate(group, 1):
                        n += 1
                        cid = "mathics/%s/%s/%d" % (module, fn.name, n)
                        line = one_line(expr)
                        ins.append(line)
                        flags, symbols, status = set(before_flags), set(before), "ok"
                        try:
                            mine, mine_flags = set(), set()
                            W.fullform(W.mparse(line), mine, mine_flags)
                            before |= mine
                            before_flags |= mine_flags
                            symbols |= mine
                            flags |= mine_flags
                            outs.append("Out[%d]: %s" % (j, expected_fullform(one_line(expected), hold, flags, symbols)))
                        except W.Unusable as u:
                            status = "unusable:" + str(u)
                            outs.append("Out[%d]: ?%s" % (j, u))
                        rows.append((cid, status, session, j, int("inexact" in flags), sorted(symbols)))
                    target = os.path.join(out, session)
                    os.makedirs(os.path.dirname(target), exist_ok=True)
                    with open(target + ".in", "w", encoding="utf-8") as f:
                        f.write("\n".join(ins) + "\n")
                    with open(target + ".expected", "w", encoding="utf-8") as f:
                        f.write("\n".join(outs) + "\n")
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "index.tsv"), "w", encoding="utf-8") as f:
        f.write("id\tstatus\tsession\tinput\tinexact\tsymbols\n")
        for cid, status, session, j, inexact, symbols in rows:
            f.write("%s\t%s\t%s\t%d\t%d\t%s\n" % (cid, status, session, j, inexact, ",".join(symbols)))
    ok = sum(1 for r in rows if r[1] == "ok")
    print("mathics: %d cases, %d usable; dropped %s" % (len(rows), ok, dropped))


if __name__ == "__main__":
    main()
