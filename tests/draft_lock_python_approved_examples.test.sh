#!/usr/bin/env bash
# approved-spec: the examples taken as is on 2026-11-03 for "Draft lock lets
# a read-only python3 run through", and for "Draft lock's refusal says where
# the draft is open".
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/draft-lock.sh"
dir=$(mktemp -d)
tail -f /dev/null & editor=$!
trap 'kill "$editor"; rm -rf "$dir"' EXIT
git init -q "$dir/repo"
lock="$(git -C "$dir/repo" rev-parse --absolute-git-dir)/red-pen-open"
fail=0
run() { jq -n --arg c "$1" --arg d "$dir/repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | CLAUDE_PLUGIN_OPTION_GUARD_DRAFT_LOCK=true bash "$hook" 2>&1; echo "exit=$?"; }
check() { if grep -qF -- "$2" <<<"$3"; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
printf '%s\ndrafts.md\npage\n' "$editor" > "$lock"

# Given a draft page open for this checkout
# When the agent runs python3 -c 'print(1)'
# Then the command runs
check "python3 printing runs" "exit=0" "$(run "python3 -c 'print(1)'")"

# Given a draft page open for this checkout
# When the agent runs python3 -c with code that opens a file for writing
# Then the draft lock still refuses it
check "python3 writing a file is refused" "exit=2" "$(run "python3 -c 'open(\"notes.txt\", \"w\").write(\"x\")'")"

# Given a draft open as a page in your browser
# When the draft lock refuses a write
# Then its message says the draft is open as a page in your browser
check "a page says browser" "open as a page in the user's browser" "$(run "echo hi > README.md")"

# Given a draft open in your editor, on a machine with no display
# When the draft lock refuses a write
# Then its message says the draft is open in your editor
printf '%s\ndrafts.md\n' "$editor" > "$lock"
check "an editor says editor" "open in the user's editor" "$(run "echo hi > README.md")"
exit $fail
