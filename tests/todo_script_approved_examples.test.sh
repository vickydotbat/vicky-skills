#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for the hook audit, E8.
# .todo changes go through one script.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
todo="$root/plugins/vicky-skills/skills/productivity/standing-orders/scripts/todo.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
git init -q "$dir/r"; printf -- '- Old line (T-1)\n' > "$dir/r/.todo"

# Given a repo with a .todo
# When the agent runs todo.sh add <line> or todo.sh done <text>
# Then the line is added in the standing-orders form, or the matching line removed
check "E8 todo.sh add appends a line in the standing-orders form" \
  '(cd "$dir/r" && bash "$todo" add "Ship the thing (PR 5)") && grep -qx -- "- Ship the thing (PR 5)" "$dir/r/.todo"'
check "E8 todo.sh done removes the matching line" \
  '(cd "$dir/r" && bash "$todo" done "Old line") && ! grep -q "Old line" "$dir/r/.todo" && grep -q "Ship the thing" "$dir/r/.todo"'
exit $fail
