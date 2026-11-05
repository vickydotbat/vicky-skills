#!/usr/bin/env bash
# The familiar's watch: follows one session transcript and prints one line per
# event the familiar acts on, then HANDOFF when the user types /conn or the
# session ends. Claude Code ends a transcript with a cost-state line when its
# session exits.
# Usage: familiar-watch.sh <transcript> [<session tag>]
# It starts at the end of the file; FAMILIAR_WATCH_FROM_START=1 reads it whole and follows on.
# The mutation tool covers plugins/vicky-skills/scripts only: mutate this script by hand, with sentinels.
set -u
file=${1:?usage: familiar-watch.sh <transcript> [<session tag>]}
tag=${2:-}
from=0
[ "${FAMILIAR_WATCH_FROM_START:-}" = 1 ] && from=+1
# FAMILIAR_WATCH_ONCE=1 reads a saved transcript whole and ends, for the replay tools.
if [ "${FAMILIAR_WATCH_ONCE:-}" = 1 ]; then exec 3< "$file"; else exec 3< <(tail -n "$from" -F "$file" 2>/dev/null); fi
tailer=${!:-}
while IFS= read -r line <&3; do
  out=$(jq -r --arg tag "${tag:+$tag }" '
    def cut: gsub("\n"; " ") | .[0:400];
    # An agent line that asks, picks or waits is never cut: its questions sit at the end.
    def say: if test("\\?|Waiting on you|\\b[Pp]ick\\b|Going with") then gsub("\n"; " ") else cut end;
    ("[" + ((.timestamp // "")[11:19]) + "] " + $tag) as $at
    | if .type == "cost-state" then $tag + "HANDOFF"
    elif .type == "system" and .subtype == "compact_boundary" then $at + "COMPACTED"
    elif .type == "user" and (.isMeta | not) and (.isCompactSummary | not) then
      .message.content as $c
      | if ($c | type) == "string" then
          if ($c | test("<command-name>/(vicky-skills:)?conn</command-name>")) then $tag + "HANDOFF"
          elif ($c | test("^<(local-command|system-reminder|task-notification|command-|bash-stdout|bash-stderr)")) or ($c | test("\\S") | not) then empty
          else $at + "USER: " + ($c | cut) end
        else $c[]? | select(.type == "tool_result") | (.content | if type == "string" then . else tostring end) as $r
          | if ($r | contains("The user sent a new message while you were working:")) then
              $at + "USER: " + ($r | split("The user sent a new message while you were working:\n")[1] | split("\n\nThis is how Claude Code")[0] | cut)
            elif .is_error and ($r | test("hook error")) then $at + "REFUSED: " + ($r | cut)
            else empty end
        end
    elif .type == "assistant" then
      .message.content[]? | select(.type == "tool_use")
      | if .name == "SendUserMessage" then $at + "AGENT: " + ((.input.message // "") | say)
        elif .name == "Skill" then $at + "SKILL: " + ((.input.skill // "") | sub(".*:"; ""))
        else empty end
    else empty end' <<<"$line" 2>/dev/null)
  [ -n "$out" ] || continue
  printf '%s\n' "$out"
  case "$out" in *HANDOFF) break ;; esac
done
kill "$tailer" 2>/dev/null # mutant-ok delete: tests see no tail outlive the script without it, but a tail -F left over would wait for the transcript's next write before it dies
exit 0 # mutant-ok delete: the kill above stops a live tail and returns 0, so the script ends the same way
