#!/usr/bin/env bash
# Regression: gamma-shift behaviours from the batch ticket that already held
# when it was built (one pull request per run, her work kept apart, each item
# stopping at examples). Plain tests with no approved mark, since they pass on main.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
skill="$root/skills/engineering/gamma-shift/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "one shared branch and one draft pull request per repo" 'grep -q "one draft pull request per repo" "$skill"'
check "never the branch the user has checked out" 'grep -q "never the branch the user has checked out" "$skill"'
check "an item with no approved examples stops at drafts" 'grep -q "No approved examples on the ticket: write drafts" "$skill"'
check "setting off adds nothing at session start" 'out=$(cd "$root/../.." && CLAUDE_PROJECT_DIR=$PWD CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT=off bash "$root/scripts/gamma-shift.sh"); [ -z "$out" ]'
exit $fail
