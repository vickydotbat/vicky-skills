#!/usr/bin/env bash
# todo.sh: a long line is still written, with a warning; done on missing text fails.
set -u
todo="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/standing-orders/scripts/todo.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
git init -q "$dir/r"; printf -- '- Kept line' > "$dir/r/.todo"
long=$(printf 'x%.0s' $(seq 81))
check "a line over 80 characters warns and is still added" \
  'err=$(cd "$dir/r" && bash "$todo" add "$long" 2>&1 >/dev/null) && grep -q "at most 80" <<<"$err" && grep -qx -- "- $long" "$dir/r/.todo"'
check "a file with no final newline gets one before the new line" 'grep -qx -- "- Kept line" "$dir/r/.todo"'
check "done on text no line holds fails" '! (cd "$dir/r" && bash "$todo" done "nothing like this" 2>/dev/null)'
check "outside a repo it refuses" '! (cd / && bash "$todo" add x 2>/dev/null)'
exit $fail
