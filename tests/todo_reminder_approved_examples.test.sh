#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Session reminder for todo
# items in this repo". Each check is named after its example. The hook is run;
# the first-contact checks read the instruction that drives the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/todo-reminder.sh"
fc="$root/plugins/vicky-skills/skills/engineering/first-contact"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
remind() { echo '{"hook_event_name":"SessionStart","source":"startup"}' | CLAUDE_PROJECT_DIR="$1" bash "$hook" 2>/dev/null; }
mkdir -p "$dir/two" "$dir/none" "$dir/empty" "$dir/off/docs/agents"
printf 'Rename the cache flag\nDrop the old fixture\n' > "$dir/two/.todo"
: > "$dir/empty/.todo"
printf 'Rename the cache flag\n' > "$dir/off/.todo"
printf '# Domain docs\n\nTodo file: off\n' > "$dir/off/docs/agents/domain.md"
out=$(remind "$dir/two")
check "a repo whose .todo file holds two items reminds the agent of both at session start, and says to delete a line once its item is done" \
  'grep -q "Rename the cache flag" <<<"$out" && grep -q "Drop the old fixture" <<<"$out" && grep -qi "delete" <<<"$out" && jq -e ".hooks.SessionStart[].hooks[] | select(.command | test(\"todo-reminder\"))" "$root/plugins/vicky-skills/hooks/hooks.json" >/dev/null'
check "a repo with no .todo file, or an empty one, gets no reminder" \
  '[ -f "$hook" ] && [ -z "$(remind "$dir/none")" ] && [ -z "$(remind "$dir/empty")" ]'
check "first-contact puts .todo in the .gitignore of a repo it sets up" \
  'grep -q "\`.todo\` to the repo'"'"'s \`.gitignore\`" "$fc/SKILL.md"'
check "a repo whose docs/agents file says \"Todo file: off\" keeps its .gitignore from first-contact, and gets no reminder" \
  'grep -q "Todo file: off" "$fc/SKILL.md" && grep -q "^Todo file: on" "$fc/domain.md" && [ -f "$hook" ] && [ -z "$(remind "$dir/off")" ]'
exit $fail
