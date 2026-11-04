#!/usr/bin/env bash
# publickey-hint adds its context after an output holding "Permission denied
# (publickey)", in any output shape, and stays quiet on other output, bad
# input and the setting off.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/publickey-hint.sh"
fail=0
said() { local out code; out=$(jq -nc --argjson r "$1" '{tool_name:"Bash",tool_response:$r}' | CLAUDE_PLUGIN_OPTION_GUARD_PUBLICKEY_HINT=${OPT:-true} bash "$hook"); code=$?
  [ "$code" = 0 ] || { echo "exit $code"; return; }; jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$out"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
deny='"git@github.com: Permission denied (publickey).\nfatal: Could not read from remote repository."'
check "stderr holding it is hinted" 1 "$(said "{\"stdout\":\"\",\"stderr\":$deny}" | grep -c 'gh api user/keys')"
check "stdout holding it is hinted" 1 "$(said "{\"stdout\":$deny}" | grep -c 'githubstatus')"
check "output holding it is hinted" 1 "$(said "{\"output\":$deny}" | grep -c 'watch.sh')"
check "a plain string response is hinted" 1 "$(said "$deny" | grep -c 'Only a key the forge lacks')"
check "other output is quiet" "" "$(said '{"stdout":"Everything up-to-date"}')"
check "a different denial is quiet" "" "$(said '{"stderr":"Permission denied (password)"}')"
check "the setting off is quiet" "" "$(OPT=false said "{\"stderr\":$deny}")"
check "the setting 0 is quiet" "" "$(OPT=0 said "{\"stderr\":$deny}")"
check "bad input is quiet" "" "$(echo nope | bash "$hook")"
exit $fail
