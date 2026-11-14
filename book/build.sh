#!/usr/bin/env bash
# Build the book. latexmk is not installed, so this runs the passes itself:
# lualatex, bibtex, makeindex, then lualatex until the references settle.
# lualatex needs luaotfload (Arch: texlive-luatex) to load a font.
#
#   ./build.sh           build build/volume2.pdf
#   ./build.sh clean     remove build/
#
# Exits non-zero on a LaTeX error, an undefined reference or citation, or a
# multiply defined label. Overfull boxes are reported and do not fail the build.
set -euo pipefail
cd "$(dirname "$0")"

job=volume2
out=build

if [[ "${1:-}" == clean ]]; then
  rm -rf "$out"
  exit 0
fi

# \include writes each part's .aux beside its source path, under the output directory.
mkdir -p "$out/front" "$out/chapters" "$out/appendices"

run_tex() {
  if ! lualatex -interaction=nonstopmode -halt-on-error -file-line-error \
      -output-directory="$out" "$job.tex" >"$out/tex.out" 2>&1; then
    grep -n -A3 -E '^[^ ]+:[0-9]+: |^! ' "$out/$job.log" || tail -n 30 "$out/tex.out"
    echo "build.sh: lualatex failed; full log in $out/$job.log" >&2
    exit 1
  fi
}

run_tex
# bibtex resolves the \@input lines of the .aux relative to its working directory.
if grep -q '\\citation' "$out"/*.aux "$out"/*/*.aux; then
  (cd "$out" && BIBINPUTS=..: BSTINPUTS=..: bibtex -terse "$job")
fi
if [[ -s "$out/$job.idx" ]]; then
  makeindex -q -o "$out/$job.ind" "$out/$job.idx"
fi

for _ in 1 2 3 4; do
  run_tex
  grep -q -E 'Rerun to get|Label\(s\) may have changed' "$out/$job.log" || break
done

status=0
if grep -E 'LaTeX Warning: (Reference|Citation) .* undefined|multiply defined|There were undefined' "$out/$job.log"; then
  echo "build.sh: undefined or duplicate references" >&2
  status=1
fi
if grep -q 'Rerun to get' "$out/$job.log"; then
  echo "build.sh: references did not settle in five passes" >&2
  status=1
fi
grep -E '^(Overfull|Underfull) \\[hv]box' "$out/$job.log" | sort | uniq -c || true
grep -E '^(LaTeX|Package|Class) .*Warning' "$out/$job.log" || true
grep -E '^Output written' "$out/$job.log" || true
exit $status
