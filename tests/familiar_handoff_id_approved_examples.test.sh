#!/usr/bin/env bash
# Approved examples for familiar fix 10, ticked 2026-11-06: a handoff names a
# session by its id, and familiar-sessions.sh resolves the id.
set -u
sessions="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-sessions.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
export FAMILIAR_PROJECTS_DIR="$fx/projects" FAMILIAR_SESSIONS_DIR="$fx/none" CLAUDE_CODE_SESSION_ID=self
mkdir -p "$fx/projects/repo"
for id in aaaa1111-0000 bbbb2222-0000; do jq -nc --arg c "$fx" '{type:"user",cwd:$c}' > "$fx/projects/repo/$id.jsonl"; done

# Given the user says hand off to a session by its id
# When the familiar looks the id up
# Then familiar-sessions.sh names the matching session and its transcript
out=$(bash "$sessions" --id bbbb2222 2>&1); code=$?
check "10 an id names its one session and transcript" '[ $code = 0 ] && [ "$(wc -l <<<"$out")" = 1 ] && grep -q "^bbbb2222-0000 $fx/projects/repo/bbbb2222-0000.jsonl" <<<"$out"'

# Given no live session has that id
# When the familiar looks it up
# Then it says no session matches and lists the live ones
out=$(bash "$sessions" --id cccc 2>&1); code=$?
check "10 an unknown id says no session matches and lists the live ones" '[ $code = 1 ] && grep -q "no session matches cccc" <<<"$out" && grep -q aaaa1111-0000 <<<"$out" && grep -q bbbb2222-0000 <<<"$out"'
exit $fail
