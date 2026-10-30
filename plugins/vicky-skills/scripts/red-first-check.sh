#!/usr/bin/env bash
# Proves each approved-examples test a branch adds was red when it landed:
# it checks out the commit that added the test in a scratch clone and runs
# the test there. The check fails when one passed at that commit, since its
# code was there first.
# Usage: red-first-check.sh <base> [<head>] [--run '<command, {} for the test>']
# The run command defaults to `bash {}`, from the clone's root.
set -u
run='bash {}'
args=()
while [ $# -gt 0 ]; do
  case "$1" in --run) run=$2; shift 2 ;; *) args+=("$1"); shift ;; esac
done
[ ${#args[@]} -ge 1 ] || { echo "usage: red-first-check.sh <base> [<head>] [--run '<command>']" >&2; exit 2; }
base=${args[0]}; head=${args[1]:-HEAD}
repo=$(git rev-parse --show-toplevel) || exit 2
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
git clone -q --no-local --no-checkout "$repo" "$scratch/clone" || exit 2
fail=0 checked=0
while IFS=$'\t' read -r sha file; do
  [ -n "$file" ] || continue
  checked=$((checked + 1))
  git -C "$scratch/clone" checkout -q --force "$sha" || { echo "red-first: can't check out $sha" >&2; exit 2; }
  if (cd "$scratch/clone" && timeout 300 bash -c "${run//\{\}/\"\$0\"}" "$file") >/dev/null 2>&1; then
    echo "red-first: $file passed at $(git rev-parse --short "$sha"), the commit that added it. Its code came first."
    fail=1
  fi
done < <(git log --reverse --diff-filter=A --format='%H' --name-only "$base..$head" |
  awk '/^[0-9a-f]{40}$/ {sha=$0; next} tolower($0) ~ /approved_?examples/ {print sha "\t" $0}')
[ $fail = 0 ] && echo "red-first: $checked approved tests, each red at the commit that added it."
exit $fail
