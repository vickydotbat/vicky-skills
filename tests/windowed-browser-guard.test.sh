#!/usr/bin/env bash
# windowed-browser-guard refuses the windowed browser for a page on this
# machine, and lets a real host, the setting off and bad input through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/windowed-browser-guard.sh"
fail=0
run() {
  local out code
  out=$(jq -n --arg u "$1" '{tool_name:"mcp__playwright__browser_navigate",tool_input:{url:$u}}' |
    env ${2:+CLAUDE_PLUGIN_OPTION_GUARD_WINDOWED_BROWSER=$2} bash "$hook"); code=$?
  [ "$code" = 0 ] || { echo "exit $code"; return; }
  jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out"
}
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
for u in http://localhost:3000/ localhost:5173 http://127.0.0.1:43911/x https://[::1]:8080 http://0.0.0.0 file:///tmp/page.html; do
  check "a page on this machine is refused: $u" deny "$(run "$u")"
done
check "a real host passes" "" "$(run https://github.com/login)"
check "a host that starts like localhost passes" "" "$(run https://localhost.example.com/)"
check "the setting off passes" "" "$(run http://localhost:3000/ false)"
check "the setting at 0 passes" "" "$(run http://localhost:3000/ 0)"
check "no url passes" "" "$(echo '{}' | bash "$hook")"
check "bad input passes" "" "$(echo 'not json' | bash "$hook")"
check "the refusal names the headless tool" 1 "$(jq -n '{tool_input:{url:"http://localhost/"}}' | bash "$hook" | grep -c 'playwright-headless__browser_navigate')"
exit $fail
