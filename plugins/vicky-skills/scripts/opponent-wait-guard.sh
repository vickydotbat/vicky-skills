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
# shellcheck disable=SC2020 # each of ; & | and newline becomes a newline, one character at a time, as meant
while IFS= read -r seg; do
  # gh, or a variable that may hold it, then pr, any flags, and merge or ready.
  grep -qE "(^|[^[:alnum:]_-])(gh|$shell_var_re)([^[:alnum:]_-]|\$)" <<<"$seg" &&
    grep -qE '[[:space:]]pr[[:space:]](.*[[:space:]])?(merge|ready)([[:space:]]|$)|[[:space:]]pr[[:space:]]+edit[[:space:]].*--ready' <<<"$seg" &&
    ! grep -qE '[[:space:]]pr[[:space:]]+ready[[:space:]].*--undo' <<<"$seg" && gated=1
  grep -qE '(^|[^[:alnum:]_-])tea[[:space:]]+(.*[[:space:]])?(pr|pulls?)[[:space:]]+(merge|m)([[:space:]]|$)' <<<"$seg" && gated=1
  grep -qE 'pulls/[^/[:space:]]+/merge([^[:alnum:]_]|$)|mergePullRequest|markPullRequestReadyForReview|enablePullRequestAutoMerge' <<<"$seg" && gated=1
done < <(prose_strip "$cmd" | sed "s/\\$'/'/g" | tr -d "\"'\\\\" | tr ';&|\n' '\n\n\n\n')
[ "$gated" = 1 ] || exit 0
transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)
# Each opponent launched in this session that still fights, as opponents.jq
# reads it: its last task notification missing or interim.
waiting=$(jq -Rrn -L "$(dirname "$0")" '
  include "opponents";
  [inputs | fromjson? | objects] as $r
  | fighting($r; opponent_launches($r)) | .agent // empty' "$transcript" 2>/dev/null | tr '\n' ' ')
[ -n "$waiting" ] || exit 0
echo "opponent-wait-guard: the deathmatch opponents ${waiting% } have not finished: an interim report is not a verdict. Wait for each one's task notification that says it finished, then fix what it proves and run this again. Nothing ran." >&2
exit 2
