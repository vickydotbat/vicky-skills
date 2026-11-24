#!/usr/bin/env bash
# approved-spec: L1 and L2, typed-only hand-offs read from the skill graph.
# The skill files hold backticks on purpose, so single quotes keep them literal.
# shellcheck disable=SC2016
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
links="$root/tests/skill-links.test.sh"
graph="$root/plugins/vicky-skills/scripts/skill-graph.py"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
skills() {
  rm -rf "$dir/s"; mkdir -p "$dir/s/g/t" "$dir/s/g/caller"
  printf -- '---\nname: t\ndescription: x. Use when asked.\ndisable-model-invocation: true\n---\n1. Work.\n' >"$dir/s/g/t/SKILL.md"
  printf -- '---\nname: caller\ndescription: y. Use when z.\n---\n1. %s\n' "$1" >"$dir/s/g/caller/SKILL.md"
}

# Given a skill the agent can start, whose step says write it with `t`, and `t` is a skill only the user types
# When the plugin's tests run
# Then they fail, naming the skill and `t`
skills 'Write it with `t`.'
out=$(bash "$links" "$dir/s" 2>&1); rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q 'caller' && echo "$out" | grep -q '\bt\b'; then echo "ok   L1"; else echo "FAIL L1: rc=$rc out=$out"; fail=1; fi

# Given a skill the agent can start, whose step says settle it with `t`'s SETTLE.md
# When the plugin's tests run
# Then they pass, and the skill graph shows no arrow to `t`
skills "Settle it with \`t\`'s SETTLE.md."
out=$(bash "$links" "$dir/s" 2>&1); rc=$?
arrows=$(python3 "$graph" list "$dir/s" | grep -c "	t$")
if [ $rc -eq 0 ] && [ "$arrows" = 0 ]; then echo "ok   L2"; else echo "FAIL L2: rc=$rc arrows=$arrows out=$out"; fail=1; fi
exit $fail
