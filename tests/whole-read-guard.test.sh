#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2329 # helpers are called inside check()'s eval
# shellcheck disable=SC2069 # only the hook's stderr is read, on purpose
# whole-read-guard refuses a ticket read piped into a cutter, and passes a
# whole read, other commands, the setting off and bad input.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/whole-read-guard.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git -C "$tmp" init -q && mkdir -p "$tmp/docs/agents"
printf '| Operation | How |\n| --- | --- |\n| Read, whole | `tracker view --comments <id>` |\n' >"$tmp/docs/agents/issue-tracker.md"
fail=0
run() { jq -nc --arg c "$1" --arg d "$tmp" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | bash "$guard" 2>&1 >/dev/null; echo "exit=$?"; }
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "plane show into head is refused with the whole-thread steer" 'run "bin/plane show GAME-2819 | head -30" | grep -q "Read the whole thread: read-item.sh GAME-2819"'
check "the refusal exits 2" 'run "bin/plane show GAME-1 | head" | grep -q "exit=2"'
check "read-item.sh into tail is refused" 'run "read-item.sh GAME-3 | tail -5" | grep -q "exit=2"'
check "sed -n is refused" 'run "plane show GAME-3 2>&1 | sed -n 1,40p" | grep -q "exit=2"'
check "grep is refused" 'run "read-item.sh 7 | grep Decision" | grep -q "exit=2"'
check "a cutter later in the pipeline is refused" 'run "plane show G-1 | jq . | head -5" | grep -q "exit=2" && run "plane show G-1 | tee f | tail" | grep -q "exit=2"'
check "a cutter reading it through a process substitution is refused" 'run "head -30 <(plane show G-1)" | grep -q "read-item.sh G-1$"'
check "the repo row command into head is refused" 'run "tracker view --comments 12 | head" | grep -q "read-item.sh 12"'
check "a whole read passes" 'run "bin/plane show GAME-2819" | grep -qx "exit=0"'
check "a whole read redirected to a file passes" 'run "read-item.sh GAME-1 > /tmp/x" | grep -qx "exit=0"'
check "sed without -n passes" 'run "plane show GAME-1 | sed s/a/b/" | grep -qx "exit=0"'
check "a pipe after a separate command is not the read" 'run "plane show GAME-1; git log | head" | grep -qx "exit=0"'
check "an unrelated head passes" 'run "git log | head -3" | grep -qx "exit=0"'
check "a missing transcript keeps the refusal (LC-6, holds already)" '[ "$(jq -nc --arg d "$tmp" "{tool_name:\"Bash\",tool_input:{command:\"read-item.sh 42 | head\"},cwd:\$d,transcript_path:\"$tmp/missing.jsonl\"}" | bash "$guard" >/dev/null 2>&1; echo $?)" = 2 ]'
check "the setting off passes" '[ "$(jq -nc "{tool_input:{command:\"plane show G-1 | head\"}}" | CLAUDE_PLUGIN_OPTION_GUARD_WHOLE_READ=false bash "$guard" 2>&1; echo $?)" = 0 ]'
check "bad input passes" '[ "$(echo notjson | bash "$guard" 2>&1; echo $?)" = 0 ]'
check "no jq: says so and passes" 'out=$(echo "{}" | PATH=/nonexistent "$BASH" "$guard" 2>&1); [ $? = 0 ] && grep -q "jq is missing" <<<"$out"'
exit $fail
