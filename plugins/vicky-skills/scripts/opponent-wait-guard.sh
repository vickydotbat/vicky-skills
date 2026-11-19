#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses `gh pr ready`, `gh pr merge` and a Gitea merge
# while a deathmatch opponent this session launched has not finished. An
# opponent can stop and hand back an interim report while its own background
# work still runs; its task notification then says "is waiting on its own
# background work", and only a later one says it finished. A verdict taken from
# the interim report merges before the opponent's last run is in.
# Always on, with no setting: a deathmatch that is still fighting has no verdict.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq the reads below come back empty and nothing is refused
input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null)
grep -qE '(^|[;&|(][[:space:]]*)(gh[[:space:]]+pr[[:space:]]+(ready|merge)|tea[[:space:]]+(pr|pulls)[[:space:]]+merge)([[:space:]]|$)' <<<"$cmd" || exit 0
grep -qE '(^|[;&|(][[:space:]]*)gh[[:space:]]+pr[[:space:]]+ready[[:space:]].*--undo' <<<"$cmd" && exit 0
transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)
# Each opponent launched in this session whose last task notification is
# missing or says it still waits on its own background work.
waiting=$(jq -Rrn '
  [inputs | fromjson? | objects] as $r
  | [$r[] | select(.type == "assistant") | .message.content[]? | objects
      | select(.type == "tool_use" and (.name == "Agent" or .name == "Task")
               and ((.input.subagent_type // "") | endswith("opponent"))) | .id] as $ids
  | [$r[] | select((.toolUseResult | type) == "object" and .toolUseResult.agentId != null)
      | select((.message.content[0].tool_use_id // "") as $u | $ids | index($u)) | .toolUseResult.agentId] as $agents
  | [$r[] | [.content, .message.content, .attachment.prompt] | map(select(type == "string")) | .[]
      | select(contains("<task-notification>"))] as $notes
  | $agents[] | . as $a
  | ([$notes[] | select(contains("<task-id>" + $a + "</task-id>"))] | last) as $n
  | select($n == null or ($n | contains("waiting on its own background work")))
  | $a' "$transcript" 2>/dev/null | sort -u | tr '\n' ' ')
[ -n "$waiting" ] || exit 0
echo "opponent-wait-guard: the deathmatch opponents ${waiting% } have not finished: an interim report is not a verdict. Wait for each one's task notification that says it finished, then fix what it proves and run this again. Nothing ran." >&2
exit 2
