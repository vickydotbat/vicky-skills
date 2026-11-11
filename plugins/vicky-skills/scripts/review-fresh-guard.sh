#!/usr/bin/env bash
# Stop and PreToolUse:Skill hook (guard_review_fresh, on by default): work goes
# to the user only after a review that saw it. A hand-off is a reply with
# "🏁 Done" or "🚪 Waiting on you", or a start of over-to-you. When the session
# changed files (an edit tool outside /tmp, a git commit or other git write, or
# a shell write such as sed -i, tee, cp, mv, patch or a > redirect) after its
# last review (the review skill, a /review the user typed, or one of the
# review skill's *-reviewer agents), the hand-off is sent back once with a
# steer to review the unreviewed changes first. Every other case goes through.
# At Stop, stop_hook_active lets the reply through, so a misjudged one never loops.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_REVIEW_FRESH:-}" in false|0) exit 0 ;; esac
payload=$(cat)
event=$(jq -r '.hook_event_name // "Stop"' <<<"$payload" 2>/dev/null) || exit 0
if [ "$event" = PreToolUse ]; then
  jq -e '(.tool_input.skill // "") | test("(^|:)over-to-you$")' <<<"$payload" >/dev/null 2>&1 || exit 0
  transcript=$(jq -r '.transcript_path // ""' <<<"$payload")
else
  # shellcheck source=stop-reply.sh
  . "$(dirname "$0")/stop-reply.sh" <<<"$payload"
  grep -qE '🏁 *Done|🚪 *Waiting on you' <<<"$(prose)" || exit 0
fi
# One jq pass over the candidate lines prints "<line> change" or "<line> review".
# A *-reviewer agent counts, since the review skill reviews through those three.
# shortcut: shell writes are a text match. A quoted ">" costs one extra review,
# and dd, install or a script that writes goes unseen; parse the shell if either bites.
marks=$(grep -nE '"name":"(Edit|Write|MultiEdit|NotebookEdit|Bash|Skill|Agent)"|<command-name>/' "$transcript" 2>/dev/null | jq -Rr '
  capture("^(?<n>[0-9]+):(?<j>.*)$") | .n as $n | (.j | fromjson? // empty) as $d
  | if ($d.type == "user") then
      ($d.message.content | if type == "string" then . else ([.[]? | .text? // empty] | join(" ")) end)
      | if test("<command-name>/([^<]*:)?review<") then "\($n) review" else empty end
    else
      $d.message.content[]? | select(.type == "tool_use") | .name as $t | .input as $i
      | if ($t == "Edit" or $t == "Write" or $t == "MultiEdit" or $t == "NotebookEdit") then
          (if ((($i.file_path // $i.notebook_path) // "") | startswith("/tmp/")) then empty else "\($n) change" end)
        elif $t == "Bash" then
          (($i.command // "") | gsub("[0-9]?>>? */(tmp|dev)/[^ ;|&]*"; "") | gsub("[0-9]?>&[0-9]"; "")
           | if test("\\bgit\\b[^|;&]*\\s(commit|apply|am|merge|rebase|cherry-pick|pull|revert|restore|reset|checkout\\s+--|stash\\s+(pop|apply))(\\s|$)|\\b(sed|perl)\\s+(-[a-zA-Z]*\\s+)*-[a-z]*i|\\bsed\\s+--in-place|\\btee\\b|\\bdd\\b[^|;&]*\\bof=|(^|[;&|]\\s*|\\b(sudo|run0|env)\\s+([A-Za-z_]+=\\S*\\s+)*)(cp|mv|rm|ln|install|truncate|patch)\\s|>") then "\($n) change" else empty end)
        elif $t == "Skill" then
          (if (($i.skill // "") | test("(^|:)review$")) then "\($n) review" else empty end)
        elif $t == "Agent" then
          (if (($i.subagent_type // "") | test("reviewer$")) then "\($n) review" else empty end)
        else empty end
    end' 2>/dev/null)
change=$(awk '$2 == "change" { n = $1 } END { print n + 0 }' <<<"$marks")
review=$(awk '$2 == "review" { n = $1 } END { print n + 0 }' <<<"$marks")
[ "$change" -gt "$review" ] || exit 0
steer="this session changed files after its last review. Start the review skill now, with its fixed point at the commit before the first unreviewed change (the last reviewed commit, or the merge-base with the default branch when nothing was reviewed). Fix what it finds, then hand over and say in the report that the review ran."
if [ "$event" = PreToolUse ]; then
  jq -n --arg r "Nothing ran: over-to-you hands work to the user, and $steer" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
else
  jq -n --arg r "You are handing work to the user, and $steer" '{decision:"block", reason:$r}'
fi
