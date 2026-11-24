#!/usr/bin/env bash
# release-outside.sh lifts a session's mark wherever the plugin data folder is,
# leaves other sessions marked, and refuses a missing or path-shaped id.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
rel="$root/plugins/vicky-skills/skills/shipping/deathmatch/scripts/release-outside.sh"
guard="$root/plugins/vicky-skills/scripts/outside-text-guard.sh"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
check() { if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
d="$t/cfg/plugins/data/vs/outside-read"; mkdir -p "$d"
echo "pr 9" >"$d/s1"; echo "pr 9" >"$d/s2"
push() { jq -nc --arg s "$1" '{session_id:$s,tool_input:{command:"git push"}}' | CLAUDE_PLUGIN_DATA="$t/cfg/plugins/data/vs" bash "$guard" >/dev/null 2>&1; echo $?; }

if [ "$(push s1)" = 2 ]; then check "a marked session is refused before the release" 0; else check "a marked session is refused before the release" 1; fi
out=$(env -u CLAUDE_PLUGIN_DATA CLAUDE_CONFIG_DIR="$t/cfg" CLAUDE_CODE_SESSION_ID=s1 bash "$rel")
if [[ $out == *"may write"* && ! -e "$d/s1" ]]; then check "the release finds the mark without CLAUDE_PLUGIN_DATA" 0; else check "the release finds the mark without CLAUDE_PLUGIN_DATA" 1; fi
if [ "$(push s1)" = 0 ]; then check "the released session pushes" 0; else check "the released session pushes" 1; fi
if [[ -e "$d/s2" && "$(push s2)" = 2 ]]; then check "another session stays marked" 0; else check "another session stays marked" 1; fi
out=$(CLAUDE_CONFIG_DIR="$t/cfg" bash "$rel" s1)
if [[ $out == *"holds no mark"* ]]; then check "a session with no mark says so" 0; else check "a session with no mark says so" 1; fi
env -u CLAUDE_CODE_SESSION_ID bash "$rel" >/dev/null 2>&1
if [ $? = 2 ]; then check "no session id is refused" 0; else check "no session id is refused" 1; fi
CLAUDE_CONFIG_DIR="$t/cfg" bash "$rel" ../vs >/dev/null 2>&1
if [[ $? = 2 && -d "$t/cfg/plugins/data/vs" ]]; then check "a path-shaped id is refused" 0; else check "a path-shaped id is refused" 1; fi
exit $fail
