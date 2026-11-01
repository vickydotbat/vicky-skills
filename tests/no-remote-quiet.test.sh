#!/usr/bin/env bash
# The gamma-shift, ticket-drift and spark-joy hooks stay silent in a git repo
# with no remote, and still speak once the repo has one.
set -u
dir="$(cd "$(dirname "$0")/../plugins/vicky-skills/scripts" && pwd)"
repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
git -C "$repo" init -q
export CLAUDE_PROJECT_DIR="$repo" CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT=engage \
  CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS=1 CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS=1
fail=0
for h in gamma-shift ticket-drift spark-joy; do
  got=$("$dir/$h.sh" </dev/null)
  [ -z "$got" ] && echo "ok   $h silent with no remote" || { echo "FAIL $h printed: $got"; fail=1; }
done
git -C "$repo" remote add origin https://example.invalid/r.git
for h in gamma-shift ticket-drift spark-joy; do
  got=$("$dir/$h.sh" </dev/null)
  [ -n "$got" ] && echo "ok   $h speaks with a remote" || { echo "FAIL $h silent with a remote"; fail=1; }
done
exit $fail
