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
git init -q "$dir/g"; printf 'node_modules' > "$dir/g/.gitignore"
(cd "$dir/g" && bash "$todo" add a && bash "$todo" add b)
check "add puts .todo in .gitignore, once, keeping the old lines" \
  '[ "$(grep -cx "\.todo" "$dir/g/.gitignore")" = 1 ] && grep -qx node_modules "$dir/g/.gitignore" && git -C "$dir/g" check-ignore -q .todo'
git init -q "$dir/h"; printf '.todo\n' > "$dir/h/.gitignore"
(cd "$dir/h" && bash "$todo" add a)
check "an already ignored .todo leaves .gitignore alone" '[ "$(cat "$dir/h/.gitignore")" = ".todo" ]'
git init -q "$dir/e"; printf '.todo\n' > "$dir/e/.git/info/exclude"
(cd "$dir/e" && bash "$todo" add a)
check "a .todo ignored by info/exclude gets no .gitignore" '[ ! -e "$dir/e/.gitignore" ]'
git init -q "$dir/n"; printf 'node_modules\n' > "$dir/n/.gitignore"; printf -- '- Old\n' > "$dir/n/.todo"
(cd "$dir/n" && bash "$todo" add new)
check "a .gitignore that ends in a newline gets no blank line" '[ "$(cat "$dir/n/.gitignore")" = "$(printf "node_modules\n.todo")" ]'
check "a .todo that ends in a newline gets no blank line" '[ "$(cat "$dir/n/.todo")" = "$(printf -- "- Old\n- new")" ]'
code() { (cd "$1" && bash "$todo" "${@:2}" >/dev/null 2>&1); echo $?; }
check "add with no line is a usage error" '[ "$(code "$dir/n" add)" = 2 ]'
check "done with no text is a usage error" '[ "$(code "$dir/n" done)" = 2 ]'
git init -q "$dir/x"
check "done with no .todo is a usage error" '[ "$(code "$dir/x" done Old)" = 2 ]'
check "an unknown command is a usage error" '[ "$(code "$dir/n" list)" = 2 ]'
exit $fail
