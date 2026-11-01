#!/usr/bin/env bash
# PostToolUse on SendUserMessage, and Notification: a desktop notification when
# an agent waits on the user. A message whose first line is the gate line,
# "🚪 Waiting on you: <what>", notifies with <what>, and so does each of Claude
# Code's own alerts except the idle one. Off unless the plugin option
# gate_notify is on.
# It uses notify-send, else osascript, and never blocks: it always exits 0.
set -u
case "${CLAUDE_PLUGIN_OPTION_GATE_NOTIFY:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
case "$(jq -r '.hook_event_name // ""' <<<"$payload")" in
  PostToolUse)
    first=$(jq -r '.tool_input.message // ""' <<<"$payload" | head -n1)
    gate='🚪 Waiting on you:'
    [[ "$first" == "$gate"* ]] || exit 0
    what="${first#"$gate"}"
    what="${what# }"
    ;;
  Notification)
    # The idle alert fires whenever a turn ends, with nothing blocked.
    [[ "$(jq -r '.notification_type // ""' <<<"$payload")" == idle_prompt ]] && exit 0
    what=$(jq -r '.message // ""' <<<"$payload")
    [[ -n "$what" ]] || exit 0
    ;;
  *) exit 0 ;;
esac
# The test points GATE_NOTIFY_SEND at a fake.
if [[ -n "${GATE_NOTIFY_SEND:-}" ]] || command -v notify-send >/dev/null 2>&1; then
  "${GATE_NOTIFY_SEND:-notify-send}" --app-name="Claude Code" "Waiting on you" "$what" >/dev/null 2>&1
elif command -v osascript >/dev/null 2>&1; then
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "Claude Code" subtitle "Waiting on you"' -e 'end run' "$what" >/dev/null 2>&1 # mutant-ok delete: macOS only, and the tests run on Linux
fi
exit 0 # mutant-ok delete: the line above leaves status 0, so the script ends the same way
