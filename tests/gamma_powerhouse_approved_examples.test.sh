#!/usr/bin/env bash
# approved-spec: the examples approved for folding spark-joy and the drift
# check under gamma_shift at engage, and for one shared gamma-shift branch.
# The hook checks run spark-joy.sh. The queue, report and branch checks read
# the gamma-shift skill, since running the shift is the agent's work.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/spark-joy.sh"
drift="$root/plugins/vicky-skills/scripts/ticket-drift.sh"
plugin="$root/plugins/vicky-skills/.claude-plugin/plugin.json"
skill="$root/plugins/vicky-skills/skills/engineering/gamma-shift/SKILL.md"
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
brief=$(awk '/^## Subagent brief/{on=1} /^## Report/{on=0} on' "$skill")
report=$(awk '/^## Report/{on=1} on' "$skill")

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
# Then each says every 7 days, and says it only runs with gamma_shift at engage
rm -f "$stamp" "$dir/repo/.git/ticket-drift-last"
f1=$(env -u CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT=engage CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null)
f2=$(env -u CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT=engage CLAUDE_PROJECT_DIR="$dir/repo" bash "$drift" </dev/null)
check "with only gamma_shift at engage, spark-joy and the drift check default to every 7 days, and their settings say they need engage" \
  'grep -q "is 7" <<<"$f1" && grep -q "is 7" <<<"$f2" && [ "$(opt deepen_every_days default)" = 7 ] && [ "$(opt drift_every_days default)" = 7 ] && opt deepen_every_days description | grep -q "gamma_shift is engage" && opt drift_every_days description | grep -q "gamma_shift is engage"'

# Given gamma_shift at engage
# When the gamma shift reports
# Then the report lists the spark-joy pull request and the tickets the drift check commented on, beside the built tickets
check "the gamma shift report lists the spark-joy work and the tickets the drift check commented on, beside the built tickets" \
  'grep -q "^- spark-joy:" <<<"$report" && grep -q "^Drift comments" <<<"$report" && grep -q "^Built" <<<"$report"'

# Given the gamma_shift setting under /plugin
# When I read its description
# Then it calls itself the experimental backlog-clearing powerhouse, and warns that at engage it builds, opens draft pull requests and comments on tickets with no one watching
d=$(opt gamma_shift description)
check "the gamma_shift setting calls itself the experimental backlog-clearing powerhouse and warns what engage does unwatched" \
  'grep -q "experimental backlog-clearing powerhouse" <<<"$d" && grep -q "draft pull request" <<<"$d" && grep -q "comments on tickets" <<<"$d" && grep -q "no one watching" <<<"$d"'

# Given gamma_shift at engage, two cleared tickets and a spark-joy run due
# When the gamma shift runs
# Then all three land on one gamma-shift branch with one draft pull request, and the branch I am working on gets none of them
check "every build in one gamma shift lands on one gamma-shift branch and one draft pull request, never the user's branch" \
  'grep -q "one shared \*\*gamma-shift branch\*\*" "$skill" && grep -q "gamma-shift-<date>" <<<"$brief" && grep -q "push origin HEAD:gamma-shift-<date>" <<<"$brief" && ! grep -q "switch -c <ticket>" <<<"$brief" && grep -q "never the branch the user has checked out" "$skill"'

# Given a gamma shift with nothing cleared and no spark-joy run due
# When it runs
# Then no gamma-shift branch or pull request is made
check "a gamma shift with nothing to build makes no branch or pull request" \
  'grep -q "With nothing to build, make no branch and no pull request" "$skill"'

# Given a trunk repo, one whose agent file says to commit straight to main
# When the gamma shift builds a cleared ticket
# Then the build lands on main, as before
check "in a trunk repo, a gamma shift build lands on main" \
  'grep -q "this is a trunk repo: git pull --rebase on main, build there, push to main, and open no pull request" <<<"$brief"'
exit $fail
