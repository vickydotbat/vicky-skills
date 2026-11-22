#!/usr/bin/env bash
# PreToolUse hook (Agent, Task): refuses a deathmatch opponent launch while as
# many opponents as batch.sh allows are still fighting, and any launch while
# Holds fights, or Holds while any other fights. A script's tools.Agent resolves
# at once with a launch receipt, not the report, so awaiting it in a batch holds
# nothing: only the opponent's task notification that says it finished frees
# its slot, and a message sent to it after that sets it fighting again. A
# TaskStop for it, or an error result for its launch, frees it too. The limit is
# the last "at once: <n>" batch.sh printed this session, else 3, its ceiling.
# Launches in one burst reach this hook before any receipt is written, so the
# hook keeps its own record of each launch it passed, under a lock, for 30
# seconds: long enough for the receipt to land. The running count is the larger
# of the record's and the transcript's, so a launch both hold counts once.
# Always on, with no setting: batch.sh's limit is the desktop's memory share.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq the reads below come back empty and nothing is refused
input=$(cat)
# One read of every field, so no field falls back to a default on its own. A read that
# fails refuses a launch whose input names an opponent, and passes anything else.
# The fields are split on the unit separator: a tab is whitespace, and read merges empty fields.
fields=$(jq -r '[.tool_input.subagent_type, .tool_use_id, .session_id, .transcript_path] | map(. // "" | tostring) | join("\u001f")' <<<"$input" 2>/dev/null) \
  || { grep -q 'opponent' <<<"$input" || exit 0; echo "opponent-batch-guard: its read of this launch failed, so the launch is refused, never passed uncounted. Send it again. Nothing was dispatched." >&2; exit 2; }
IFS=$'\x1f' read -r type id session transcript <<<"$fields"
[[ "$type" == *opponent ]] || exit 0
# Each session counts in its own record; a launch with no session would count in none.
[ -n "$session" ] || { echo "opponent-batch-guard: this launch names no session, so it can't be counted, and it is refused. Nothing was dispatched." >&2; exit 2; }
session=$(printf '%s\n' "$session" | tr -c '[:alnum:]_.-' _)
dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}/opponent-batch"
mkdir -p "$dir" 2>/dev/null || exit 0 # mutant-ok delete: with no folder for the record every later read and write fails, and nothing is refused
record="$dir/$session.tsv"
lock="$dir/$session.lock"
# Concurrent hooks of one burst take turns, ten seconds at most. The lock is a file bash creates
# with noclobber, an exclusive open: some mkdir builds report success to two racing callers.
# A launch that never gets the
# lock is refused, never run unlocked. A lock older than the hook's own 30-second timeout was
# left by a killed hook: the refused launch clears it, so the next one can take it.
held= # mutant-ok delete: held starts unset in a hook, so the reset only guards a caller that exported it
for _ in $(seq 200); do (set -o noclobber; : > "$lock") 2>/dev/null && { held=1; break; }; sleep 0.05; done
if [ -z "$held" ]; then
  find "$lock" -maxdepth 0 -mmin +0.5 -exec rm -f {} \; 2>/dev/null
  echo "opponent-batch-guard: another launch held the lock for ten seconds, so this one is refused. Send it again. Nothing was dispatched." >&2; exit 2
fi
trap 'rm -f "$lock"' EXIT
touch "$record" 2>/dev/null && [ -w "$record" ] || { echo "opponent-batch-guard: it can't write its record of launches, so this launch is refused, never passed uncounted. Nothing was dispatched." >&2; exit 2; }
# A record row lives this many seconds, long enough for its receipt to land; batch.sh never sends more than ceiling.
window=30 ceiling=3
now=$(date +%s)
limit=$(grep -oE 'at once: [0-9]+' "$transcript" 2>/dev/null | tail -n 1 | grep -oE '[0-9]+$')
[[ "$limit" =~ ^[1-9][0-9]*$ ]] && [ "$limit" -le "$ceiling" ] || limit=$ceiling
# Each launch still fighting, as <tool use id><tab><type>: in the record or the transcript, with no
# final notification after its launch or its last message, and no error result.
# Only lines that can name a launch, its result, a notification, a message or a stop reach jq.
running=$(grep -E 'opponent|<task-notification>|"(SendMessage|TaskStop)"|"is_error":true|"agentId"' "$transcript" 2>/dev/null \
  | jq -Rrn -L "$(dirname "$0")" --rawfile rec "$record" --argjson now "$now" --argjson window "$window" '
  include "opponents";
  [inputs | fromjson? | objects] as $r
  | [$rec | split("\n")[] | select(length > 0) | split("\t")
     | select(($now - (.[2] | tonumber? // 0)) < $window) | {id: .[0], type: .[1], from: "record"}] as $recorded
  | (opponent_launches($r) | map(. + {from: "transcript"})) as $seen
  | fighting($r; $recorded + $seen)
  | "\(.from)\t\(.id)\t\(.type)"' 2>/dev/null) || { echo "opponent-batch-guard: the read of running opponents failed, so this launch is refused, never passed uncounted. Send it again. Nothing was dispatched." >&2; exit 2; }
# A launch the record and the transcript both hold counts once: every record row counts, and
# so does each transcript launch whose id the record lacks.
running=$(awk -F '\t' 'NF && $1 == "record" {
    seen[$2] = 1 # mutant-ok: reading seen[$2] in awk creates it, so every mutant of this line is the same program
    print $2 "\t" $3; next }
  NF { later[++n] = $0 }
  END { for (i = 1; i <= n; i++) { split(later[i], f, "\t"); if (!(f[2] in seen)) print f[2] "\t" f[3] } }' <<<"$running")
count=$(grep -c . <<<"$running")
refuse() { echo "opponent-batch-guard: $1 A launch from a script resolves at once with a launch receipt, not the report, so awaiting it holds nothing. Wait for each running opponent's task notification that says it finished, then send the next. An opponent that will never report (its session was stopped or resumed) frees its place once you stop it with TaskStop. Nothing was dispatched." >&2; exit 2; }
names=$(cut -f2 <<<"$running" | sed 's/.*://' | sort | uniq -c | awk '{printf "%s%s", (NR > 1 ? ", " : ""), ($1 > 1 ? $1 " x " $2 : $2)}')
if [[ "$type" == *holds-opponent ]]; then
  [ "$count" -eq 0 ] || refuse "Holds fights alone, and $names still fight."
else
  cut -f2 <<<"$running" | grep -q 'holds-opponent$' && refuse "Holds fights alone, and it still fights."
  [ "$count" -lt "$limit" ] || refuse "$names still fight, and batch.sh sends $limit at a time."
fi
printf '%s\t%s\t%s\n' "${id:-unnamed-$RANDOM}" "$type" "$now" >> "$record"
