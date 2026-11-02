#!/usr/bin/env bash
# The spark-joy hook is part of the gamma shift. With gamma_shift at engage, it
# adds a run to gamma-shift's queue when that many days have passed since the
# last run (7 when unset), and records the run. It says nothing, and records
# nothing, when gamma_shift is anything else, the option is 0 or not a number,
# or outside a repo.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/spark-joy.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"; git -C "$dir/repo" remote add origin https://example.invalid/r.git
stamp="$dir/repo/.git/spark-joy-last"
day=86400
fail=0
run() { CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT="${GS:-engage}" CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS="$1" CLAUDE_PROJECT_DIR="${2:-$dir/repo}" bash "$hook" </dev/null; }
asks() { out=$(run "$1"); grep -q "gamma-shift's engage queue" <<<"$out" || { echo "FAIL $2: no run queued: $out"; fail=1; }; }
silent() { out=$(run "$1" "${3:-}" 2>&1); [ -z "$out" ] || { echo "FAIL $2 printed: $out"; fail=1; }; }
asks 3 "first run"
[ -s "$stamp" ] || { echo "FAIL no run recorded"; fail=1; }
silent 3 "a run just now"
echo $(( $(date +%s) - 2 * day )) > "$stamp"; silent 3 "2 of 3 days"
echo $(( $(date +%s) - 3 * day )) > "$stamp"; asks 3 "3 of 3 days"
echo garbage > "$stamp"; asks 3 "an unreadable record"
echo $(( $(date +%s) - 6 * day )) > "$stamp"; silent "" "6 days with the option unset"
echo $(( $(date +%s) - 7 * day )) > "$stamp"; asks "" "7 days with the option unset"
rm -f "$stamp"
GS=remind silent 3 "gamma_shift at remind"
GS=off silent 3 "gamma_shift off"
out=$(env -u CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS=3 CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null)
[ -z "$out" ] || { echo "FAIL gamma_shift unset printed: $out"; fail=1; }
silent 0 "option 0"
silent weekly "option not a number"
[ -e "$stamp" ] && { echo "FAIL an off run left a record"; fail=1; }
silent 3 "outside a repo" "$dir"
[ $fail -eq 0 ] && echo "ok   spark-joy queues a run every N days at engage, records each run, and is quiet otherwise"
exit $fail
