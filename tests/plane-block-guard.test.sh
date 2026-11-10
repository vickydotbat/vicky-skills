#!/usr/bin/env bash
# plane-block-guard's steer names real tickets, and speaks of "each ticket"
# when the command builds its keys from a shell variable, as a loop does.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/plane-block-guard.sh"
fail=0
pb="plane bl""ock"
steer() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | CLAUDE_PLUGIN_OPTION_GUARD_PLANE_BLOCK=true bash "$guard" 2>&1 >/dev/null; }
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "a real key is named in the steer" 'steer "bin/$pb GAME-2 GAME-1" | grep -q "in GAME-2.s body"'
check "a loop variable is no ticket: the steer speaks of each ticket" 'out=$(steer "for t in 1 2; do bin/$pb GAME-\$t GAME-9; done"); grep -q "each ticket the command blocks" <<<"$out" && ! grep -qF "GAME-\$t" <<<"$out"'
check "a variable blocker is named as its blocker" 'steer "bin/$pb GAME-2 \$B" | grep -q "Waits on: its blocker"'
check "a help call links nothing and passes" '[ -z "$(steer "timeout 30 bin/$pb -h 2>&1 | sed -n 1,8p")" ] && [ -z "$(steer "bin/$pb --help")" ]'
check "a redirect is no blocker" '[ -z "$(steer "bin/$pb GAME-2 2>&1")" ]'
check "a real block before a comment is still refused" 'steer "bin/$pb GAME-2 GAME-1; echo done" | grep -q "in GAME-2.s body"'
exit $fail
