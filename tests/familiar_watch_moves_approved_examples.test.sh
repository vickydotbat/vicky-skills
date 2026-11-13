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
# Each step waits on the watch's own output, with a hard cap, so a slow machine can't reorder them.
until_out() { local i; for i in $(seq 1 300); do grep -q "$2" "$1" 2>/dev/null && return 0; sleep 0.1; done; echo "FAIL the watch never printed $2"; fail=1; return 1; }

# Given the familiar watches a session transcript
# When the session enters a worktree and its transcript moves to a new folder
# Then the watch picks up the new file and keeps printing events, with no HANDOFF
typed "before the move" > "$fx/projects/repo/s1.jsonl"
timeout 60 bash "$watch" "$fx/projects/repo/s1.jsonl" > "$fx/out" 2>&1 & pid=$!
until_out "$fx/out" "USER: before the move$"
mv "$fx/projects/repo/s1.jsonl" "$fx/projects/repo-worktree/s1.jsonl"
typed "between" >> "$fx/projects/repo-worktree/s1.jsonl"
until_out "$fx/out" "USER: between$"
typed "after the move" >> "$fx/projects/repo-worktree/s1.jsonl"
until_out "$fx/out" "USER: after the move$"
jq -nc '{type:"cost-state"}' >> "$fx/projects/repo-worktree/s1.jsonl"
wait "$pid"
out=$(cat "$fx/out")
check "8 the watch prints events from the moved transcript" 'grep -q "USER: after the move" <<<"$out"'
check "8 each line before, during and after the move prints once" 'for w in "before the move" between "after the move"; do [ "$(grep -c "USER: $w$" <<<"$out")" = 1 ] || exit 1; done'
check "8 the move itself is no HANDOFF" '[ "$(grep -c HANDOFF <<<"$out")" -le 1 ] && grep -B1 HANDOFF <<<"$out" | grep -q "after the move"'

# A transcript gone for one idle spell and back at its place is followed on.
typed "first" > "$fx/projects/repo/s3.jsonl"
timeout 60 bash "$watch" "$fx/projects/repo/s3.jsonl" > "$fx/out3" 2>&1 & pid=$!
until_out "$fx/out3" "USER: first$"; rm "$fx/projects/repo/s3.jsonl"; sleep 1.2
typed "back" > "$fx/projects/repo/s3.jsonl"; until_out "$fx/out3" "USER: back$"
jq -nc '{type:"cost-state"}' >> "$fx/projects/repo/s3.jsonl"; wait "$pid"
check "8 a short gap is no LOST" '! grep -q LOST "$fx/out3" && grep -q "USER: back" "$fx/out3"'

# Given the old transcript is gone and no new one with the same session id appears
# When the watch looks for it
# Then it prints one LOST line and ends
typed "here" > "$fx/projects/repo/s2.jsonl"
timeout 60 bash "$watch" "$fx/projects/repo/s2.jsonl" > "$fx/out2" 2>&1 & pid=$!
until_out "$fx/out2" "USER: here$"
rm "$fx/projects/repo/s2.jsonl"
wait "$pid"; code=$?
out=$(cat "$fx/out2")
check "8 a transcript gone for good prints one LOST line and ends" '[ $code = 0 ] && [ "$(grep -c LOST <<<"$out")" = 1 ] && [ "$(tail -n 1 <<<"$out")" = LOST ]'
exit $fail
