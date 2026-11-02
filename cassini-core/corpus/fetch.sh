#!/usr/bin/env bash
# Clone the fetched corpora at their pinned commits into corpus/fetched/
# (DESIGN.md §7.8, D26), and extract their sessions. Run from cassini-core/.
# The repository holds only these corpora's case IDs, never their content.
#
#   corpus/fetch.sh [PYTHON]
#
# PYTHON is an interpreter with Mathics3 10.0.1 installed (default: python3);
# it reads the test files and normalizes their expected values.
set -euo pipefail

python=${1:-python3}
here=$(cd "$(dirname "$0")" && pwd)
fetched="$here/fetched"
mkdir -p "$fetched"

# Mathics3's own test suite, at the release whose evaluator the oracle runs.
mathics_commit=f6a987e704313e37b2b46ed4fe0b61aab108b58a # tag 10.0.1
if [ ! -d "$fetched/mathics-core/.git" ]; then
  git clone --quiet https://github.com/Mathics3/mathics-core "$fetched/mathics-core"
fi
git -C "$fetched/mathics-core" fetch --quiet --tags
git -C "$fetched/mathics-core" checkout --quiet "$mathics_commit"
rm -rf "$fetched/mathics"
"$python" -I "$here/tools/extract_mathics_tests.py" "$fetched/mathics-core" "$fetched/mathics"
