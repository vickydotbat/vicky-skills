#!/usr/bin/env bash
# rm-steer's decisions beyond the approved examples: each flag spelling and
# variable form it refuses, and each command shape it lets through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/rm-steer.sh"
fail=0
run() {
  jq -nc --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_RM_STEER="${2-true}" bash "$hook" >/dev/null 2>&1
  echo $?
}
expect() { # name want command [option]
  local got
  got=$(run "$3" "${4-true}")
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: exit $got, want $2"; fail=1; fi
}

expect "rm -r alone is refused on a variable" 2 'rm -r $S/out'
expect "rm -f alone is refused on a variable" 2 'rm -f $S/out'
expect "rm -R is refused on a variable" 2 'rm -R $S/out'
expect "split flags are refused" 2 'rm -v -r $S/out'
expect "--recursive is refused" 2 'rm --recursive $S/out'
expect "--force is refused" 2 'rm --force $S/out'
expect "a braced variable is refused" 2 'rm -rf ${S}/out'
expect "a double-quoted variable is refused" 2 'rm -rf "$S/out"'
expect "a command substitution is refused" 2 'rm -rf $(cat list)'
expect "a backtick substitution is refused" 2 'rm -rf `cat list`'
expect "a later segment is refused" 2 'mkdir -p /tmp/a && rm -rf $S/out'
expect "after a semicolon is refused" 2 'cd /tmp; rm -rf $S/out'
expect "after an assignment is refused" 2 'S=/tmp/a rm -rf $S/out'
expect "under sudo is refused" 2 'sudo rm -rf $S/out'
expect "under run0 is refused" 2 'run0 rm -rf $S/out'
expect "under timeout is refused" 2 'timeout 30 rm -rf $S/out'
expect "in a subshell is refused" 2 '(rm -rf $S/out)'
expect "under nice with a flag is refused" 2 'nice -n 5 rm -rf $S/out'
expect "under sudo -u is refused" 2 'sudo -u bob rm -rf $S/out'
expect "under env -i is refused" 2 'env -i rm -rf $S/out'
expect "under xargs is refused" 2 'xargs rm -rf $S/out'
expect "a command substitution inside a path is refused" 2 'rm -rf $(pwd)/x'
expect "a wrapper with no rm passes" 0 'sudo -u bob ls -rf $S'
expect "a command after an assignment that isn't rm passes" 0 'S=/tmp/a ls -rf $S'

expect "a long option that isn't -r or -f passes" 0 'rm --verbose $S/out'
expect "a short option without r or f passes" 0 'rm -v $S/out'
expect "a literal path with a variable elsewhere passes" 0 'echo $S; rm -rf /tmp/abc/out'
expect "a variable in another command passes" 0 'cp $S/a /tmp/b && rm -rf /tmp/abc/out'
expect "a word that only contains rm passes" 0 'grep -rf $S/pattern file'
expect "a forced rm of a literal path, then a plain rm of a variable, passes" 0 'rm -rf /tmp/abc/out; rm $S/notes.md'
expect "the option at 1 refuses" 2 'rm -rf $S/out' 1
expect "the option at false passes" 0 'rm -rf $S/out' false
exit $fail
