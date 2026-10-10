#!/usr/bin/env python3
"""Fail if any benchmark allocates more than its committed baseline allows.

DESIGN.md §8.1 and §8.6: tasty-bench's --fail-if-slower thresholds time only,
so the allocation gate is this diff of the CSV's Allocated column. Allocation
depends on the compiler, the flags and the library's optimization level, not on
the machine, so any machine's baseline is valid for the same GHC if it was built
the same way: plain `cabal bench`, whose library is at cabal's default
optimization. `cabal bench -O2` changes some figures by large factors. Under the
`intern` flag allocation also varies by a few percent between runs, with
garbage-collection timing; the threshold absorbs that.

    check-allocation.py BASELINE.csv CURRENT.csv [--threshold PERCENT] [--slack BYTES] [--only PREFIX]

A benchmark fails only when it is over by more than the threshold *and* by more
than the slack. Near-zero baselines (a few bytes of stack growth or
bookkeeping per iteration) would otherwise fail on noise: against a baseline
of 0, any allocation at all is an infinite percentage.

--only restricts the check to the benchmarks whose names start with PREFIX.
CI gates on the end-to-end workload alone (`--only All.EndToEnd`): §8.6 makes
it the number CI gates on, and the microbenchmarks advisory.
"""

import argparse
import csv
import sys


def allocations(path):
    with open(path, newline="") as f:
        return {row["Name"]: int(row["Allocated"]) for row in csv.DictReader(f)}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("baseline")
    parser.add_argument("current")
    parser.add_argument("--threshold", type=float, default=10.0, help="percent over baseline allowed")
    parser.add_argument("--slack", type=int, default=1024, help="bytes over baseline always allowed")
    parser.add_argument("--only", default="", help="check only benchmarks whose names start with this")
    args = parser.parse_args()

    baseline = {k: v for k, v in allocations(args.baseline).items() if k.startswith(args.only)}
    current = {k: v for k, v in allocations(args.current).items() if k.startswith(args.only)}
    if not baseline:
        print(f"no baseline benchmark starts with {args.only!r}")
        sys.exit(1)
    failed = False
    for name, base in sorted(baseline.items()):
        if name not in current:
            print(f"missing   {name}")
            failed = True
            continue
        now = current[name]
        change = 100.0 * (now - base) / base if base else (0.0 if now == 0 else float("inf"))
        over = change > args.threshold and now - base > args.slack
        failed |= over
        print(f"{'FAIL' if over else 'ok':8}  {change:+7.1f}%  {now:>14,}  {name}")
    for name in sorted(current.keys() - baseline.keys()):
        print(f"new       {name}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
