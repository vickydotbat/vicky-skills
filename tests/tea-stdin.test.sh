#!/usr/bin/env bash
# tea-stdin refuses a tea call with stdin open, passes closed or piped ones, and is off by default.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/tea-stdin.sh"
fail=0
check() { # want command [option]
  jq -n --arg c "$2" '{tool_input:{command:$c}}' | CLAUDE_PLUGIN_OPTION_GUARD_TEA_STDIN="${3-true}" "$hook" >/dev/null 2>&1; got=$?
  if [ "$got" = "$1" ]; then echo "ok   $2 -> $1"; else echo "FAIL $2: got $got, want $1"; fail=1; fi
}
refuse() { check 2 "$1"; }
allow() { check 0 "$1"; }
refuse 'tea pr list'
refuse 'tea pr list  '
refuse 'tea pr list --login bot'
refuse 'tea --login bot whoami'
refuse 'tea pr list | jq .'
refuse 'cd x && tea issues'
refuse 'echo $(tea whoami)'
refuse 'tea pr list; echo done'
refuse 'tea pr list 2>&1 | head'
refuse 'FOO=1 tea pr list'
refuse 'tea pr edit 3 -d "a | b; c"'
refuse 'tea pr edit 3 -d "$(cat f)"'
refuse 'tea a && tea b'
refuse 'tea a </dev/null && tea b'
allow 'tea pr list </dev/null'
allow 'tea pr create < body.txt'
allow 'tea pr list 0</dev/null'
allow 'cat f | tea pr create'
allow 'echo x | tea pr create | jq .'
allow 'git status'
allow 'ls'
allow 'teapot --brew'
allow 'steam run'
allow 'echo tea'
allow 'git commit -m "tea time"'
allow $'cat <<EOF\ntea pr list\nEOF'
allow "bash -c 'tea pr list'"
check 0 'tea pr list' ""
check 0 'tea pr list' false
check 2 'tea pr list' 1
exit $fail
