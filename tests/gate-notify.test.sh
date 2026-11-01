#!/usr/bin/env bash
# The gate-notify hook announces a message that opens with the gate line and
# Claude Code's own alerts except the idle one, and nothing else. It is quiet while its option is
# off. A fake notify-send records each call.
set -euo pipefail

hook="$(dirname "$0")/../plugins/vicky-skills/scripts/gate-notify.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"
cat >"$scratch/bin/notify-send" <<'FAKE'
#!/usr/bin/env bash
printf '%s|' "$@" >>"$NOTIFY_LOG"; echo >>"$NOTIFY_LOG"
FAKE
chmod +x "$scratch/bin/notify-send"
export NOTIFY_LOG="$scratch/log" GATE_NOTIFY_SEND="$scratch/bin/notify-send" CLAUDE_PLUGIN_OPTION_GATE_NOTIFY=true
# No real notify-send on the PATH, so only the fake can be called.
mkdir -p "$scratch/path"
for tool in bash env jq cat grep sed head tr rm; do ln -s "$(command -v "$tool")" "$scratch/path/$tool"; done
export PATH="$scratch/path"
failed=0

# A here-string, not a pipe: the hook may exit before it reads stdin, and
# under pipefail jq's broken pipe would then fail the test at random.
run() {
  local payload rc=0
  payload=$(jq -nc "$1")
  : >"$NOTIFY_LOG"
  bash "$hook" <<<"$payload" || rc=$?
  echo "exit=$rc" >>"$scratch/exits"
}
says() { # <name> <expected log line, or empty for none>
  if [[ -z "$2" ]]; then
    [[ ! -s "$NOTIFY_LOG" ]] || { echo "FAIL $1: notified: $(cat "$NOTIFY_LOG")"; failed=1; }
  else
    grep -qxF -- "$2" "$NOTIFY_LOG" || { echo "FAIL $1: wanted $2, got $(cat "$NOTIFY_LOG")"; failed=1; }
  fi
}

run '{hook_event_name:"PostToolUse",tool_name:"SendUserMessage",tool_input:{message:"🚪 Waiting on you: merge #29\nCI is green."}}'
says "a gate line notifies" "--app-name=Claude Code|Waiting on you|merge #29|"
run '{hook_event_name:"PostToolUse",tool_name:"SendUserMessage",tool_input:{message:"Done. PR #29 is merged."}}'
says "an ordinary message stays quiet" ""
run '{hook_event_name:"PostToolUse",tool_name:"SendUserMessage",tool_input:{message:"Done.\n🚪 Waiting on you: later line"}}'
says "a gate line below the first stays quiet" ""
run '{hook_event_name:"Notification",message:"Claude needs your permission to use Bash"}'
says "Claude Code's own alert notifies" "--app-name=Claude Code|Waiting on you|Claude needs your permission to use Bash|"
run '{hook_event_name:"Notification",notification_type:"permission_prompt",message:"Claude needs your permission to use Bash"}'
says "a permission alert notifies" "--app-name=Claude Code|Waiting on you|Claude needs your permission to use Bash|"
run '{hook_event_name:"Notification",notification_type:"idle_prompt",message:"Claude is waiting for your input"}'
says "the idle alert stays quiet" ""
run '{hook_event_name:"Notification",message:""}'
says "an empty alert stays quiet" ""
run '{hook_event_name:"Stop"}'
says "another event stays quiet" ""
CLAUDE_PLUGIN_OPTION_GATE_NOTIFY=false run '{hook_event_name:"PostToolUse",tool_name:"SendUserMessage",tool_input:{message:"🚪 Waiting on you: merge #29"}}'
says "the option off stays quiet" ""
grep -qv '^exit=0$' "$scratch/exits" && { echo "FAIL the hook exited non-zero"; failed=1; }

if [[ $failed -eq 0 ]]; then echo "ok   gate-notify announces a gate line and Claude Code alerts but the idle one, nothing else"; fi
exit "$failed"
