#!/usr/bin/env bash
# Every guard that refuses a Bash call says that nothing in the command ran,
# so the steps chained around the refused one get rerun, not lost.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
s="$root/plugins/vicky-skills/scripts"
dir=$(mktemp -d)
tail -f /dev/null & editor=$!
trap 'kill "$editor"; rm -rf "$dir"' EXIT
note="Nothing in this command ran, not even its other steps"
fail=0
said() { # script command [env...] -> refusal text, with exit 2 checked
  local out
  out=$(jq -nc --arg c "$2" --arg d "${CWD:-$dir}" --arg s "${SID:-s1}" --arg a "${AGENT:-}" '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$d,session_id:$s,agent_id:$a,tool_input:{command:$c}}' |
    env "${@:3}" bash "$s/$1" 2>&1 >/dev/null); [ $? = 2 ] && printf '%s' "$out"
}
check() { if grep -qF "$note" <<<"$2"; then echo "ok   $1 says nothing ran"; else echo "FAIL $1 says nothing ran: $2"; fail=1; fi; }
check tea-stdin "$(said tea-stdin.sh 'ls; tea pr list' CLAUDE_PLUGIN_OPTION_GUARD_TEA_STDIN=true)"
check poll-pace "$(said poll-pace.sh 'until curl -s x; do sleep 5; done' CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=true)"
check plane-block-guard "$(said plane-block-guard.sh 'plane block GAME-1 GAME-2' CLAUDE_PLUGIN_OPTION_GUARD_PLANE_BLOCK=true)"
check rm-steer "$(said rm-steer.sh 'rm -rf "$S/out"' CLAUDE_PLUGIN_OPTION_GUARD_RM_STEER=true)"
git init -q "$dir/repo"
printf '%s\ndrafts.md\npage\n' "$editor" > "$(git -C "$dir/repo" rev-parse --absolute-git-dir)/red-pen-open"
check scratch-guard "$(AGENT=a1 said scratch-guard.sh 'ls; echo x > /tmp/s1/out' CLAUDE_PLUGIN_OPTION_GUARD_SCRATCH=true)"
exit $fail
