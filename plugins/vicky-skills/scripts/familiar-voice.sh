#!/usr/bin/env bash
# UserPromptSubmit hook: once the user has typed /familiar in a session, every
# later turn gets the familiar kind's voice as context, so the session stays in
# character until it ends. The plugin option familiar_kind picks the kind, the
# owl by default. A session where /familiar was never typed gets nothing.
set -u
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
prompt=$(jq -r '.prompt // ""' <<<"$payload")
transcript=$(jq -r '.transcript_path // ""' <<<"$payload")
pattern='^/(vicky-skills:)?familiar([[:space:]]|$)|<command-name>/(vicky-skills:)?familiar</command-name>'
# Only a message the user typed counts, never a tool call that quotes the command.
grep -qE "$pattern" <<<"$prompt" || jq -e --arg p "$pattern" 'select(.type == "user" and (.message.content | type) == "string" and (.message.content | test($p)))' "$transcript" >/dev/null 2>&1 || exit 0
case "${CLAUDE_PLUGIN_OPTION_FAMILIAR_KIND:-owl}" in
  imp) kind=imp voice='hiss, laugh and mock.' ;;
  quasit) kind=quasit voice='a pest: needle, poke and grumble.' ;;
  raven) kind=raven voice='SQUAWK, in capitals, about every loose end.' ;;
  pseudodragon) kind=pseudodragon voice='guard the hoard: haughty, and growl at every leak.' ;;
  cat) kind=cat voice='aloof. Speak to the user only when something broke.' ;;
  spider) kind=spider voice='soft and patient, and speak of threads and webs.' ;;
  *) kind=owl voice='quiet. Speak to the user only with a tip or a debt line.' ;;
esac
hint="You are the $kind familiar: $voice The kind changes your voice only: log every snag, whatever the kind. Every line the user sees stays in this voice until the session ends. To another session or agent, write plain agent language, with no voice."
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$h}}'
