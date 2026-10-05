#!/usr/bin/env bash
# Checks .hlint.yaml's layering rules (DESIGN.md §2.6) against fixture modules:
# every import under lint/fixtures/reported must be reported, and none under
# lint/fixtures/allowed. Run from the repository root.
set -euo pipefail

status=0
restricted() {
  # hlint exits non-zero when it finds hints, so read its output, not its status.
  local out
  out=$(hlint --hint=.hlint.yaml "$1" || true)
  [[ $out == *"Avoid restricted module"* ]]
}
for f in lint/fixtures/reported/*.hs; do
  if restricted "$f"; then
    echo "ok      reported: $f"
  else
    echo "FAIL    not reported: $f"
    status=1
  fi
done
for f in lint/fixtures/allowed/*.hs; do
  if restricted "$f"; then
    echo "FAIL    reported: $f"
    status=1
  else
    echo "ok      allowed: $f"
  fi
done
exit "$status"
