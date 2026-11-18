#!/usr/bin/env bash
# prefight.sh <fixed-point>: the Leak check deathmatch runs before any opponent
# fights. Each added line that holds a path into a home folder, a Nix store
# path or a private key prints as <file>:<line>, and the script exits 1. A
# clean diff exits 0.
set -u
base=${1:?usage: prefight.sh <fixed-point>}
leak='/(home|Users)/[[:alnum:]_.-]+|/nix/sto[r]e/|-----BEGIN [A-Z ]*PRIVATE KEY'
found=0
while IFS= read -r f; do
  while IFS= read -r n; do
    echo "leak: $f:$n"
    found=1
  done < <(git diff -U0 "$base"...HEAD -- "$f" | awk -v pat="$leak" '
    /^@@/ { split($3, a, ","); line = substr(a[1], 2) + 0; next }
    /^\+\+\+/ { next }
    /^\+/ { if ($0 ~ pat) print line; line++ }')
done < <(git diff --name-only --diff-filter=AMR "$base"...HEAD)
exit "$found"
