#!/usr/bin/env bash
# approved-spec: the examples approved for "no stale blocked-by links in
# Plane" (P1 to P5). Each check is named after its example. The hook's checks
# run it; the rule checks read the skill text that drives the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
guard="$root/scripts/plane-block-guard.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
err=$(mktemp); trap 'rm -f "$err"' EXIT
run() { jq -nc --arg c "$2" '{tool_name: "Bash", tool_input: {command: $c}}' |
  CLAUDE_PLUGIN_OPTION_GUARD_PLANE_BLOCK="$1" bash "$guard" 2>"$err" >/dev/null; }

run true 'bin/plane block GAME-2 GAME-1'; plain=$?
run true 'plane block GAME-2 GAME-1 </dev/null'; bare=$?
check "with the Plane block guard on, plane block GAME-2 GAME-1 with no hard reason is refused, says only a person can remove the link, and says to write Waits on: GAME-1 (<why>) in GAME-2's body" \
  '[ $plain = 2 ] && [ $bare = 2 ] && grep -q "only a person can remove" "$err" && grep -qF "Waits on: GAME-1 (<why>)" "$err" && grep -q "GAME-2" "$err"'

run true 'bin/plane block GAME-2 GAME-1 # hard: GAME-2 calls the parser GAME-1 writes'; hard=$?
check "with the Plane block guard on, plane block GAME-2 GAME-1 # hard: <reason> runs" '[ $hard = 0 ]'

run false 'bin/plane block GAME-2 GAME-1'; off=$?
run "" 'bin/plane block GAME-2 GAME-1'; unset_=$?
check "with the Plane block guard off, as it is by default, plane block runs" \
  '[ $off = 0 ] && [ $unset_ = 0 ] && jq -e ".userConfig.guard_plane_block.default == false" "$root/.claude-plugin/plugin.json" >/dev/null'

check "loose-ends names a touched ticket whose blocker its body doesn't call a hard dependency, and asks me to remove the link in Plane" \
  'grep -q "blocked by a ticket its body never names as a hard dependency" "$root/skills/engineering/loose-ends/SKILL.md" && grep -q "ask the user to remove the link" "$root/skills/engineering/loose-ends/SKILL.md"'

check "an agent filing Plane tickets in an order writes a Waits on: line in the later ticket's body, and blocks only with a hard reason" \
  'grep "Blocking" "$root/skills/engineering/first-contact/issue-tracker-plane.md" | grep -q "Write the order as a .Waits on: <KEY> (<why>). line" && grep "Blocking" "$root/skills/engineering/first-contact/issue-tracker-plane.md" | grep -q "# hard: "'
exit $fail
