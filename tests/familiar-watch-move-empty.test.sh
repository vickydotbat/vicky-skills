#!/usr/bin/env bash
# The familiar watch follows a transcript that was empty when it started and
# then moved: each line prints once. Each step waits on the watch's output,
# not on a fixed sleep, with a hard cap.
set -u
watch="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-watch.sh"
fx=$(mktemp -d); pid=; trap '[ -n "$pid" ] && kill "$pid" 2>/dev/null; rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
typed() { jq -nc --arg t "$1" '{type:"user",timestamp:"2026-11-06T10:00:01.000Z",message:{content:$t}}'; }
until_out() { local i; for i in $(seq 1 100); do grep -q "$1" "$fx/out" && return 0; sleep 0.1; done; echo "FAIL the watch never printed $1"; fail=1; return 1; }
export FAMILIAR_PROJECTS_DIR="$fx/projects" FAMILIAR_WATCH_IDLE=1
mkdir -p "$fx/projects/repo" "$fx/projects/repo-worktree"
: > "$fx/projects/repo/s.jsonl"
timeout 30 bash "$watch" "$fx/projects/repo/s.jsonl" > "$fx/out" 2>&1 & pid=$!
sleep 0.5
typed "one" >> "$fx/projects/repo/s.jsonl"; until_out "USER: one$"
mv "$fx/projects/repo/s.jsonl" "$fx/projects/repo-worktree/s.jsonl"
typed "two" >> "$fx/projects/repo-worktree/s.jsonl"; until_out "USER: two$"
jq -nc '{type:"cost-state"}' >> "$fx/projects/repo-worktree/s.jsonl"; wait "$pid"
check "a transcript empty at the start and then moved prints each line once" '[ "$(grep -c "USER: one$" "$fx/out")" = 1 ] && [ "$(grep -c "USER: two$" "$fx/out")" = 1 ]'
# A quiet transcript outside the projects folder, still in its place, is no LOST.
mkdir -p "$fx/elsewhere"; typed "hello" > "$fx/elsewhere/q.jsonl"
: > "$fx/out"; timeout 30 bash "$watch" "$fx/elsewhere/q.jsonl" > "$fx/out" 2>&1 & pid=$!
# The watch says LOST after three idle spells of 1 s with no file, so 4.5 s of quiet crosses them.
sleep 4.5; jq -nc '{type:"cost-state"}' >> "$fx/elsewhere/q.jsonl"; wait "$pid"
check "a quiet transcript in its place is followed past three idle spells" '! grep -q LOST "$fx/out"'
# Idle spells before a move count no lines, so the moved file is read from the right line.
typed "start" > "$fx/projects/repo/i.jsonl"; : > "$fx/out"
timeout 30 bash "$watch" "$fx/projects/repo/i.jsonl" > "$fx/out" 2>&1 & pid=$!
sleep 2.5 # two idle spells of 1 s pass before the move
mv "$fx/projects/repo/i.jsonl" "$fx/projects/repo-worktree/i.jsonl"; typed "later" >> "$fx/projects/repo-worktree/i.jsonl"
until_out "USER: later$"; jq -nc '{type:"cost-state"}' >> "$fx/projects/repo-worktree/i.jsonl"; wait "$pid"
check "a line written after idle spells and a move prints once" '[ "$(grep -c "USER: later$" "$fx/out")" = 1 ]'
exit $fail
