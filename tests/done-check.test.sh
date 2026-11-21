#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# done-check's decisions beyond its approved examples: every path that lets the
# stop through exits 0, and bad input, a folder outside git, a missing jq and an
# unwritable state folder let it through too.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/done-check.sh"
fx=$(mktemp -d); trap 'chmod -R u+w "$fx"; rm -rf "$fx"' EXIT
export DONE_CHECK_STATE="$fx/state"
repo="$fx/repo"; mkdir -p "$repo/docs/agents"
git -C "$repo" init -q; git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
echo a >"$repo/a.txt"; git -C "$repo" add -A; git -C "$repo" commit -qm init
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
ev() { jq -nc --arg e "$1" --arg d "${2:-$repo}" '{hook_event_name:$e,session_id:"s1",cwd:$d}' | bash "$hook" >/dev/null 2>&1; echo $?; }
line() { printf '%s\n' "$1" >"$repo/docs/agents/testing.md"; }
edit_turn() { rm -rf "$DONE_CHECK_STATE"; ev UserPromptSubmit >/dev/null; date +%N >>"$repo/a.txt"; }

check "UserPromptSubmit exits 0" '[ "$(ev UserPromptSubmit)" = 0 ]'
check "SubagentStart exits 0" '[ "$(ev SubagentStart)" = 0 ]'
check "another event exits 0" '[ "$(ev PreToolUse)" = 0 ]'
line "nothing"; edit_turn
check "no Check: line exits 0" '[ "$(ev Stop)" = 0 ]'
check "the note already shown exits 0" '[ "$(ev Stop)" = 0 ]'
line "Check: none"; edit_turn
check "Check: none exits 0" '[ "$(ev Stop)" = 0 ]'
line "Check: false"; edit_turn
for i in 1 2 3; do ev Stop >/dev/null; done
check "the stop after 3 blocks exits 0" '[ "$(ev Stop)" = 0 ]'
date +%N >>"$repo/a.txt"
out=$(jq -nc --arg d "$repo" '{hook_event_name:"Stop",session_id:"s1",cwd:$d}' | bash "$hook" 2>/dev/null)
check "the count starts again after the still-fails stop" 'jq -e ".decision == \"block\"" <<<"$out" >/dev/null'
line "Check: true"; edit_turn
check "a passing check exits 0" '[ "$(ev Stop)" = 0 ]'
line "Check: sleep 30"; edit_turn
out=$(jq -nc --arg d "$repo" '{hook_event_name:"Stop",session_id:"s1",cwd:$d}' | DONE_CHECK_TIMEOUT=1 bash "$hook" 2>/dev/null); rc=$?
check "a timeout blocks once, with one answer, and exits 0" '[ $rc = 0 ] && [ "$(grep -c . <<<"$out")" = 1 ]'
check "the stop after a timeout exits 0" '[ "$(DONE_CHECK_TIMEOUT=1 ev Stop)" = 0 ]'
check "bad input exits 0" '[ "$(echo notjson | bash "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
check "a folder outside git exits 0" '[ "$(ev Stop "$fx")" = 0 ]'
check "no jq exits 0" '[ "$(echo "{}" | PATH=/nonexistent "$BASH" "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
mkdir -p "$fx/ro"; chmod a-w "$fx/ro"
check "an unwritable state folder exits 0" '[ "$(jq -nc --arg d "$repo" "{hook_event_name:\"Stop\",cwd:\$d}" | DONE_CHECK_STATE="$fx/ro/state" bash "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
exit $fail
