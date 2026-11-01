#!/usr/bin/env bash
# The spark-joy hook asks for a run when the option is a number of days and
# that many days have passed since the last run, records the run, and says
# nothing when the option is 0, unset or not a number, or outside a repo. With
# gamma_shift at engage, the run goes into gamma-shift's queue instead.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/spark-joy.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"; git -C "$dir/repo" remote add origin https://example.invalid/r.git
stamp="$dir/repo/.git/spark-joy-last"
day=86400
fail=0
run() { CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT="${GS:-off}" CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS="$1" CLAUDE_PROJECT_DIR="${2:-$dir/repo}" bash "$hook" </dev/null; }
asks() { out=$(run "$1"); grep -q 'spark-joy' <<<"$out" || { echo "FAIL $2: no run asked: $out"; fail=1; }; }
silent() { out=$(run "$1" "${3:-}" 2>&1); [ -z "$out" ] || { echo "FAIL $2 printed: $out"; fail=1; }; }
asks 3 "first run"
[ -s "$stamp" ] || { echo "FAIL no run recorded"; fail=1; }
silent 3 "a run just now"
echo $(( $(date +%s) - 2 * day )) > "$stamp"; silent 3 "2 of 3 days"
echo $(( $(date +%s) - 3 * day )) > "$stamp"; asks 3 "3 of 3 days"
echo garbage > "$stamp"; asks 3 "an unreadable record"
grep -q 'background subagent' <<<"$out" || { echo "FAIL alone: not its own run: $out"; fail=1; }
rm -f "$stamp"; GS=engage asks 3 "with gamma-shift"
grep -q "gamma-shift's engage queue" <<<"$out" || { echo "FAIL engage: not queued: $out"; fail=1; }
rm -f "$stamp"; GS=remind asks 3 "gamma-shift at remind"
rm -f "$stamp"; out=$(env -u CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS=3 CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null)
grep -q 'background subagent' <<<"$out" || { echo "FAIL gamma_shift unset: not its own run: $out"; fail=1; }
grep -q 'background subagent' <<<"$out" || { echo "FAIL remind: not its own run: $out"; fail=1; }
rm -f "$stamp"
silent 0 "option 0"
silent "" "option unset"
silent weekly "option not a number"
[ -e "$stamp" ] && { echo "FAIL an off run left a record"; fail=1; }
silent 3 "outside a repo" "$dir"
[ $fail -eq 0 ] && echo "ok   spark-joy runs every N days, records each run, and is quiet otherwise"
exit $fail
