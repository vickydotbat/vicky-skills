#!/usr/bin/env bash
# approved-spec: the examples the user set for the rm steer, from the .todo
# line "Take the training wheels off". Each check runs the hook on the
# command an example names and reads its decision.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/rm-steer.sh"
fail=0
# $1 the command, $2 the option. Prints the exit status, then what the hook said.
run() {
  local out status
  out=$(jq -nc --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_RM_STEER="${2-true}" bash "$hook" 2>&1)
  status=$?
  printf '%s\n%s' "$status" "$out"
}
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

check "the rm steer refuses rm -rf on a variable path with a steer to spell the full path out, and no permission prompt reaches me" \
  'r=$(run "rm -rf \$S/out"); [ "$(head -1 <<<"$r")" = 2 ] && grep -qi "spell" <<<"$r" && grep -q "full path" <<<"$r"'
check "the rm steer lets rm -rf on a spelled-out path run" \
  'r=$(run "rm -rf /tmp/abc123/out"); [ "$(head -1 <<<"$r")" = 0 ]'
check "the rm steer lets a plain rm of one file run, with no -r and no -f" \
  'r=$(run "rm \$S/notes.md"); [ "$(head -1 <<<"$r")" = 0 ]'
check "the rm steer lets text that only mentions rm run, in an echo or a heredoc" \
  'r=$(run "echo '"'"'rm -rf \$S/out'"'"'"); [ "$(head -1 <<<"$r")" = 0 ] && r=$(run "cat > /tmp/abc123/n.md <<'"'"'EOF'"'"'
rm -rf \$S/out
EOF"); [ "$(head -1 <<<"$r")" = 0 ]'
check "the rm steer is off by default and then says nothing" \
  'r=$(run "rm -rf \$S/out" ""); [ "$(head -1 <<<"$r")" = 0 ] && [ -z "$(tail -n +2 <<<"$r")" ]'
exit $fail
