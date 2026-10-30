#!/usr/bin/env bash
# The auto-tidy hook names the local branches whose upstream is gone and asks
# for marie-kondo. It says nothing when the option is off, when no upstream is
# gone, and outside a git repo.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/auto-tidy.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
g() { git -c user.name=t -c user.email=t@example.invalid "$@"; }
g init -q --bare "$dir/origin.git"
g clone -q "$dir/origin.git" "$dir/repo" 2>/dev/null
g -C "$dir/repo" commit -q --allow-empty -m base
g -C "$dir/repo" push -q origin HEAD:main 2>/dev/null
for b in merged kept; do
  g -C "$dir/repo" switch -q -c "$b"
  g -C "$dir/repo" push -q -u origin "$b" 2>/dev/null
done
g -C "$dir/repo" switch -q -c local-only
fail=0
# No global config, so only the hook's own --prune drops a deleted branch.
run() { GIT_CONFIG_GLOBAL=/dev/null CLAUDE_PLUGIN_OPTION_AUTO_TIDY="$1" CLAUDE_PROJECT_DIR="$2" bash "$hook" </dev/null; }
silent() { out=$(run "$1" "$2"); [ -z "$out" ] || { echo "FAIL $3 printed: $out"; fail=1; }; }
silent true "$dir/repo" "no upstream gone"
g -C "$dir/origin.git" branch -q -D merged
out=$(run true "$dir/repo")
grep -q 'marie-kondo' <<<"$out" || { echo "FAIL no marie-kondo ask: $out"; fail=1; }
grep -qw 'merged' <<<"$out" || { echo "FAIL gone branch not named: $out"; fail=1; }
grep -qw 'kept' <<<"$out" && { echo "FAIL a branch with its upstream named: $out"; fail=1; }
grep -qw 'local-only' <<<"$out" && { echo "FAIL a branch with no upstream named: $out"; fail=1; }
out=$(run 1 "$dir/repo"); grep -q 'marie-kondo' <<<"$out" || { echo "FAIL 1 does not turn it on"; fail=1; }
silent false "$dir/repo" "option false"
silent "" "$dir/repo" "option unset"
silent true "$dir" "outside a repo"
[ $fail -eq 0 ] && echo "ok   auto-tidy asks for marie-kondo only when it's on and an upstream is gone"
exit $fail
