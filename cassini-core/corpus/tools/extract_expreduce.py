#!/usr/bin/env python3
"""Turn Expreduce's test cases into sessions (DESIGN.md §7.8, milestone 1c).

Expreduce keeps its tests beside its definitions, in resources/*.m:

    Tests`D = {
        ESimpleExamples[ ESameTest[2x, D[x^2, x]], ... ],
        ETests[ ... ], EKnownFailures[ ... ]
    };

Its runner (expreduce/cas_test.go, TestIncludedModules) evaluates each symbol's
ESimpleExamples, then EFurtherExamples, then ETests, in order, in one state per
module, and EResetState[] clears it. ESameTest[expected, input] evaluates both
and compares them. So each Tests`Name block becomes one session, split at
EResetState[], with one case per ESameTest; EKnownFailures, EKnownDangerous,
EStringTest (printed forms), ENearlySameTest (inexact), EComment and
EExampleOnlyInstruction are not cases.

    extract_expreduce.py VENDOR_DIR OUT_DIR

reads VENDOR_DIR/resources/*.m and writes OUT_DIR/<module>/<Symbol>/<k>.in and
.expected, one session each, and OUT_DIR/index.tsv. An input is kept as the
text Expreduce wrote, on one line, for cassini-corpus to read with Cassini's
own infix parser. ESameTest evaluates its expected side too, and some tests
put the call there and its value in the input, so the expected value is
evaluated once, fully, by Mathics3, as the stand-in for Expreduce, whose own
evaluation is not available; Cassini's would let a bug reproduce on both
sides. A Null is written "-", as a script writes it.

index.tsv has, per case: its ID (expreduce/<module>/<Symbol>/<n>, n counting
the symbol's ESameTests from 1), its status (ok, or unusable with the reason),
its session and input number, whether it holds an inexact number, and the
System symbols its input and expected value mention, which is what the scope
rule reads: those of every input up to its own, since the session's state
carries, and of its expected value. A name the modules define outside their
tests is one of Expreduce's builtins, written in WL, and counts as a System
symbol.

Needs Mathics3, as extract_wolfram_docs.py does, and imports that script's
parser and normalizer.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import extract_wolfram_docs as W  # noqa: E402

# ---------------------------------------------------------------------------
# Reading WL source text: enough to find balanced brackets and top-level
# commas, skipping strings and (nested) comments.


def skip_string(src, i):
    """Index just past the string literal starting at src[i] == '"'."""
    i += 1
    while i < len(src):
        c = src[i]
        if c == "\\":
            i += 2
            continue
        if c == '"':
            return i + 1
        i += 1
    raise ValueError("unterminated string")


def skip_comment(src, i):
    """Index just past the comment starting at src[i:i+2] == '(*'."""
    depth = 0
    while i < len(src):
        if src.startswith("(*", i):
            depth += 1
            i += 2
        elif src.startswith("*)", i):
            depth -= 1
            i += 2
            if depth == 0:
                return i
        else:
            i += 1
    raise ValueError("unterminated comment")


OPEN = {"[": "]", "{": "}", "(": ")"}


def matching(src, i):
    """Index of the bracket closing the one at src[i]."""
    stack = []
    while i < len(src):
        c = src[i]
        if c == '"':
            i = skip_string(src, i)
            continue
        if src.startswith("(*", i):
            i = skip_comment(src, i)
            continue
        if c in OPEN:
            stack.append(OPEN[c])
        elif c in "]})":
            if not stack or stack.pop() != c:
                raise ValueError("unbalanced %r at %d" % (c, i))
            if not stack:
                return i
        i += 1
    raise ValueError("unclosed bracket")


def split_top(src):
    """The top-level comma-separated parts of src, stripped, comments kept."""
    parts, depth, start, i = [], 0, 0, 0
    while i < len(src):
        c = src[i]
        if c == '"':
            i = skip_string(src, i)
            continue
        if src.startswith("(*", i):
            i = skip_comment(src, i)
            continue
        if c in OPEN:
            depth += 1
        elif c in "]})":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append(src[start:i].strip())
            start = i + 1
        i += 1
    last = src[start:].strip()
    if last:
        parts.append(last)
    return parts


def strip_comments(src):
    out, i = [], 0
    while i < len(src):
        if src[i] == '"':
            j = skip_string(src, i)
            out.append(src[i:j])
            i = j
        elif src.startswith("(*", i):
            i = skip_comment(src, i)
            out.append(" ")
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def one_line(src):
    """The text on one line: a newline outside a string is a space; inside
    one it is the escape \\n."""
    out, i = [], 0
    while i < len(src):
        if src[i] == '"':
            j = skip_string(src, i)
            out.append(src[i:j].replace("\r", "").replace("\n", "\\n"))
            i = j
        elif src[i] in "\r\n\t":
            out.append(" ")
            i += 1
        else:
            out.append(src[i])
            i += 1
    return re.sub(r" {2,}", " ", "".join(out)).strip()


def call(text):
    """(head, [args]) of a call written head[args], or None."""
    m = re.match(r"\s*([A-Za-z$][A-Za-z0-9$`]*)\s*\[", text)
    if not m:
        return None
    open_at = m.end() - 1
    close = matching(text, open_at)
    if text[close + 1 :].strip():
        return None
    return m.group(1), split_top(text[open_at + 1 : close])


TESTS = re.compile(r"Tests`([A-Za-z$][A-Za-z0-9$]*)\s*=\s*\{")
ORDER = ["ESimpleExamples", "EFurtherExamples", "ETests"]


def blocks(src):
    """Each Tests`Name block of a module, as (Name, [instruction text]), the
    groups in the runner's order."""
    i = 0
    while True:
        m = TESTS.search(src, i)
        if not m:
            return
        open_at = m.end() - 1
        close = matching(src, open_at)
        groups = {g: [] for g in ORDER}
        for part in split_top(src[open_at + 1 : close]):
            c = call(strip_comments(part).strip())
            if c and c[0] in groups:
                groups[c[0]].extend(c[1])
        yield m.group(1), [x for g in ORDER for x in groups[g]]
        i = close + 1


def sessions(instructions):
    """Split at EResetState[], keeping the ESameTests as (expected, input)."""
    current = []
    for text in instructions:
        c = call(strip_comments(text))
        if c is None:
            continue
        head, args = c
        if head == "EResetState":
            if current:
                yield current
            current = []
        elif head == "ESameTest" and len(args) == 2:
            current.append((args[0], args[1]))
    if current:
        yield current


def system_symbols(text, flags):
    symbols = set()
    W.fullform(W.mparse(text), symbols, flags)
    return symbols


DEFINED = re.compile(r"^\s*(?:Attributes\[)?([A-Za-z$][A-Za-z0-9$]*)(?:::usage|\]\s*=|\[.*?\]\s*:?=)", re.M)


def defined_names(src):
    """The names a module defines outside its tests: Expreduce's builtins,
    written in WL. A case that mentions one depends on Expreduce's own
    definitions, which the session does not have, so the scope rule must see
    it as a System symbol."""
    return set(DEFINED.findall(strip_comments(src)))


def expected_fullform(text, flags, symbols):
    """ESameTest evaluates its expected side as it does its input, so
    Mathics3 evaluates it, fully and once, as the stand-in for Expreduce."""
    e = W.mparse(text)
    try:
        e = W.with_timeout(W.evaluate, e)
    except W.Unusable:
        raise
    except Exception as ex:
        raise W.Unusable("normalizer-error:" + type(ex).__name__)
    out = W.fullform(e, symbols, flags)
    return "-" if out == "Null" else out


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    vendor, out = sys.argv[1], sys.argv[2]
    resources = os.path.join(vendor, "resources")
    docs = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "wolfram-docs")
    # A System symbol Mathics3 does not implement it files under Global`; the
    # Wolfram documentation's page names, where present, catch those.
    if os.path.isdir(docs):
        W.SYSTEM_NAMES.update(n for n in os.listdir(docs) if not n.endswith((".tsv", ".txt")))
    rows = []
    modules = {}
    for name in sorted(os.listdir(resources)):
        if name.endswith(".m") and not name.startswith("rubi"):
            modules[name[:-2]] = open(os.path.join(resources, name), encoding="utf-8").read()
    for src in modules.values():
        W.SYSTEM_NAMES.update(defined_names(src))
    # Expreduce's builtins written in Go are named for it (ExpreduceOrderlessFn,
    # LoadRubiBundledSnapshot); the vendored WL files only call them.
    for src in modules.values():
        W.SYSTEM_NAMES.update(n for n in re.findall(r"[A-Za-z$][A-Za-z0-9$]*", strip_comments(src)) if n.startswith("Expreduce") or "Rubi" in n)
    for module, src in modules.items():
        for symbol, instructions in blocks(src):
            n = 0
            for k, tests in enumerate(sessions(instructions), 1):
                session = "%s/%s/%d" % (module, symbol, k)
                ins, outs = [], []
                # A case depends on every input before it in its session.
                before, before_flags = set(), set()
                for j, (expected, given) in enumerate(tests, 1):
                    n += 1
                    cid = "expreduce/%s/%s/%d" % (module, symbol, n)
                    line = one_line(strip_comments(given))
                    ins.append(line)
                    flags, symbols, status = set(before_flags), set(before), "ok"
                    try:
                        mine = system_symbols(line, flags)
                        before |= mine
                        before_flags |= flags
                        symbols |= mine
                        out_text = expected_fullform(one_line(strip_comments(expected)), flags, symbols)
                        outs.append("Out[%d]: %s" % (j, out_text))
                    except W.Unusable as u:
                        status = "unusable:" + str(u)
                        outs.append("Out[%d]: ?%s" % (j, u))
                    rows.append((cid, status, session, j, int("inexact" in flags), sorted(symbols)))
                path = os.path.join(out, session)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path + ".in", "w", encoding="utf-8") as f:
                    f.write("\n".join(ins) + "\n")
                with open(path + ".expected", "w", encoding="utf-8") as f:
                    f.write("\n".join(outs) + "\n")
    with open(os.path.join(out, "index.tsv"), "w", encoding="utf-8") as f:
        f.write("id\tstatus\tsession\tinput\tinexact\tsymbols\n")
        for cid, status, session, j, inexact, symbols in rows:
            f.write("%s\t%s\t%s\t%d\t%d\t%s\n" % (cid, status, session, j, inexact, ",".join(symbols)))
    ok = sum(1 for r in rows if r[1] == "ok")
    print("expreduce: %d cases, %d usable" % (len(rows), ok))


if __name__ == "__main__":
    main()
