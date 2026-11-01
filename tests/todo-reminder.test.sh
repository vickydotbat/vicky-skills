#!/usr/bin/env bash
# The todo reminder lists a repo's .todo items at session start, skips blank
# lines, and stays silent with no file, an empty file, or "Todo file: off".
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/todo-reminder.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
expect() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'"; fail=1; fi; }
run() { CLAUDE_PROJECT_DIR="$1" bash "$hook" </dev/null; }
mkdir -p "$dir/a" "$dir/blank" "$dir/off/docs/agents" "$dir/on/docs/agents"
printf 'one\n\n  \ntwo\n' > "$dir/a/.todo"
printf '\n \n' > "$dir/blank/.todo"
printf 'one\n' > "$dir/off/.todo"; printf 'Todo file: off\n' > "$dir/off/docs/agents/domain.md"
printf 'one\n' > "$dir/on/.todo"; printf 'Todo file: on\n' > "$dir/on/docs/agents/domain.md"
expect "two items, blank lines skipped" "This repo's .todo file lists small items to do:
- one
- two
Do each item whose wait is over now, without asking, then delete its line from .todo. A line that still waits on the user stays until they engage it. A line whose star, chart or ticket has closed goes too." "$(run "$dir/a")"
expect "only blank lines, silent" "" "$(run "$dir/blank")"
expect "no .todo, silent" "" "$(run "$dir")"
expect "Todo file: off, silent" "" "$(run "$dir/off")"
expect "Todo file: on, reminded" "- one" "$(run "$dir/on" | sed -n 2p)"
expect "exits 0 when silent" 0 "$(run "$dir" >/dev/null; echo $?)"
expect "exits 0 when off" 0 "$(run "$dir/off" >/dev/null; echo $?)"
exit $fail
