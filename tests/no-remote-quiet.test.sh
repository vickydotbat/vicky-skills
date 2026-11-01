#!/usr/bin/env bash
# The session-start hooks stay silent where they have nothing to work on:
# gamma-shift, ticket-drift and spark-joy in a git repo with no remote, and
# gamma-shift and ticket-drift in a repo with no tracker file. With both, all
# three speak. Each exits 0 either way.
set -u
dir="$(cd "$(dirname "$0")/../plugins/vicky-skills/scripts" && pwd)"
repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
git -C "$repo" init -q
export CLAUDE_PROJECT_DIR="$repo" CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT=engage \
  CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS=1 CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS=1
fail=0
expect() { # silent|speaks label hooks...
  want=$1 label=$2; shift 2
  for h in "$@"; do
    rm -f "$repo/.git/"*-last
    got=$("$dir/$h.sh" </dev/null); status=$?
    if [ "$want" = silent ]; then [ -z "$got" ]; else [ -n "$got" ]; fi && [ "$status" = 0 ] \
      && echo "ok   $h $want $label" || { echo "FAIL $h not $want $label: $got"; fail=1; }
  done
}
mkdir -p "$repo/docs/agents"; : > "$repo/docs/agents/issue-tracker.md"
expect silent "with no remote" gamma-shift ticket-drift spark-joy
git -C "$repo" remote add origin https://example.invalid/r.git
expect speaks "with a remote and a tracker" gamma-shift ticket-drift spark-joy
rm "$repo/docs/agents/issue-tracker.md"
expect silent "with no tracker" gamma-shift ticket-drift
expect speaks "with no tracker" spark-joy
CLAUDE_PROJECT_DIR="$repo/gone" expect silent "when the project folder is gone" gamma-shift
exit $fail
