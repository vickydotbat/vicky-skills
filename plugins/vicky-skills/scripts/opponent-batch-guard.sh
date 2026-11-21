#!/usr/bin/env bash
# PreToolUse hook (Agent, Task): refuses a deathmatch opponent launch while as
# many opponents as batch.sh allows are still fighting, and any launch while
# Holds fights, or Holds while any other fights. A script's tools.Agent resolves
# at once with a launch receipt, not the report, so awaiting it in a batch holds
# nothing: only the opponent's task notification that says it finished frees
# its slot, and a message sent to it after that sets it fighting again. The
# limit is the last "at once: <n>" batch.sh printed this session, else 3, its
# ceiling. Launches in one burst reach this hook before any receipt is written,
# so the hook keeps its own record of each launch it passed, under a lock.
# Always on, with no setting: batch.sh's limit is the desktop's memory share.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq the reads below come back empty and nothing is refused
input=$(cat)
type=$(jq -r '.tool_input.subagent_type // ""' <<<"$input" 2>/dev/null)
[[ "$type" == *opponent ]] || exit 0
id=$(jq -r '.tool_use_id // ""' <<<"$input")
session=$(jq -r '.session_id // "none"' <<<"$input" | tr -c '[:alnum:]_.-' _)
transcript=$(jq -r '.transcript_path // ""' <<<"$input")
dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}/opponent-batch"
mkdir -p "$dir" 2>/dev/null || exit 0 # mutant-ok delete: with no folder for the record every later read and write fails, and nothing is refused
record="$dir/$session.tsv"
lock="$dir/$session.lock"
# Concurrent hooks of one burst take turns: two seconds at most, then the lock counts as stale.
for _ in $(seq 40); do mkdir "$lock" 2>/dev/null && break; sleep 0.05; done
mkdir "$lock" 2>/dev/null # mutant-ok delete: takes a stale lock over; the rmdir below and this mkdir leave it held either way
trap 'rmdir "$lock" 2>/dev/null' EXIT
touch "$record"
# A rerun for a launch this hook passed already passes again.
[ -n "$id" ] && cut -f1 "$record" | grep -qxF -- "$id" && exit 0
limit=$(grep -oE 'at once: [0-9]+' "$transcript" 2>/dev/null | tail -n 1 | grep -oE '[0-9]+$')
[[ "$limit" =~ ^[1-9][0-9]*$ ]] || limit=3
# Each launch still fighting, as <tool use id><tab><type>: in the record or the transcript, with no
# final notification after its launch or its last message, and no error result.
running=$(jq -Rrn --rawfile rec "$record" '
  [inputs | fromjson? | objects] as $r
  | ([$rec | split("\n")[] | select(length > 0) | split("\t") | {id: .[0], type: .[1]}]
     + [$r[] | select(.type == "assistant") | .message.content[]? | objects
        | select(.type == "tool_use" and (.name == "Agent" or .name == "Task")
                 and ((.input.subagent_type // "") | endswith("opponent")))
        | {id, type: .input.subagent_type}]) | unique_by(.id) as $launches
  | [$r[] | select(.type == "user") | .message.content[]? | objects
      | select(.type == "tool_result" and .is_error == true) | .tool_use_id] as $errors
  | [$r[] | select((.toolUseResult | type) == "object" and .toolUseResult.agentId != null)
      | {id: (.message.content[0].tool_use_id // ""), agent: .toolUseResult.agentId}] as $agents
  | [range(0; $r | length) as $i | $r[$i] | [.. | strings | select(contains("<task-notification>"))][]
      | {i: $i, t: .}] as $notes
  | [range(0; $r | length) as $i | $r[$i] | select(.type == "assistant") | .message.content[]? | objects
      | select(.type == "tool_use" and .name == "SendMessage") | {i: $i, to: (.input.to // "")}] as $sends
  | $launches[] | . as $l
  | select(($errors | index($l.id)) | not)
  | ([$agents[] | select(.id == $l.id) | .agent] | first) as $a
  | ([$notes[] | select((.t | contains("<tool-use-id>" + $l.id + "</tool-use-id>"))
                        or ($a != null and (.t | contains("<task-id>" + $a + "</task-id>"))))] | last) as $n
  | ([$sends[] | select($a != null and .to == $a) | .i] | max) as $s
  | select($n == null or ($n.t | contains("waiting on its own background work")) or ($s != null and $s > $n.i))
  | "\(.id)\t\(.type)"' "$transcript" 2>/dev/null)
count=$(grep -c . <<<"$running")
refuse() { echo "opponent-batch-guard: $1 A launch from a script resolves at once with a launch receipt, not the report, so awaiting it holds nothing. Wait for each running opponent's task notification that says it finished, then send the next. Nothing was dispatched." >&2; exit 2; }
names=$(cut -f2 <<<"$running" | sed 's/.*://' | sort | uniq -c | awk '{printf "%s%s", (NR > 1 ? ", " : ""), ($1 > 1 ? $1 " x " $2 : $2)}')
if [[ "$type" == *holds-opponent ]]; then
  [ "$count" -eq 0 ] || refuse "Holds fights alone, and $names still fight."
else
  cut -f2 <<<"$running" | grep -q 'holds-opponent$' && refuse "Holds fights alone, and it still fights."
  [ "$count" -lt "$limit" ] || refuse "$names still fight, and batch.sh sends $limit at a time."
fi
printf '%s\t%s\n' "${id:-unnamed-$RANDOM}" "$type" >> "$record"
