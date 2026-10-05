#!/usr/bin/env python3
"""Fail if any benchmark allocates more than its committed baseline allows.

DESIGN.md §8.1 and §8.6: tasty-bench's --fail-if-slower thresholds time only,
so the allocation gate is this diff of the CSV's Allocated column. Allocation
is deterministic for a given compiler and flags, so any machine's baseline is
valid for the same GHC.

    check-allocation.py BASELINE.csv CURRENT.csv [--threshold PERCENT]
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
    args = parser.parse_args()

    baseline = allocations(args.baseline)
    current = allocations(args.current)
    failed = False
    for name, base in sorted(baseline.items()):
        if name not in current:
            print(f"missing   {name}")
            failed = True
            continue
        now = current[name]
        change = 100.0 * (now - base) / base if base else (0.0 if now == 0 else float("inf"))
        over = change > args.threshold
        failed |= over
        print(f"{'FAIL' if over else 'ok':8}  {change:+7.1f}%  {now:>14,}  {name}")
    for name in sorted(current.keys() - baseline.keys()):
        print(f"new       {name}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
