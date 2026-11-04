#!/usr/bin/env bash
# publickey-hint adds its context after an output holding "Permission denied
# (publickey)", in any output shape, and stays quiet on other output, bad
# input and the setting off, and on any command but the ones the script lists.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/publickey-hint.sh"
fail=0
said() { local out code; out=$(jq -nc --argjson r "$1" --arg c "${CMD:-git push origin main}" '{tool_name:"Bash",tool_input:{command:$c},tool_response:$r}' | CLAUDE_PLUGIN_OPTION_GUARD_PUBLICKEY_HINT=${OPT:-true} bash "$hook"); code=$?
  [ "$code" = 0 ] || { echo "exit $code"; return; }; jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$out"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
deny='"git@github.com: Permission denied (publickey).\nfatal: Could not read from remote repository."'
check "stderr holding it is hinted" 1 "$(said "{\"stdout\":\"\",\"stderr\":$deny}" | grep -c 'gh api user/keys')"
check "stdout holding it is hinted" 1 "$(said "{\"stdout\":$deny}" | grep -c 'githubstatus')"
check "output holding it is hinted" 1 "$(said "{\"output\":$deny}" | grep -c 'watch.sh')"
check "a plain string response is hinted" 1 "$(said "$deny" | grep -c 'Only a key the forge lacks')"
check "other output is quiet" "" "$(said '{"stdout":"Everything up-to-date"}')"
check "a different denial is quiet" "" "$(said '{"stderr":"Permission denied (password)"}')"
for c in 'ssh -T git@github.com' 'cd repo && git fetch' 'scp a host:b' 'sftp host' 'rsync -a a host:b' 'jj git push' '(git push)' 'x=`git push`' 'true|git push' 'true;git push' git; do
  check "$c is hinted" 1 "$(CMD=$c said "{\"stderr\":$deny}" | grep -c 'watch.sh')"
done
check "a file read is quiet" "" "$(CMD='cat scripts/publickey-hint.sh' said "{\"stdout\":$deny}")"
check "a word holding git is quiet" "" "$(CMD='digit push' said "{\"stderr\":$deny}")"
check "a word starting git is quiet" "" "$(CMD='gitk push' said "{\"stderr\":$deny}")"
check "no command is quiet" "" "$(jq -nc --argjson r "{\"stderr\":$deny}" '{tool_name:"Bash",tool_response:$r}' | bash "$hook")"
check "a quoted phrase mid-line is quiet" "" "$(said '{"stdout":"grep -qF '"'"'Permission denied (publickey)'"'"' x"}')"
check "the phrase with no host is quiet" "" "$(said '{"stdout":"Permission denied (publickey)."}')"
check "the setting off is quiet" "" "$(OPT=false said "{\"stderr\":$deny}")"
check "the setting 0 is quiet" "" "$(OPT=0 said "{\"stderr\":$deny}")"
check "it names the Gitea and GitLab checks" 1 "$(said "{\"stderr\":$deny}" | grep -c 'tea api user/keys.*glab api user/keys')"
check "without jq it is quiet" "" "$(echo '{"tool_response":{"stderr":"Permission denied (publickey)"}}' | PATH=/nonexistent /usr/bin/env bash "$hook" 2>/dev/null)"
check "bad input is quiet" "" "$(echo nope | bash "$hook")"
exit $fail
