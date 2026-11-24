#!/usr/bin/env bash
# release-outside.sh lifts a session's mark wherever the plugin data folder is,
# leaves other sessions marked, and refuses a missing or path-shaped id.
set -u
# shellcheck disable=SC2016 # each check is a string ok() evals later, so it must not expand now
# shellcheck disable=SC2329 # push() is called from inside those evaled strings
# shellcheck disable=SC2034 # out is read from inside those evaled strings
root="$(cd "$(dirname "$0")/.." && pwd)"
rel="$root/plugins/vicky-skills/skills/shipping/deathmatch/scripts/release-outside.sh"
guard="$root/plugins/vicky-skills/scripts/outside-text-guard.sh"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
ok() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
d="$t/cfg/plugins/data/vs/outside-read"; mkdir -p "$d"
echo "pr 9" >"$d/s1"; echo "pr 9" >"$d/s2"
push() { jq -nc --arg s "$1" '{session_id:$s,tool_input:{command:"git push"}}' | CLAUDE_PLUGIN_DATA="$t/cfg/plugins/data/vs" bash "$guard" >/dev/null 2>&1; echo $?; }
ok "a marked session is refused before the release" '[ "$(push s1)" = 2 ]'
out=$(env -u CLAUDE_PLUGIN_DATA CLAUDE_CONFIG_DIR="$t/cfg" CLAUDE_CODE_SESSION_ID=s1 bash "$rel")
ok "the release finds the mark without CLAUDE_PLUGIN_DATA" '[[ $out == *"may write"* ]] && [ ! -e "$d/s1" ]'
ok "the released session pushes" '[ "$(push s1)" = 0 ]'
ok "another session stays marked" '[ -e "$d/s2" ] && [ "$(push s2)" = 2 ]'
out=$(CLAUDE_CONFIG_DIR="$t/cfg" bash "$rel" s1)
ok "a session with no mark says so" '[[ $out == *"holds no mark"* ]]'
env -u CLAUDE_CODE_SESSION_ID bash "$rel" >/dev/null 2>&1; ok "no session id is refused" '[ $? = 2 ]'
CLAUDE_CONFIG_DIR="$t/cfg" bash "$rel" ../vs >/dev/null 2>&1; ok "a path-shaped id is refused" '[ $? = 2 ] && [ -d "$t/cfg/plugins/data/vs" ]'
exit $fail
