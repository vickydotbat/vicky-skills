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
expect "an unmarked session pushes" 0 "git push" fresh
expect "the guard off lets a push through" 0 "git push" marked false
expect "the guard set to 0 lets a push through" 0 "git push" marked 0
got=$(echo 'not json' | bash "$hook" >/dev/null 2>&1; echo $?)
if [ "$got" = 0 ]; then echo "ok   bad input passes"; else echo "FAIL bad input passes: exit $got"; fail=1; fi
got=$(jq -nc '{session_id:"marked",tool_input:{command:"git push"}}' | PATH=/nonexistent "$(command -v bash)" "$hook" >/dev/null 2>&1; echo $?)
if [ "$got" = 0 ]; then echo "ok   no jq passes"; else echo "FAIL no jq passes: exit $got"; fail=1; fi
exit $fail
