#!/usr/bin/env bash
# Stop hook (guard_take_pick, off by default): a question the agent asks in
# chat with its own pick attached, and no gate behind it, waits forever when
# the user says nothing. When the agent's last reply gives a pick ("my pick",
# "I recommend", "Pick:") and asks a question, the stop is blocked once with a
# steer: take the pick now and say "Going with", or gate it with a
# "🚪 Waiting on you" ask and a watch. A reply that already says "Going with"
# or opens a gate goes through. It steers once per turn: with
# stop_hook_active set, the reply goes through, so a misjudged one never loops.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_TAKE_PICK:-}" in true|1) ;; *) exit 0 ;; esac
payload=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$payload" 2>/dev/null)" = false ] || exit 0
transcript=$(jq -r '.transcript_path // ""' <<<"$payload" 2>/dev/null)
[ -f "$transcript" ] || exit 0 # mutant-ok delete: tail reads nothing from a missing file, so no question is found and the hook exits 0
# The agent's text since the user's last typed message: its chat text and the
# messages it sent with SendUserMessage.
said=$(tail -n 400 "$transcript" | jq -rs '
  (map(.type == "user" and ((.message.content | type) == "string" or any(.message.content[]?; .type == "text"))) | rindex(true)) as $u
  | .[(($u // -1) + 1):][] | select(.type == "assistant") | .message.content[]?
  | if .type == "text" then .text elif .type == "tool_use" and .name == "SendUserMessage" then .input.message else empty end' 2>/dev/null)
grep -qiE "going with|🚪 waiting on you" <<<"$said" && exit 0
grep -qiE "my pick|i recommend|\bpick:" <<<"$said" || exit 0
asks=$(printf '%s\n' "$said" | tr '\n' ' ' | sed 's/\([.?!]\) /\1\n/g' | grep -E '\?[[:space:]]*$|\?$')
[ -n "$asks" ] || exit 0
jq -n --arg q "$asks" '{decision:"block", reason:("You asked with a pick but nothing takes it if the user stays silent. When the pick is cheap to undo, take it now: write \"Going with <pick>\" and act on it. When it is costly to undo, gate it: open it with \"🚪 Waiting on you: <the one thing>\" and wait at it as skills/GATES.md in this plugin says. The question:\n" + $q)}'
