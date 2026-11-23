#!/usr/bin/env bash
# UserPromptSubmit hook: where a repo hands the ready mark to the user, they
# run it as a `!` command, which reaches the transcript as a <bash-input> entry
# and starts no turn. Their next prompt then arrives with nothing telling the
# agent that make-it-so goes on. This hook reads the prompt and the bash
# inputs since the agent's last reply, and when one marked a pull request
# ready (`gh pr ready` without --undo, `tea pr edit --ready`, or
# `tea pr edit -t` with a title that drops `WIP:`), adds make-it-so's
# remaining steps as context. On unless the plugin option ready_resume_hint
# is false or 0.
set -u
case "${CLAUDE_PLUGIN_OPTION_READY_RESUME_HINT:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every read below comes back empty, and the hook exits 0 the same way
input=$(cat)
prompt=$(jq -r '.prompt // ""' <<<"$input" 2>/dev/null)
transcript=$(jq -r '.transcript_path // ""' <<<"$input" 2>/dev/null)
inputs="" ready=""
if [ -f "$transcript" ]; then
  # The user entries after the last assistant entry, each a plain string.
  inputs=$(tail -n 400 "$transcript" | jq -rs '
    (map(.type) | rindex("assistant")) as $a
    | .[(($a // -1) + 1):][]
    | select(.type == "user" and (.message.content | type) == "string")
    | .message.content' 2>/dev/null)
fi
cmds=$(printf '%s\n%s\n' "$prompt" "$inputs" | grep -oE '<bash-input>[^<]*</bash-input>' | sed -E 's#</?bash-input>##g')
while IFS= read -r c; do
  if grep -Eq '(^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+ready([[:space:]]|$)' <<<"$c"; then
    grep -Eq -- '--undo' <<<"$c" || ready=$c
  elif grep -Eq '(^|[^[:alnum:]_-])tea[[:space:]]+(pr|pulls?)[[:space:]]+edit([[:space:]]|$)' <<<"$c"; then
    if grep -Eq -- '--ready([[:space:]]|$)' <<<"$c"; then
      ready=$c
    elif grep -Eq -- '(^|[[:space:]])(-t|--title)([[:space:]=])' <<<"$c" && ! grep -Eq -- '--draft|(-t|--title)[[:space:]=]+["'"'"']?WIP:' <<<"$c"; then
      ready=$c
    fi
  fi
done <<<"$cmds"
[ -n "$ready" ] || exit 0
jq -nc --arg c "$ready" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:("The user marked a pull request ready (`" + $c + "`). make-it-so goes on from there, unasked: run `git fetch origin`, and when the branch is behind its base, rebase and push it as step 1 says. Then check that a run started for the head commit, the new one after a rebase, and when none did (a Gitea title edit often starts none), close and reopen the pull request (step 5). Then watch every required check to a final state and fix red (step 6), settle the tickets and the body, and report (step 7).")}}'
