#!/usr/bin/env bash
# Approved examples for familiar fix 8, ticked 2026-11-06: the watch follows a
# session transcript that moves to a new folder when the session enters a worktree.
set -u
watch="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-watch.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
typed() { jq -nc --arg t "$1" '{type:"user",timestamp:"2026-11-06T10:00:01.000Z",message:{content:$t}}'; }
export FAMILIAR_PROJECTS_DIR="$fx/projects" FAMILIAR_WATCH_IDLE=1 FAMILIAR_WATCH_FROM_START=1
mkdir -p "$fx/projects/repo" "$fx/projects/repo-worktree"

# Given the familiar watches a session transcript
# When the session enters a worktree and its transcript moves to a new folder
# Then the watch picks up the new file and keeps printing events, with no HANDOFF
typed "before the move" > "$fx/projects/repo/s1.jsonl"
timeout 20 bash "$watch" "$fx/projects/repo/s1.jsonl" > "$fx/out" 2>&1 & pid=$!
sleep 2
mv "$fx/projects/repo/s1.jsonl" "$fx/projects/repo-worktree/s1.jsonl"
typed "between" >> "$fx/projects/repo-worktree/s1.jsonl"
sleep 3
typed "after the move" >> "$fx/projects/repo-worktree/s1.jsonl"
sleep 4
jq -nc '{type:"cost-state"}' >> "$fx/projects/repo-worktree/s1.jsonl"
wait "$pid"
out=$(cat "$fx/out")
check "8 the watch prints events from the moved transcript" 'grep -q "USER: after the move" <<<"$out"'
check "8 each line before, during and after the move prints once" 'for w in "before the move" between "after the move"; do [ "$(grep -c "USER: $w$" <<<"$out")" = 1 ] || exit 1; done'
check "8 the move itself is no HANDOFF" '[ "$(grep -c HANDOFF <<<"$out")" -le 1 ] && grep -B1 HANDOFF <<<"$out" | grep -q "after the move"'

# A transcript gone for one idle spell and back at its place is followed on.
typed "first" > "$fx/projects/repo/s3.jsonl"
timeout 20 bash "$watch" "$fx/projects/repo/s3.jsonl" > "$fx/out3" 2>&1 & pid=$!
sleep 1.5; rm "$fx/projects/repo/s3.jsonl"; sleep 1.2
typed "back" > "$fx/projects/repo/s3.jsonl"; sleep 2.5
jq -nc '{type:"cost-state"}' >> "$fx/projects/repo/s3.jsonl"; wait "$pid"
check "8 a short gap is no LOST" '! grep -q LOST "$fx/out3" && grep -q "USER: back" "$fx/out3"'

# A transcript empty when the watch starts, then moved, prints each line once.
: > "$fx/projects/repo/s4.jsonl"
timeout 20 bash "$watch" "$fx/projects/repo/s4.jsonl" > "$fx/out4" 2>&1 & pid=$!
sleep 1; typed "one" >> "$fx/projects/repo/s4.jsonl"; sleep 1.5
mv "$fx/projects/repo/s4.jsonl" "$fx/projects/repo-worktree/s4.jsonl"; sleep 2.5
typed "two" >> "$fx/projects/repo-worktree/s4.jsonl"; sleep 2.5
jq -nc '{type:"cost-state"}' >> "$fx/projects/repo-worktree/s4.jsonl"; wait "$pid"
check "8 a transcript empty at the start and then moved prints each line once" '[ "$(grep -c "USER: one$" "$fx/out4")" = 1 ] && [ "$(grep -c "USER: two$" "$fx/out4")" = 1 ]'

# Given the old transcript is gone and no new one with the same session id appears
# When the watch looks for it
# Then it prints one LOST line and ends
typed "here" > "$fx/projects/repo/s2.jsonl"
timeout 20 bash "$watch" "$fx/projects/repo/s2.jsonl" > "$fx/out2" 2>&1 & pid=$!
sleep 2
rm "$fx/projects/repo/s2.jsonl"
wait "$pid"; code=$?
out=$(cat "$fx/out2")
check "8 a transcript gone for good prints one LOST line and ends" '[ $code = 0 ] && [ "$(grep -c LOST <<<"$out")" = 1 ] && [ "$(tail -n 1 <<<"$out")" = LOST ]'
exit $fail
