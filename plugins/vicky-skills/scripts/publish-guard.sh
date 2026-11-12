#!/usr/bin/env bash
# PreToolUse hook (Bash; guard_publish, on by default): making a repository
# public can't be taken back once it is seen, so it is the user's call, never
# an agent's "Going with" pick. Refuses `gh repo edit --visibility public`,
# `gh repo create --public`, `gh api` with `private=false` or
# `visibility=public`, the same through `glab`, and tea's `--private false`,
# unless the user's last message says "public" with no "not", "n't",
# "never" or "no" in it. A body sent with `--input` or curl goes unseen. An agent once asked, then took its own pick 15
# seconds later with no answer.
case "${CLAUDE_PLUGIN_OPTION_GUARD_PUBLISH:-true}" in false|0) exit 0 ;; esac
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null | sed -e ':a' -e '/\\$/{N;s/\\\n//;ba' -e '}')
grep -qE '(^|[;&|[:space:]])((gh|glab)[[:space:]]+repo[[:space:]]+edit[^;&|]*--visibility[[:space:]=]+public|(gh|glab)[[:space:]]+repo[[:space:]]+create[^;&|]*--public|(gh|glab|tea)[[:space:]]+api[^;&|]*(private=false|visibility=public)|tea[[:space:]][^;&|]*--private[[:space:]=]+false)' <<<"$cmd" || exit 0
# The user's last typed message. Claude Code injects skill text and hook feedback as
# user messages marked isMeta, so those never count as the user speaking.
asked=$(tail -n 400 "$(jq -r '.transcript_path // empty' <<<"$payload" 2>/dev/null)" 2>/dev/null | jq -rs '
  [.[] | select(.type == "user" and (.isMeta | not)) | .message.content
   | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join(" ")) end
   | select(. != "")] | last // ""' 2>/dev/null)
grep -qiw 'public' <<<"$asked" && ! grep -qiE "\b(not|never|no)\b|n't" <<<"$asked" && exit 0
jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"publish-guard: refused, making a repository public cannot be taken back once it is seen, so only the user decides it. Nothing ran. Ask the user in one line whether to make it public, wait for their answer, and run this again once their message says public."}}'
