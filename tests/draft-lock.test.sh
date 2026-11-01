#!/usr/bin/env bash
# The draft lock's decisions the approved examples leave out: a read while the
# draft is open, an edit with no path, and what a refusal names.
set -u
# No test may reach the user's own editor.
export VISUAL=true EDITOR=true
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/draft-lock.sh"
opener="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts/open-draft.sh"
dir=$(mktemp -d); trap 'kill "$(head -1 "$lock" 2>/dev/null)" 2>/dev/null; rm -rf "$dir"' EXIT
repo="$dir/repo"; git init -q "$repo"; mkdir -p "$repo/scripts"; printf 'x\n' > "$repo/scripts/c.sh"
printf '#!/bin/sh\nexec sleep 30\n' > "$dir/editor"; chmod +x "$dir/editor"
(cd "$repo" && VISUAL="$dir/editor" bash "$opener" "$dir/draft.md") &
lock="$repo/.git/red-pen-open"
for _ in $(seq 50); do [ -s "$lock" ] && break; sleep 0.1; done
fail=0
run() { CLAUDE_PLUGIN_OPTION_GUARD_DRAFT_LOCK=true bash "$hook" 2>"$dir/err" >/dev/null; }
expect() { # name want-exit want-in-message json
  run <<<"$4"; got=$?
  if [ "$got" = "$2" ] && { [ -z "$3" ] || grep -qF -- "$3" "$dir/err"; }; then echo "ok   $1"; else echo "FAIL $1: exit $got, '$(cat "$dir/err")'"; fail=1; fi
}
bash_in() { jq -n --arg c "$1" --arg d "$repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}'; }
expect "a read while the draft is open runs" 0 "" "$(bash_in 'cat scripts/c.sh')"
expect "a read that sends stderr to stdout runs" 0 "" "$(bash_in 'grep x scripts/c.sh 2>&1 | tail -3')"
expect "a read that drops its output in /dev/null runs" 0 "" "$(bash_in 'grep -q x scripts/c.sh >/dev/null 2> /dev/null')"
expect "a write beside a 2>&1 is still refused" 2 "$repo waits" "$(bash_in 'echo y > scripts/c.sh 2>&1')"
expect "an edit with no path runs" 0 "" "$(jq -n --arg d "$repo" '{tool_name: "Edit", tool_input: {}, cwd: $d}')"
expect "a refused shell write names the checkout and the draft" 2 "$repo waits" "$(bash_in 'echo y > scripts/c.sh')"
grep -qF "$dir/draft.md" "$dir/err" || { echo "FAIL the refusal names the draft"; fail=1; }
expect "a refused edit names the file" 2 "$repo/scripts/c.sh waits" "$(jq -n --arg f "$repo/scripts/c.sh" --arg d "$repo" '{tool_name: "Edit", tool_input: {file_path: $f}, cwd: $d}')"
expect "a copy between two folders outside the checkout runs" 0 "" "$(bash_in "cp $dir/a $dir/b")"
expect "a copy into the checkout is still refused" 2 "$repo waits" "$(bash_in "cp $dir/a $repo/scripts/c.sh")"
expect "a git write that names an outside path is still refused" 2 "$repo waits" "$(bash_in "git commit -F $dir/msg")"
exit $fail
