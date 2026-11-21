#!/usr/bin/env bash
# approved-spec: the examples approved on the note "LC-5 pr-guard decides from
# state". A deathmatch run leaves its record at
# <git common dir>/vicky-skills/deathmatch/<branch>, holding the session id;
# deathmatch's verdict.sh record writes it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
hook="$scripts/pr-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
export HOME="$fx/home"; mkdir -p "$HOME"
repo="$fx/repo"; mkdir -p "$repo"
git -C "$repo" init -q -b work; git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
git -C "$repo" commit -q --allow-empty -m init
record() { mkdir -p "$repo/.git/vicky-skills/deathmatch"; echo "$2" >"$repo/.git/vicky-skills/deathmatch/$1"; }
run() { jq -nc --arg c "$1" --arg d "$repo" '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$d,session_id:"sid1",tool_input:{command:$c}}' |
  CLAUDE_PLUGIN_OPTION_GUARD_PR=true bash "$hook" 2>&1 >/dev/null; echo "exit=$?"; }

# Given a pull request body passed through a shell variable the hook can't expand
# When the agent creates the pull request
# Then it is refused, and the agent reads to pass the body file by its path
out=$(run 'gh pr create --draft --title T --body "$(cat $BODYFILE)"')
check "LC-5 E1 a body behind a variable the hook can't expand is refused" 'grep -q "exit=2" <<<"$out" && grep -q "full path" <<<"$out"'

# Given deathmatch has not run on this branch this session
# When the agent marks the pull request ready
# Then it is refused, and the agent reads to ask the user to type /make-it-so
out=$(run "gh pr ready 12")
check "LC-5 E2 ready with no deathmatch record is refused" 'grep -q "exit=2" <<<"$out" && grep -q "/make-it-so" <<<"$out"'

# Given deathmatch has not run on this branch this session
# And the body carries "Skipped: deathmatch"
# When the agent sends it
# Then it is refused, with the steer to run deathmatch
out=$(run "gh pr comment 12 --body 'Skipped: deathmatch, small diff'")
check "LC-5 E4 a skip line with no record is refused, steering to deathmatch" 'grep -q "exit=2" <<<"$out" && grep -qi "run the deathmatch" <<<"$out"'

# Given a body file whose path comes from a variable set in an earlier command
# And the body holds all four sections
# When the agent creates the pull request
# Then it is refused, and the agent reads to pass the body file by its path
out=$(run 'gh pr create --draft --title T --body-file $BODY')
check "LC-5 E5 a body path the hook can't read is refused even with every section" 'grep -q "exit=2" <<<"$out" && grep -q "full path" <<<"$out"'

# Given a deathmatch record for another branch
# When the agent marks the pull request ready
# Then it is refused
record other sid1
check "LC-5 E6 a record for another branch does not count" 'run "gh pr ready 12" | grep -q "exit=2"'

# Given deathmatch ran on this branch this session
# When the agent marks the pull request ready with a body that says "Skipped: review"
# Then the call goes through, since the run record decides and not the body text
record work sid1
check "LC-5 E3 with this branch's record, a Skipped: review body goes through" 'run "gh pr edit 12 --body '"'"'Skipped: review, see verdict'"'"' && gh pr ready 12" | grep -qx "exit=0"'

exit $fail
