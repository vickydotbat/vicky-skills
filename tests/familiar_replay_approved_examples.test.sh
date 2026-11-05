#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Familiar replay".
# A stand-in model (FAMILIAR_REPLAY_MODEL) answers in place of the familiar,
# so the check runs no real model.
set -u
replay="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-replay.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
ts() { printf '2026-11-04T%s:00.000Z' "$1"; }
{
  printf '{"type":"user","timestamp":"%s","message":{"content":"build it"}}\n' "$(ts 12:30)"
  printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"git push"}}]}}\n' "$(ts 12:42)"
  printf '{"type":"user","timestamp":"%s","message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":true,"content":"PreToolUse:Bash hook error: refused"}]}}\n' "$(ts 12:42)"
} > "$dir/session.jsonl"
# Labels: <set> <HH:MM>, set being catch, miss or fp.
printf 'catch 12:42\nmiss 12:50\nfp 12:30\nfp 12:55\n' > "$dir/labels"
# The stand-in reads the watch output on stdin, and counts its own runs.
# Runs 1 and 2 log a snag at 12:42, and run 1 also flags 12:30.
cat > "$dir/model" <<EOF
#!/usr/bin/env bash
cat > "$dir/watch-seen"
n=\$(( \$(cat "$dir/runs" 2>/dev/null || echo 0) + 1 )); echo \$n > "$dir/runs"
[ \$n -le 2 ] && echo "- S1 12:42: a push refused"
[ \$n -eq 1 ] && echo "- S2 12:30: a pick asked"
exit 0
EOF
chmod +x "$dir/model"
out=$(FAMILIAR_REPLAY_MODEL="$dir/model" bash "$replay" "$dir/session.jsonl" "$dir/labels" 2>&1)

# Given a saved transcript and the snag lines its debt note holds
# When the replay runs
# Then the familiar reads the watch output three times, and each label shows how many of the three runs wrote a line of its shape
check "E17 three runs read the watch output, and each label shows how many runs logged it" \
  '[ "$(cat "$dir/runs")" = 3 ] && grep -q "REFUSED" "$dir/watch-seen" && grep -qx "catch 12:42 2/3" <<<"$out" && grep -qx "miss 12:50 0/3" <<<"$out"'

# Given labels from the familiar's own catches, from Familiar misses and from Familiar false positives
# When the replay reports
# Then it gives each set's result on its own: catches, recall on the misses, and precision on the false positives
check "E18 catches, recall on the misses and precision on the false positives each get their own line" \
  'grep -qx "catches: 1 of 1 found" <<<"$out" && grep -qx "recall on misses: 0 of 1 found" <<<"$out" && grep -qx "precision on false positives: 1 of 2 left alone" <<<"$out"'
[ $fail -eq 0 ] || echo "$out" | sed 's/^/     /'
exit $fail
