#!/usr/bin/env bash
# Replays one saved transcript through the familiar three times and scores it
# against labels: "<set> <HH:MM>" lines, set being catch, miss or fp.
# Usage: familiar-replay.sh <transcript> <labels file>
# FAMILIAR_REPLAY_MODEL names a stand-in for the model, which reads the watch
# output on stdin and prints snag lines ("- S<n> HH:MM: ..."). Unset, it runs
# claude -p under a 4G memory cap.
set -u
transcript=${1:?usage: familiar-replay.sh <transcript> <labels file>}
labels=${2:?usage: familiar-replay.sh <transcript> <labels file>}
[ -r "$transcript" ] && [ -r "$labels" ] || { echo "familiar-replay: cannot read $transcript or $labels" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
runs=3
watch=$(FAMILIAR_WATCH_ONCE=1 timeout 120 bash "$here/familiar-watch.sh" "$transcript")
shapes=$(awk '/^## Snag shapes/{on=1; next} /^## /{on=0} on' "$here/../SKILL.md")
prompt="You are the familiar. Below is a watched session's event log on stdin. Log each snag you see, one line each, in the form '- S<n> HH:MM: <what happened>', with the event's time. Print nothing else. A snag is any of these shapes:
$shapes"
model() {
  if [ -n "${FAMILIAR_REPLAY_MODEL:-}" ]; then timeout 300 "$FAMILIAR_REPLAY_MODEL"
  else systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 timeout 300 claude -p "$prompt"; fi
}
seen=$(mktemp); trap 'rm -f "$seen"' EXIT
for run in $(seq 1 "$runs"); do
  model <<<"$watch" | grep -oE '^- *[SM][0-9]+b? [0-9]{2}:[0-9]{2}' | grep -oE '[0-9]{2}:[0-9]{2}$' | sed "s/^/$run /"
done > "$seen"
awk -v runs="$runs" '
  function min(t) { split(t, p, ":"); return p[1] * 60 + p[2] }
  FNR == NR { at[$1, min($2)] = 1; next }
  {
    m = min($2); k = 0
    for (r = 1; r <= runs; r++) if ((r, m - 1) in at || (r, m) in at || (r, m + 1) in at) k++
    printf "%s %s %d/%d\n", $1, $2, k, runs
    total[$1]++; if (k > 0) flagged[$1]++
  }
  END {
    printf "catches: %d of %d found\n", flagged["catch"], total["catch"]
    printf "recall on misses: %d of %d found\n", flagged["miss"], total["miss"]
    printf "precision on false positives: %d of %d left alone\n", total["fp"] - flagged["fp"], total["fp"]
  }' "$seen" "$labels"
