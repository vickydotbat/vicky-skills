#!/usr/bin/env bash
# The gate-notify hook announces a message that opens with the gate line and
# Claude Code's own alerts, and nothing else. It is quiet while its option is
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
failed=0

run() { : >"$NOTIFY_LOG"; jq -nc "$1" | bash "$hook"; echo "exit=$?" >>"$scratch/exits"; }
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
run '{hook_event_name:"Notification",message:""}'
says "an empty alert stays quiet" ""
run '{hook_event_name:"Stop"}'
says "another event stays quiet" ""
CLAUDE_PLUGIN_OPTION_GATE_NOTIFY=false run '{hook_event_name:"PostToolUse",tool_name:"SendUserMessage",tool_input:{message:"🚪 Waiting on you: merge #29"}}'
says "the option off stays quiet" ""
grep -qv '^exit=0$' "$scratch/exits" && { echo "FAIL the hook exited non-zero"; failed=1; }

if [[ $failed -eq 0 ]]; then echo "ok   gate-notify announces a gate line and Claude Code alerts, nothing else"; fi
exit "$failed"
