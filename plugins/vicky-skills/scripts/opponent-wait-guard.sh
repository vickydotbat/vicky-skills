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
cmd=$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null | sed -e ':a' -e '/\\$/{N;s/\\\n//;ba' -e '}')
# shellcheck source=prose-strip.sh
. "$(dirname "$0")/prose-strip.sh"
# Each segment is read on its own, anywhere in it, so a wrapper, a subshell or
# flags before the subcommand still count. A title's or message's words don't.
while IFS= read -r seg; do
  grep -qE '(^|[^[:alnum:]_-])gh([^[:alnum:]_-]|$)' <<<"$seg" &&
    grep -qE '[[:space:]]pr[[:space:]](.*[[:space:]])?(merge|ready)([[:space:]]|$)|[[:space:]]pr[[:space:]]+edit[[:space:]].*--ready' <<<"$seg" &&
    ! grep -qE '[[:space:]]pr[[:space:]]+ready[[:space:]].*--undo' <<<"$seg" && gated=1
  grep -qE '(^|[^[:alnum:]_-])tea[[:space:]]+(.*[[:space:]])?(pr|pulls?)[[:space:]]+(merge|m)([[:space:]]|$)' <<<"$seg" && gated=1
  grep -qE 'pulls/[^/[:space:]]+/merge([^[:alnum:]_]|$)|mergePullRequest|markPullRequestReadyForReview|enablePullRequestAutoMerge' <<<"$seg" && gated=1
done < <(prose_strip "$cmd" | sed "s/\\$'/'/g" | tr -d "\"'\\\\" | tr ';&|\n' '\n\n\n\n')
[ "$gated" = 1 ] || exit 0
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
  | [range(0; $r | length) as $i | $r[$i] | [.content, .message.content]
      | map(select(type == "string")) | .[] | select(contains("<task-notification>")) | {i: $i, t: .}] as $notes
  | [range(0; $r | length) as $i | $r[$i] | select(.type == "assistant") | .message.content[]? | objects
      | select(.type == "tool_use" and .name == "SendMessage") | {i: $i, to: (.input.to // "")}] as $sends
  | $agents[] | . as $a
  | ([$notes[] | select(.t | contains("<task-id>" + $a + "</task-id>"))] | last) as $n
  | ([$sends[] | select(.to == $a) | .i] | max) as $s
  # A message sent to an opponent after its last notification sets it working again.
  | select($n == null or ($n.t | contains("waiting on its own background work")) or ($s != null and $s > $n.i))
  | $a' "$transcript" 2>/dev/null | sort -u | tr '\n' ' ')
[ -n "$waiting" ] || exit 0
echo "opponent-wait-guard: the deathmatch opponents ${waiting% } have not finished: an interim report is not a verdict. Wait for each one's task notification that says it finished, then fix what it proves and run this again. Nothing ran." >&2
exit 2
