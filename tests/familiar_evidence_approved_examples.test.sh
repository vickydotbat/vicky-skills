#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Familiar visibility by
# evidence". Each check runs the probe or the replay on synthetic sessions.
set -u
here="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/familiar/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/notes" "$dir/corpus/-p"
ts() { printf '2026-11-04T%s:00.000Z' "$1"; }
{
  printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"git push"}}]}}\n' "$(ts 12:42)"
  printf '{"type":"user","timestamp":"%s","message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":true,"content":"PreToolUse:Bash hook error: push refused"}]}}\n' "$(ts 12:42)"
  printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","id":"t2","name":"SendUserMessage","input":{"message":"Which one, A or B?"}}]}}\n' "$(ts 12:45)"
} > "$dir/corpus/-p/eeee5555-z.jsonl"
printf -- '- S1 12:42: a guard refused a push\n- S2 12:42: files were copied by shell between checkouts\n- S3 12:45: the agent asked a pick in chat\n' > "$dir/notes/2026 Familiar debt eeee5555.md"
out=$(python3 "$here/familiar-visibility.py" "$dir/notes" "$dir/corpus" 2>&1)

# Given a snag line S1 12:42 saying a guard refused a push, and a hook refusal at 12:42
# When the visibility probe runs
# Then it tags S1 visible
check "E19 a refusal snag at the minute of a hook refusal is visible" 'grep -qx "eeee5555 S1 12:42 visible" <<<"$out"'

# Given a snag line S2 12:42 saying files were copied by shell between checkouts, and only that hook refusal at 12:42
# When the visibility probe runs
# Then it tags S2 not visible, since the watch never shows a copy
check "E20 a copy snag at the same minute as a refusal is not visible" 'grep -qx "eeee5555 S2 12:42 not visible" <<<"$out"'

# Given a snag line S3 12:45 saying the agent asked a pick in chat, and an agent message at 12:45
# When the visibility probe runs
# Then it tags S3 visible
check "E21 a chat snag at the minute of an agent message is visible" 'grep -qx "eeee5555 S3 12:45 visible" <<<"$out"'

session="$dir/corpus/-p/eeee5555-z.jsonl"
printf 'catch 12:42 refused\n' > "$dir/labels"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho "- S1 12:42: a pick asked in chat"\n' > "$dir/chat"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho "- S1 12:42: a guard refused the push"\n' > "$dir/guard"
chmod +x "$dir/chat" "$dir/guard"

# Given a label for a refusal at 12:42, and runs that each log a pick asked in chat at 12:42
# When the replay runs
# Then the label shows 0 of 3 runs
check "E22 runs that log another kind of snag at the label's minute count for nothing" \
  'FAMILIAR_REPLAY_MODEL="$dir/chat" bash "$here/familiar-replay.sh" "$session" "$dir/labels" | grep -qx "catch 12:42 0/3"'

# Given a label for a refusal at 12:42, and runs that each log a guard refusing a push at 12:42
# When the replay runs
# Then the label shows 3 of 3 runs
check "E23 runs that log the same kind of snag at the label's minute all count" \
  'FAMILIAR_REPLAY_MODEL="$dir/guard" bash "$here/familiar-replay.sh" "$session" "$dir/labels" | grep -qx "catch 12:42 3/3"'
[ $fail -eq 0 ] || echo "$out" | sed 's/^/     /'
exit $fail
