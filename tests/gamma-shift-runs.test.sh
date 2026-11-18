#!/usr/bin/env bash
# Regression: the gamma-shift session hook adds nothing when the setting is off.
# A plain test with no approved mark, since it passes on main.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "setting off adds nothing at session start" 'out=$(cd "$root/../.." && CLAUDE_PROJECT_DIR=$PWD CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT=off bash "$root/scripts/gamma-shift.sh"); [ -z "$out" ]'
exit $fail
