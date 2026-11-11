#!/usr/bin/env bash
# Stop hook (guard_review_fresh, on by default): work goes to the user only
# after a review that saw it. When the agent's last reply hands over, with
# "🏁 Done" or "🚪 Waiting on you", and the session changed files (an Edit,
# Write or MultiEdit outside /tmp, or a git commit) after its last review
# (the review skill, a /review the user typed, or a reviewer subagent), the
# stop is blocked once with a steer to review the unreviewed commits first.
# A reply with no hand-off, a session with no change since its last review
# and the setting off go through. With stop_hook_active set the reply goes
# through, so a misjudged one never loops.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_REVIEW_FRESH:-}" in false|0) exit 0 ;; esac
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
grep -qE '🏁 *Done|🚪 *Waiting on you' <<<"$(prose)" || exit 0
# One jq pass over the candidate lines prints "<line> change" or "<line> review".
marks=$(grep -nE '"name":"(Edit|Write|MultiEdit|Bash|Skill|Agent)"|<command-name>/[^<]*review<' "$transcript" | jq -Rr '
  capture("^(?<n>[0-9]+):(?<j>.*)$") | .n as $n | (.j | fromjson? // empty) as $d
  | if ($d.type == "user") then
      (if (($d.message.content | type) == "string") and ($d.message.content | test("<command-name>/[^<]*:review<")) then "\($n) review" else empty end)
    else
      $d.message.content[]? | select(.type == "tool_use") | .name as $t | .input as $i
      | if ($t == "Edit" or $t == "Write" or $t == "MultiEdit") then
          (if (($i.file_path // "") | startswith("/tmp/")) then empty else "\($n) change" end)
        elif $t == "Bash" then
          (if (($i.command // "") | test("\\bgit\\b[^|;&]*\\scommit(\\s|$)")) then "\($n) change" else empty end)
        elif $t == "Skill" then
          (if (($i.skill // "") | test("(^|:)review$")) then "\($n) review" else empty end)
        elif $t == "Agent" then
          (if (($i.subagent_type // "") | test("reviewer$")) then "\($n) review" else empty end)
        else empty end
    end' 2>/dev/null)
change=$(awk '$2 == "change" { n = $1 } END { print n + 0 }' <<<"$marks")
review=$(awk '$2 == "review" { n = $1 } END { print n + 0 }' <<<"$marks")
[ "$change" -gt "$review" ] || exit 0
jq -n '{decision:"block", reason:"You are handing work to the user, and this session changed files after its last review. Start the review skill now, with its fixed point at the commit before the first unreviewed change (the last reviewed commit, or the merge-base with the default branch when nothing was reviewed). Fix what it finds, then hand over and say in the report that the review ran."}'
