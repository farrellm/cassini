#!/usr/bin/env python3
"""Extract the Wolfram documentation corpus (DESIGN.md §7.9, milestone W).

Reads the reference-page notebooks of the documentation that comes with a
Mathematica licence, turns every example into a session of FullForm inputs with
their documented outputs and messages, and writes them under OUT_DIR, which
must be gitignored: the corpus is never committed (D27). No Wolfram kernel is
needed or used.

    extract_wolfram_docs.py NOTEBOOK_DIR OUT_DIR [--jobs N] [--limit N] [--only A,B]

NOTEBOOK_DIR is searched recursively. Pages are recognized by content, not by
path, so it may be an installation's Documentation directory or the files
unpacked from the offline documentation installer, whose names are opaque.

Needs Mathics3 (`pip install Mathics3`, tested with 10.0.1, whose builtins
must be loaded explicitly before a session starts). Mathics3 parses
the input text the boxes are flattened into, and normalizes each output by
evaluating it once with every head except arithmetic made inert (§7.9).
"""

import argparse
import collections
import datetime
import multiprocessing
import os
import re
import sys

# ---------------------------------------------------------------------------
# Notebook reading: a tolerant parser for the Notebook[...] expression.
#
# Nodes: ("s", raw) a string literal, still escaped; ("a", text) any other
# token run; ("c", head, args) a call; ("l", items) a list;
# ("x", items) an argument made of several tokens (infix, options).

TOKEN = re.compile(
    r'"(?:[^"\\]|\\.)*"'  # string literal
    r"|\(\*.*?\*\)"  # comment
    r"|[\[\]{},]"  # structure
    r'|[^\s"\[\]{},]+',  # anything else
    re.S,
)

END_OF_CONTENT = "(* End of Notebook Content *)"


def parse_notebook(src):
    stack = [("root", [], [], None)]  # (kind, args, current-arg items, (head, position))
    for m in TOKEN.finditer(src):
        t = m.group()
        c = t[0]
        if c == "(" and t.startswith("(*"):
            continue
        kind, args, cur, _ = stack[-1]
        if t == "[":
            # A call: the head is the item just before, if adjacent.
            if cur and m.start() > 0 and not src[m.start() - 1].isspace():
                head = cur.pop()
            else:
                head = ("a", "")
            stack.append(("c", [], [], (head, m.end())))
        elif t == "{":
            stack.append(("l", [], [], (None, m.end())))
        elif t == ",":
            args.append(_arg(cur))
            stack[-1] = (kind, args, [], stack[-1][3])
        elif t in "]}":
            if len(stack) == 1:
                continue
            kind, args, cur, (head, _start) = stack.pop()
            if cur or args:
                args.append(_arg(cur))
            node = ("c", head, args) if kind == "c" else ("l", args)
            stack[-1][2].append(node)
        elif c == '"':
            cur.append(("s", t))
        else:
            cur.append(("a", t))
    return stack[0][2]


def _arg(items):
    if len(items) == 1:
        return items[0]
    return ("x", items)


def head_name(node):
    if node[0] == "c" and node[1][0] == "a":
        return node[1][1]
    return None


def string_value(node):
    """The value of a notebook string literal, as source text for WL."""
    raw = node[1][1:-1]
    out = []
    i = 0
    while i < len(raw):
        ch = raw[i]
        if ch == "\\" and i + 1 < len(raw):
            nxt = raw[i + 1]
            if nxt == '"':
                out.append('"')
                i += 2
                continue
            if nxt == "\\":
                out.append("\\")
                i += 2
                continue
            if nxt == "n":
                out.append("\n")
                i += 2
                continue
            if nxt in "<>":  # multi-line string markers
                i += 2
                continue
        out.append(ch)
        i += 1
    return "".join(out)


# ---------------------------------------------------------------------------
# Boxes to input text.


class Unusable(Exception):
    """A cell the corpus cannot use, with the reason."""


LONG_NAMES = {
    "ImaginaryI": " I ",
    "ImaginaryJ": " I ",
    "ExponentialE": " E ",
    "LeftDoubleBracket": "[[",
    "RightDoubleBracket": "]]",
    "InvisibleTimes": " ",
    "InvisibleSpace": " ",
    "InvisibleComma": ",",
    "InvisibleApplication": " ",
    "NonBreakingSpace": " ",
    "VeryThinSpace": " ",
    "ThinSpace": " ",
    "MediumSpace": " ",
    "ThickSpace": " ",
    "NegativeVeryThinSpace": " ",
    "NegativeThinSpace": " ",
    "NegativeMediumSpace": " ",
    "NegativeThickSpace": " ",
    "IndentingNewLine": "\n",
    "Times": "*",
    "Divide": "/",
    "Minus": "-",
    "Degree": " Degree ",
}

# Long names that mean an operator Mathics3 does not parse, or notation with
# no linear equivalent here.
UNPARSED_LONG_NAMES = {"Element", "NotElement", "DifferentialD", "Integral", "Sum", "Product"}

LONG_NAME = re.compile(r"\\\[([A-Za-z]+)\]")


def token_text(s):
    if s.startswith("\\!") or "\\!\\(" in s:
        raise Unusable("inline-box-string")

    def sub(m):
        name = m.group(1)
        if name in UNPARSED_LONG_NAMES:
            raise Unusable("long-name:" + name)
        return LONG_NAMES.get(name, m.group(0))

    return LONG_NAME.sub(sub, s)


PRIME = {"\\[Prime]": "'", "\\[Prime]\\[Prime]": "''", "\\[DoublePrime]": "''"}

# Heads that are display only: their first argument is the content.
TRANSPARENT = {"StyleBox", "AdjustmentBox", "BoxData", "ErrorBox"}


def lin(node):
    k = node[0]
    if k == "s":
        return token_text(string_value(node))
    if k != "c":
        raise Unusable("box-shape:" + k)
    h = head_name(node)
    args = node[2]
    if h == "RowBox":
        if not args or args[0][0] != "l":
            raise Unusable("box-shape:RowBox")
        return " ".join(lin(a) for a in args[0][1])
    if h == "BoxData" and args and args[0][0] == "l":
        return multiline(args[0][1])
    if h in TRANSPARENT:
        if not args:
            raise Unusable("box-shape:" + h)
        return lin(args[0])
    if h == "SuperscriptBox":
        base, sup = args[0], args[1]
        if sup[0] == "s":
            p = PRIME.get(string_value(sup))
            if p is not None:
                return lin(base) + p
            if string_value(sup) in ("\\[Transpose]", "\\[ConjugateTranspose]", "*", "\\[Dagger]", "\\[HermitianConjugate]"):
                raise Unusable("superscript-operator")
        return "(" + lin(base) + ")^(" + lin(sup) + ")"
    if h == "FractionBox":
        return "((" + lin(args[0]) + ")/(" + lin(args[1]) + "))"
    if h == "SqrtBox":
        return "Sqrt[" + lin(args[0]) + "]"
    if h == "RadicalBox":
        return "((" + lin(args[0]) + ")^(1/(" + lin(args[1]) + ")))"
    if h == "FormBox":
        fmt = args[1][1] if len(args) > 1 and args[1][0] == "a" else ""
        if fmt in ("TraditionalForm", "TextForm"):
            raise Unusable("form-box:" + fmt)
        return lin(args[0])
    if h == "InterpretationBox":
        # The second argument is the expression itself, in InputForm.
        if len(args) < 2:
            raise Unusable("box-shape:InterpretationBox")
        raise _Interpretation(args[1])
    if h == "TagBox":
        tag = args[1] if len(args) > 1 else ("a", "")
        tag_s = tag[1] if tag[0] == "a" else (string_value(tag) if tag[0] == "s" else head_name(tag) or tag[0])
        if tag_s in ("HoldForm",):
            return "HoldForm[" + lin(args[0]) + "]"
        if tag_s in ("Null", "InputForm", "FullForm", "\"InputForm\""):
            return lin(args[0])
        raise Unusable("TagBox:" + str(tag_s)[:40])
    if h == "TemplateBox":
        names = [string_value(a) for a in args[1:] if a[0] == "s"]
        raise Unusable("TemplateBox:" + (names[0] if names else "?"))
    raise Unusable("box:" + str(h))


NEWLINES = {"\n", "\\[IndentingNewLine]"}


def multiline(items):
    """A cell of several lines. When every line but the last ends in `;`, the
    cell's one output is the last line's value, which is what joining them
    into one CompoundExpression gives; otherwise the cell is unusable."""
    lines = [lin(x) for x in items if not (x[0] == "s" and string_value(x) in NEWLINES)]
    if not lines:
        raise Unusable("box-shape:empty")
    if any(not t.rstrip().endswith(";") for t in lines[:-1]):
        raise Unusable("multi-expression-cell")
    return " ".join(lines)


class _Interpretation(Exception):
    """An InterpretationBox: the expression is given, not its display."""

    def __init__(self, node):
        self.node = node


def node_source(node):
    """Re-serialize a parsed InputForm node (for InterpretationBox)."""
    k = node[0]
    if k == "s":
        return node[1]
    if k == "a":
        return node[1]
    if k == "x":
        return " ".join(node_source(n) for n in node[1])
    if k == "l":
        return "{" + ", ".join(node_source(n) for n in node[1]) + "}"
    return node_source(node[1]) + "[" + ", ".join(node_source(a) for a in node[2]) + "]"


def cell_text(box):
    """The input text of a cell's boxes, or Unusable."""
    try:
        return lin(box)
    except _Interpretation as i:
        # The notebook's cell context is the session's Global` context.
        return node_source(i.node).replace("$CellContext`", "")


# ---------------------------------------------------------------------------
# Walking a reference page into examples.

SECTION_STYLES = ("ExampleSection", "ExampleSubsection", "ExampleSubsubsection")
LABEL = re.compile(r"(In|Out)\[(\d+)\](//(\w+))?")
DURING = re.compile(r"During evaluation of In\[(\d+)\]")


def cell_parts(node):
    """(content, style, label) for a Cell call, else None."""
    if head_name(node) != "Cell" or not node[2]:
        return None
    args = node[2]
    style = args[1] if len(args) > 1 and args[1][0] == "s" else None
    label = None
    for a in args[2:]:
        if a[0] == "x" and a[1] and a[1][0] == ("a", "CellLabel->") and len(a[1]) > 1 and a[1][1][0] == "s":
            label = string_value(a[1][1])
    return args[0], (string_value(style) if style else None), label


def section_title(content):
    """First plain string in a section cell's TextData."""
    stack = [content]
    while stack:
        n = stack.pop(0)
        if n[0] == "s":
            t = string_value(n).strip()
            if t and not t.startswith("\\["):
                return t
        elif n[0] == "l":
            stack = list(n[1]) + stack
        elif n[0] == "c" and head_name(n) in ("TextData",):
            stack = list(n[2]) + stack
    return "Untitled"


def walk_cells(nodes):
    """Yield (content, style, label) for each leaf cell in document order."""
    stack = list(reversed(nodes))
    while stack:
        n = stack.pop()
        if n[0] == "l":
            stack.extend(reversed(n[1]))
            continue
        if n[0] != "c":
            continue
        h = head_name(n)
        if h == "Notebook":
            stack.extend(reversed(n[2][:1]))
            continue
        if h == "Cell":
            content = n[2][0] if n[2] else None
            if content is not None and head_name(content) == "CellGroupData":
                stack.extend(reversed(content[2][:1]))
                continue
            parts = cell_parts(n)
            if parts:
                yield parts


def page_examples(nodes):
    """Group a page's example cells into sessions."""
    examples = []
    sections = []  # stack of titles, by level
    counters = collections.Counter()
    current = None
    in_examples = False

    def new_example():
        nonlocal current
        path = "/".join(sanitize(t) for t in sections) or "Examples"
        # Numbered by the sanitized path: two headings can differ only in an
        # inline formula that sanitizing drops.
        counters[path] += 1
        current = {"section": path, "n": counters[path], "cells": []}
        examples.append(current)

    for content, style, label in walk_cells(nodes):
        if style == "PrimaryExamplesSection":
            in_examples = True
            continue
        if not in_examples or style is None:
            continue
        if style in SECTION_STYLES:
            level = SECTION_STYLES.index(style)
            sections[level:] = [section_title(content)]
            current = None
            continue
        if style == "ExampleDelimiter":
            current = None
            continue
        if style in ("Input", "Output", "Message", "Print"):
            if current is None:
                new_example()
            current["cells"].append((style, content, label))
    return [e for e in examples if any(c[0] == "Input" for c in e["cells"])]


# ---------------------------------------------------------------------------
# Mathics3: parsing, FullForm, and output normalization.

ARITHMETIC = {"Plus", "Times", "Power", "Sqrt", "Rational", "Complex", "DirectedInfinity", "Minus", "Subtract", "Divide", "List"}
INERT = "CassiniInert`"

_session = None


def session():
    global _session
    if _session is None:
        import io
        import contextlib

        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            from mathics.core.load_builtin import import_and_load_builtins

            import_and_load_builtins()
            from mathics.session import MathicsSession

            _session = MathicsSession()
    return _session


def mparse(text):
    from mathics.core.parser import parse
    from mathics_scanner.feed import SingleLineFeeder

    try:
        e = parse(session().definitions, SingleLineFeeder(text, "<doc>"))
    except Exception as ex:  # the scanner raises several kinds
        raise Unusable("parse:" + type(ex).__name__)
    if e is None:
        raise Unusable("parse:empty")
    return e


def short(name):
    for ctx in ("System`", "Global`"):
        if name.startswith(ctx):
            return name[len(ctx):]
    return name


def fullform(e, symbols=None, flags=None):
    """WL FullForm text of a Mathics3 expression; collects System symbols."""
    from mathics.core.atoms import Complex, Integer, Rational, Real, String

    if isinstance(e, Integer):
        return str(e.value)
    if isinstance(e, Rational):
        v = e.value
        return "Rational[%d, %d]" % (v.p, v.q)
    if isinstance(e, Real):
        if flags is not None:
            flags.add("inexact")
        v = e.value
        if isinstance(v, float):
            return repr(v)
        # A decimal rendering of an arbitrary-precision real with a huge
        # binary exponent or precision runs for minutes; inexact numbers are
        # out of scope anyway (D9), so such a number costs its cell, not the run.
        mpf = getattr(v, "_mpf_", None)
        if (mpf is not None and abs(mpf[2]) > 100000) or getattr(v, "_prec", 0) > 100000:
            raise Unusable("huge-real")
        return str(e)
    if isinstance(e, Complex):
        return "Complex[%s, %s]" % (fullform(e.real, symbols, flags), fullform(e.imag, symbols, flags))
    if isinstance(e, String):
        v = e.value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return '"' + v + '"'
    if hasattr(e, "elements"):
        return fullform(e.head, symbols, flags) + "[" + ", ".join(fullform(x, symbols, flags) for x in e.elements) + "]"
    name = e.get_name()
    if symbols is not None:
        # Mathics3 puts a System symbol it does not implement in Global`, so
        # the documentation's own list of symbols decides as well.
        if name.startswith("System`") or (name.startswith("Global`") and short(name) in SYSTEM_NAMES):
            symbols.add(short(name))
    return short(name)


# Every symbol with a reference page, filled in before any page is processed.
SYSTEM_NAMES = set()


def inert(e, hold_attrs):
    """Replace every non-arithmetic symbol head by an inert copy."""
    from mathics.core.expression import Expression
    from mathics.core.symbols import Symbol

    if not hasattr(e, "elements"):
        return e
    head = e.head
    if hasattr(head, "elements"):
        new_head = inert(head, hold_attrs)
    else:
        name = head.get_name()
        if short(name) in ARITHMETIC and name.startswith("System`"):
            new_head = head
        else:
            inert_name = INERT + name.replace("`", "$")
            if inert_name not in hold_attrs:
                hold_attrs[inert_name] = name
                _copy_hold_attributes(name, inert_name)
            new_head = Symbol(inert_name)
    return Expression(new_head, *[inert(x, hold_attrs) for x in e.elements])


def _copy_hold_attributes(name, inert_name):
    from mathics.core import attributes as A

    defs = session().definitions
    try:
        attrs = defs.get_attributes(name)
    except Exception:
        attrs = 0
    keep = attrs & (A.A_HOLD_ALL | A.A_HOLD_FIRST | A.A_HOLD_REST | A.A_HOLD_ALL_COMPLETE | A.A_SEQUENCE_HOLD)
    defs.set_attributes(inert_name, keep)


def restore(e, names):
    from mathics.core.expression import Expression
    from mathics.core.symbols import Symbol

    if hasattr(e, "elements"):
        return Expression(restore(e.head, names), *[restore(x, names) for x in e.elements])
    if not hasattr(e, "get_name"):
        return e
    n = e.get_name()
    return Symbol(names[n]) if n in names else e


def evaluate(e):
    from mathics.core.evaluation import Evaluation

    ev = Evaluation(session().definitions, output=None, catch_interrupt=False)
    return e.evaluate(ev)


MAX_TEXT = 20000
TIMEOUT_SECONDS = 5


class _Timeout(BaseException):
    """Raised by SIGALRM. A BaseException, so Mathics3's handlers cannot catch it."""


def _alarm(signum, frame):
    raise _Timeout()


def with_timeout(f, *args):
    import signal

    old = signal.signal(signal.SIGALRM, _alarm)
    signal.setitimer(signal.ITIMER_REAL, TIMEOUT_SECONDS)
    try:
        return f(*args)
    except _Timeout:
        raise Unusable("timeout")
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, old)


def normalize_output(text, flags, symbols=None):
    """FullForm of a documented output, arithmetic re-canonicalized."""
    if len(text) > MAX_TEXT:
        raise Unusable("size")
    e = mparse(text)
    names = {}
    try:
        once = with_timeout(evaluate, inert(e, names))
        twice = with_timeout(evaluate, once)
        a = fullform(once)
        if fullform(twice) != a:
            raise Unusable("not-fixed-point")
        result = fullform(restore(once, names), symbols, flags)
    except Unusable:
        raise
    except Exception as ex:  # Mathics3's own errors: the output, not the page, is lost
        raise Unusable("normalizer-error:" + type(ex).__name__)
    if MODULE_LOCAL.search(result):
        raise Unusable("module-local-name")
    return result


# Module's locals are named x$nnn from $ModuleNumber, which depends on the whole
# session history of the kernel that built the page (§4.13).
MODULE_LOCAL = re.compile(r"[A-Za-z][A-Za-z0-9]*\$\d+\b")


# ---------------------------------------------------------------------------
# One page.


def message_tag(content):
    box = content[2][0] if content[0] == "c" and head_name(content) == "BoxData" and content[2] else content
    if head_name(box) == "TemplateBox" and len(box[2]) > 1 and box[2][1][0] == "s" and string_value(box[2][1]) == "MessageTemplate":
        items = box[2][0][1] if box[2][0][0] == "l" else []
        if len(items) >= 2 and items[0][0] == "s" and items[1][0] == "s":
            return string_value(items[0]) + "::" + string_value(items[1])
    raise Unusable("message-shape")


def sanitize(s):
    s = re.sub(r"[^A-Za-z0-9$]+", "", s.title().replace("&", "And"))
    return s or "Untitled"


CONTINUATION = re.compile(r"\\\r?\n")


# Every page's "Copy Wolfram Documentation Center URL" action names its own
# URL, which tells apart variant pages sharing a window title
# (`ref/blockchain/BlockchainData-Bitcoin` beside `ref/BlockchainData`).
PAGE_URL = re.compile(r'"http://reference\.wolfram\.com/language/"\]\s*<>\s*"ref/([^"]+)"')
PACLET = re.compile(r'"paclet" -> "([^"]*)"')


def page_identity(src):
    m = PAGE_URL.search(src)
    return m.group(1) if m else None


def select_pages(paths):
    """The built-in symbol pages among paths, one per identity. A few pages
    ship twice under one URL; the copy tagged with the Mathematica paclet is
    kept. Returns the kept paths, the number of duplicates dropped, and every
    page's symbol."""
    best = {}
    names = set()
    pages = 0
    for p in paths:
        with open(p, encoding="utf-8", errors="replace") as h:
            src = h.read()
        if 'Cell["BUILT-IN SYMBOL", "PacletNameCell"' not in src:
            continue
        pages += 1
        sym = page_symbol(src)
        if sym:
            names.add(sym)
        ident = page_identity(src) or sym or p
        m = PACLET.search(src)
        rank = 1 if m and m.group(1) == "Mathematica" else 0
        if ident not in best or rank > best[ident][0]:
            best[ident] = (rank, p)
    kept = sorted(p for _, p in best.values())
    return kept, pages - len(kept), names


def page_symbol(src):
    """The symbol a page documents: its window title, minus any operator form ("Plus (+)")."""
    t = re.search(r"WindowTitle->(\S+)", src[:5000])
    return t.group(1) if t else None


def process_page(path):
    """Returns (symbol, [case records]) or None if not a built-in symbol page."""
    with open(path, encoding="utf-8", errors="replace") as h:
        src = h.read()
    if 'Cell["BUILT-IN SYMBOL", "PacletNameCell"' not in src:
        return None
    symbol = page_symbol(src) or os.path.basename(path)
    built = re.search(r"CreatedBy='([^']*)'", src[:2000])
    page = page_identity(src) or symbol
    end = src.find(END_OF_CONTENT)
    if end > 0:
        src = src[:end]
    # The file format breaks long lines with a backslash-newline continuation,
    # inside strings and numbers alike.
    src = CONTINUATION.sub("", src)
    nodes = parse_notebook(src)
    cases = []
    for ex in page_examples(nodes):
        cases.append(process_example(page, ex))
    return symbol, cases, built.group(1) if built else "unknown"


def process_example(page, ex):
    case_id = "wolfram/%s/%s/%d" % (page, ex["section"], ex["n"])
    inputs = []  # (k, fullform)
    outputs = {}  # k -> fullform | Unusable reason
    messages = collections.defaultdict(list)
    prints = 0
    reasons = collections.Counter()
    symbols = set()
    flags = set()
    status = "ok"
    k_seen = 0
    for style, content, label in ex["cells"]:
        if style == "Input":
            m = LABEL.match(label or "")
            k = int(m.group(2)) if m else k_seen + 1
            k_seen = k
            try:
                text = cell_text(content)
                if len(text) > MAX_TEXT:
                    raise Unusable("size")
                inputs.append((k, fullform(mparse(text), symbols, flags)))
            except Unusable as u:
                reasons["input:" + str(u)] += 1
                status = "unusable"
                inputs.append((k, None))
        elif style == "Output":
            m = LABEL.match(label or "")
            k = int(m.group(2)) if m else k_seen
            form = m.group(4) if m else None
            try:
                if form and form not in ("InputForm", "FullForm"):
                    raise Unusable("form:" + form)
                outputs[k] = normalize_output(cell_text(content), flags, symbols)
            except Unusable as u:
                reasons["output:" + str(u)] += 1
                outputs[k] = u
        elif style == "Message":
            m = DURING.search(label or "")
            k = int(m.group(1)) if m else k_seen
            try:
                messages[k].append(message_tag(content))
            except Unusable as u:
                reasons["message:" + str(u)] += 1
                messages[k].append(u)
        elif style == "Print":
            prints += 1
    if status == "ok" and any(isinstance(v, Unusable) for v in outputs.values()):
        status = "partial"
    if status == "ok" and any(isinstance(v, Unusable) for vs in messages.values() for v in vs):
        status = "partial"
    usable_outputs = sum(1 for v in outputs.values() if not isinstance(v, Unusable))
    return {
        "id": case_id,
        "status": status,
        "inputs": inputs,
        "outputs": outputs,
        "messages": dict(messages),
        "prints": prints,
        "reasons": reasons,
        "symbols": sorted(symbols),
        "inexact": "inexact" in flags,
        "n_outputs": len(outputs),
        "n_usable_outputs": usable_outputs,
    }


def worker(path):
    try:
        return path, process_page(path), None
    except Exception as ex:  # a page that breaks the extractor is reported, not fatal
        return path, None, "%s: %s" % (type(ex).__name__, ex)


PAGE_TIMEOUT_SECONDS = 300


def _serve(tasks, results, system_names):
    SYSTEM_NAMES.update(system_names)
    while True:
        path = tasks.get()
        if path is None:
            return
        results.put(worker(path))


def run_pages(paths, jobs, system_names):
    """Yield worker(path) for every path, in parallel. A worker still on one
    page after PAGE_TIMEOUT_SECONDS is killed and the page reported as failed:
    a hang inside compiled code never returns to Python, so the per-output
    alarm cannot reach it."""
    import queue
    import time

    results = multiprocessing.Queue()
    pending = list(reversed(paths))
    workers = {}  # id -> [process, task queue, path, started]

    def spawn(i):
        tasks = multiprocessing.Queue()
        proc = multiprocessing.Process(target=_serve, args=(tasks, results, system_names), daemon=True)
        proc.start()
        workers[i] = [proc, tasks, None, 0.0]

    def assign(i):
        w = workers[i]
        if pending:
            w[2] = pending.pop()
            w[3] = time.monotonic()
            w[1].put(w[2])
        else:
            w[2] = None

    for i in range(jobs):
        spawn(i)
        assign(i)
    while any(w[2] is not None for w in workers.values()):
        try:
            path, result, err = results.get(timeout=1)
        except queue.Empty:
            now = time.monotonic()
            for i, w in list(workers.items()):
                if w[2] is not None and now - w[3] > PAGE_TIMEOUT_SECONDS:
                    stuck = w[2]
                    w[0].kill()
                    spawn(i)
                    assign(i)
                    yield stuck, None, "page-timeout"
            continue
        for i, w in workers.items():
            if w[2] == path:
                assign(i)
                break
        yield path, result, err
    for w in workers.values():
        w[1].put(None)


# ---------------------------------------------------------------------------
# Output.


def write_case(out_dir, case):
    rel = case["id"][len("wolfram/"):]
    base = os.path.join(out_dir, rel)
    os.makedirs(os.path.dirname(base), exist_ok=True)
    with open(base + ".in", "w") as f:
        for k, ff in case["inputs"]:
            f.write(ff + "\n")
    with open(base + ".expected", "w") as f:
        for k, _ in case["inputs"]:
            out = case["outputs"].get(k)
            if out is None:
                f.write("Out[%d]: -\n" % k)
            elif isinstance(out, Unusable):
                f.write("Out[%d]: ?%s\n" % (k, out))
            else:
                f.write("Out[%d]: %s\n" % (k, out))
            for msg in case["messages"].get(k, []):
                f.write("Message[%d]: %s\n" % (k, ("?" + str(msg)) if isinstance(msg, Unusable) else msg))


def find_notebooks(root):
    for d, _, files in os.walk(root):
        for f in files:
            p = os.path.join(d, f)
            try:
                with open(p, "rb") as h:
                    if b"application/vnd.wolfram.mathematica" in h.read(200):
                        yield p
            except OSError:
                pass


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("notebook_dir")
    ap.add_argument("out_dir")
    ap.add_argument("--jobs", type=int, default=os.cpu_count())
    ap.add_argument("--limit", type=int, default=0, help="stop after N notebooks (for trial runs)")
    ap.add_argument("--only", default="", help="comma-separated symbol names to extract")
    a = ap.parse_args()

    notebooks = sorted(find_notebooks(a.notebook_dir))
    paths, duplicates, system_names = select_pages(notebooks)
    if a.only:
        wanted = set(a.only.split(","))
        keep = []
        for p in paths:
            with open(p, encoding="utf-8", errors="replace") as h:
                head = h.read(3000)
            if page_symbol(head) in wanted:
                keep.append(p)
        paths = keep
    if a.limit:
        paths = paths[: a.limit]

    os.makedirs(a.out_dir, exist_ok=True)
    totals = collections.Counter()
    reasons = collections.Counter()
    versions = collections.Counter()
    failures = []
    started = datetime.datetime.now(datetime.timezone.utc)
    with open(os.path.join(a.out_dir, "index.tsv"), "w") as index:
        index.write("id\tstatus\tinputs\toutputs\tusable_outputs\tmessages\tprints\tinexact\tsymbols\treasons\n")
        for n, (path, result, err) in enumerate(run_pages(paths, a.jobs, system_names), 1):
            if err:
                failures.append((path, err))
                continue
            if result is None:
                continue
            symbol, cases, built = result
            versions[built] += 1
            totals["pages"] += 1
            if not cases:
                totals["pages_without_examples"] += 1
            for c in cases:
                totals["examples"] += 1
                totals["examples_" + c["status"]] += 1
                totals["inputs"] += len(c["inputs"])
                totals["outputs"] += c["n_outputs"]
                totals["usable_outputs"] += c["n_usable_outputs"] if c["status"] != "unusable" else 0
                reasons.update(c["reasons"])
                if c["status"] != "unusable":
                    write_case(a.out_dir, c)
                n_msgs = sum(len(v) for v in c["messages"].values())
                index.write(
                    "\t".join(
                        [
                            c["id"],
                            c["status"],
                            str(len(c["inputs"])),
                            str(c["n_outputs"]),
                            str(c["n_usable_outputs"]),
                            str(n_msgs),
                            str(c["prints"]),
                            "1" if c["inexact"] else "0",
                            ",".join(c["symbols"]),
                            ",".join("%s=%d" % kv for kv in sorted(c["reasons"].items())),
                        ]
                    )
                    + "\n"
                )
            if n % 500 == 0:
                print("%d notebooks, %d pages" % (n, totals["pages"]), file=sys.stderr)

    import mathics

    with open(os.path.join(a.out_dir, "run.txt"), "w") as f:
        f.write("extracted: %s\n" % started.isoformat(timespec="seconds"))
        f.write("extractor: corpus/tools/extract_wolfram_docs.py\n")
        f.write("normalizer: Mathics3 %s\n" % mathics.__version__)
        f.write("source: %s\n" % os.path.abspath(a.notebook_dir))
        for v, c in versions.most_common():
            f.write("documentation: %s (%d pages)\n" % (v, c))
        f.write("\n")
        for k in (
            "pages",
            "pages_without_examples",
            "examples",
            "examples_ok",
            "examples_partial",
            "examples_unusable",
            "inputs",
            "outputs",
            "usable_outputs",
        ):
            f.write("%s: %d\n" % (k, totals[k]))
        f.write("duplicate_pages_dropped: %d\n" % duplicates)
        f.write("extractor_failures: %d\n" % len(failures))
        f.write("\nreasons:\n")
        for r, c in reasons.most_common():
            f.write("  %8d %s\n" % (c, r))
        if failures:
            f.write("\nfailures:\n")
            for p, e in failures:
                f.write("  %s %s\n" % (p, e))
    print(open(os.path.join(a.out_dir, "run.txt")).read())


if __name__ == "__main__":
    main()
