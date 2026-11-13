#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Familiar shape counter".
# Each check runs the counter on synthetic transcripts.
set -u
counter="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-shapes.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/corpus/-proj"
user() { printf '{"type":"user","timestamp":"%sT%s:00.000Z","message":{"content":"%s"}}\n' "$1" "$2" "$3"; }
use() { printf '{"type":"assistant","timestamp":"%sT%s:00.000Z","message":{"content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":"%s"}}]}}\n' "$1" "$2" "$3" "$4"; }
refused() { printf '{"type":"user","timestamp":"%sT%s:00.000Z","message":{"content":[{"type":"tool_result","tool_use_id":"%s","is_error":true,"content":"PreToolUse:Bash hook error: refused"}]}}\n' "$1" "$2" "$3"; }
# Day one: 4 user turns, and one refused command run again unchanged.
{
  for m in 10 11 12 13; do user 2026-11-03 "10:$m" "ask $m"; done
  use 2026-11-03 10:20 a1 "git push"; refused 2026-11-03 10:20 a1
  use 2026-11-03 10:21 a2 "git push"; refused 2026-11-03 10:21 a2
} > "$dir/corpus/-proj/day1.jsonl"
# Day two: 2 user turns, and a refused command followed by a changed one.
{
  user 2026-11-04 09:00 "ask"; user 2026-11-04 09:05 "ask again"
  use 2026-11-04 09:10 b1 "git push"; refused 2026-11-04 09:10 b1
  use 2026-11-04 09:11 b2 "git pull --rebase && git push"
} > "$dir/corpus/-proj/day2.jsonl"
# Day three: tool calls only, no user turn.
{ use 2026-11-05 08:00 c1 "ls"; } > "$dir/corpus/-proj/day3.jsonl"
out=$(bash "$counter" "$dir/corpus" --law same-refusal=2026-11-04 2>&1)

# Given transcripts from two days, and the frozen rule for a refused command run again unchanged
# When the shape counter runs
# Then it prints, for each day, the rule's hits per 100 user turns
check "E14 each day gets the rule's hits per 100 user turns" \
  'grep -qx "2026-11-03 same-refusal 1/4 turns = 25.0 per 100" <<<"$out" && grep -qx "2026-11-04 same-refusal 0/2 turns = 0.0 per 100" <<<"$out"'

# Given a law for that shape that merged on the second day
# When the shape counter runs
# Then it prints the rate before the merge and the rate after it, side by side
check "E15 a law's shape gets its rate before and after the merge on one line" \
  'grep -qx "same-refusal law 2026-11-04: before 25.0 per 100, after 0.0 per 100" <<<"$out"'

# Given a day whose transcripts hold no user turns
# When the shape counter runs
# Then that day shows no rate, never a rate of zero
check "E16 a day with no user turns shows no rate" \
  'grep -qx "2026-11-05 same-refusal no user turns, no rate" <<<"$out" && ! grep -q "^2026-11-05 same-refusal .*per 100" <<<"$out"'
[ $fail -eq 0 ] || echo "$out" | sed 's/^/     /'
twice=$(bash "$counter" "$dir/corpus" --law same-refusal=2026-11-04 --law same-refusal=2026-11-04 2>&1 | grep " law ")
check "each law counts from zero, so the same law twice prints the same line twice" '[ "$(sort -u <<<"$twice")" = "same-refusal law 2026-11-04: before 25.0 per 100, after 0.0 per 100" ] && [ "$(wc -l <<<"$twice")" = 2 ]'
bash "$counter" "$dir/corpus" --bogus >/dev/null 2>&1; code=$?
check "an unknown argument is a usage error" '[ $code = 2 ]'
exit $fail
