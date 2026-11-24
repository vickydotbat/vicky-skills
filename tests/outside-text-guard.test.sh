#!/usr/bin/env bash
# outside-text-guard's decisions beyond its approved examples: every write it
# refuses after outside text, every command and session it lets through, the
# setting off, no jq, and bad input.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/outside-text-guard.sh"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
export CLAUDE_PLUGIN_DATA="$t/data"; mkdir -p "$t/data/outside-read"; echo "pull request 9" > "$t/data/outside-read/marked"
fail=0
run() { # command [session] [option]
  jq -nc --arg c "$1" --arg s "${2:-marked}" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:$s,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_OUTSIDE_TEXT="${3-true}" bash "$hook" >/dev/null 2>&1; echo $?; }
expect() { local got; got=$(run "$3" "${4:-marked}" "${5-true}"); if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: exit $got, want $2"; fail=1; fi; }
expect "a push after outside text is refused" 2 "git push -u origin feature"
expect "a new pull request is refused" 2 "gh pr create --title x --body y"
expect "a tea issue is refused" 2 "tea issues create --title x"
expect "a pull request review is refused" 2 "gh pr review 9 --approve"
expect "a merge is refused" 2 "gh pr merge 9 --squash"
expect "an api POST is refused" 2 "gh api repos/o/r/issues -X POST -f title=x"
expect "a release is refused" 2 "gh release create v1"
expect "reading the pull request passes" 0 "gh pr view 9 --comments"
expect "a local commit passes" 0 "git commit -m x"
expect "an api GET passes" 0 "gh api repos/o/r/pulls/9"
# Found by the deathmatch on its own pull request: write forms the first guard let through.
expect "a push after git's own options is refused" 2 "git -C . push origin x"
expect "a push after -c is refused" 2 "git -c a=b push"
expect "a send-pack is refused" 2 "git send-pack origin HEAD"
expect "an api call with fields, an implicit POST, is refused" 2 "gh api repos/o/r/issues -f title=x"
expect "an api call with --method= is refused" 2 "gh api repos/o/r/issues --method=POST"
expect "an api call with --input is refused" 2 "gh api repos/o/r/issues --input body.json"
expect "a comment after -R is refused" 2 "gh -R o/r pr comment 1 -b x"
expect "a ready mark is refused" 2 "gh pr ready 5"
expect "a workflow run is refused" 2 "gh workflow run ci.yml"
expect "a tea comment is refused" 2 "tea comment 1 hi"
expect "a stack submit is refused" 2 "gs stack submit"
expect "a curl POST is refused" 2 "curl -X POST https://example.com/x"
expect "a curl with data is refused" 2 "curl -d x=1 https://example.com/x"
expect "a write after a newline is refused" 2 "$(printf 'cd x\ngit push')"
expect "a write after a pipe is refused" 2 "echo y | gh pr merge 9"
expect "a push behind an env assignment is refused" 2 "GIT_TRACE=1 git push"
expect "a push inside bash -c is refused" 2 "bash -c 'git push'"
expect "a push inside sh -c is refused" 2 "sh -c \"git push origin x\""
expect "a merge through eval is refused" 2 "eval gh pr merge 9"
expect "a push through xargs is refused" 2 "echo x | xargs git push"
expect "a push behind timeout is refused" 2 "timeout 60 git push"
expect "a push behind env is refused" 2 "env A=1 git push"
expect "bash -c with a read passes" 0 "bash -c 'gh pr view 9'"
expect "a pull request list passes" 0 "gh pr list --state open"
expect "a tea read passes" 0 "tea pr 9 --comments"
expect "a plain curl GET passes" 0 "curl -s https://example.com/x"
expect "a fetch passes" 0 "git -C . fetch origin"
expect "grep for the word push passes" 0 "grep -n push README.md"
# The user lifts the mark with a `!` command; the agent never can.
expect "a tea help page passes" 0 "tea pr edit --help"
expect "a gh help page passes" 0 "gh pr create -h"
expect "a tea write with help elsewhere is still refused" 2 "tea comment 1 hi; tea pr edit -h"
expect "the agent's own release is refused" 2 "bash plugins/x/release-outside.sh marked"
expect "removing the mark by hand is refused" 2 "rm \"$CLAUDE_PLUGIN_DATA/outside-read/marked\""
expect "an unmarked session pushes" 0 "git push" fresh
expect "the guard off lets a push through" 0 "git push" marked false
expect "the guard set to 0 lets a push through" 0 "git push" marked 0
got=$(echo 'not json' | bash "$hook" >/dev/null 2>&1; echo $?)
if [ "$got" = 0 ]; then echo "ok   bad input passes"; else echo "FAIL bad input passes: exit $got"; fail=1; fi
got=$(jq -nc '{session_id:"marked",tool_input:{command:"git push"}}' | PATH=/nonexistent "$(command -v bash)" "$hook" >/dev/null 2>&1; echo $?)
if [ "$got" = 0 ]; then echo "ok   no jq passes"; else echo "FAIL no jq passes: exit $got"; fail=1; fi
exit $fail
