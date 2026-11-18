#!/usr/bin/env bash
# approved-spec: the examples approved for folding spark-joy and the drift
# check under gamma_shift at engage, and for one shared gamma-shift branch.
# The checks run the spark-joy and ticket-drift hooks.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/spark-joy.sh"
drift="$root/plugins/vicky-skills/scripts/ticket-drift.sh"
plugin="$root/plugins/vicky-skills/.claude-plugin/plugin.json"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"; git -C "$dir/repo" remote add origin https://example.invalid/r.git
mkdir -p "$dir/repo/docs/agents"; : > "$dir/repo/docs/agents/issue-tracker.md"
stamp="$dir/repo/.git/spark-joy-last"
day=86400
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT="${GS:-engage}" CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS="$1" CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null; }
ago() { echo $(( $(date +%s) - $1 * day )) > "$stamp"; }
opt() { jq -r --arg k "$1" ".userConfig[\$k].$2" "$plugin"; }

# Given gamma_shift at engage and deepen_every_days at 7
# When a session starts eight days after the last spark-joy run
# Then a spark-joy run joins the end of the gamma shift's queue
ago 8; out=$(run 7)
check "at engage and deepen_every_days 7, eight days on, a spark-joy run joins the end of the gamma shift's queue" \
  'grep -q "spark-joy" <<<"$out" && grep -q "last build in gamma-shift.s engage queue" <<<"$out"'

# Given gamma_shift at engage and deepen_every_days at 7
# When a session starts two days after the last spark-joy run
# Then no spark-joy run starts
ago 2; out=$(run 7)
check "at engage and deepen_every_days 7, two days on, no spark-joy run starts" '[ -z "$out" ]'

# Given gamma_shift at off or remind and deepen_every_days at 7
# When a session starts eight days after the last spark-joy run
# Then no spark-joy run starts
ago 8; o1=$(GS=off run 7); ago 8; o2=$(GS=remind run 7)
ago 8; o3=$(env -u CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS=7 CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null)
check "at gamma_shift off, remind or unset, eight days on, no spark-joy run starts" '[ -z "$o1$o2$o3" ]'

# Given a fresh install with gamma_shift switched to engage and nothing else changed
# When I read the spark-joy and drift settings under /plugin
# Then each says every 7 days
rm -f "$stamp" "$dir/repo/.git/ticket-drift-last"
f1=$(env -u CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT=engage CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null)
f2=$(env -u CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT=engage CLAUDE_PROJECT_DIR="$dir/repo" bash "$drift" </dev/null)
check "with only gamma_shift at engage, spark-joy and the drift check default to every 7 days" \
  'grep -q "is 7" <<<"$f1" && grep -q "is 7" <<<"$f2" && [ "$(opt deepen_every_days default)" = 7 ] && [ "$(opt drift_every_days default)" = 7 ]'

exit $fail
