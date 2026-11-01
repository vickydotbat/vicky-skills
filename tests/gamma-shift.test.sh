#!/usr/bin/env bash
# The gamma-shift hook asks for a count at remind, a run at engage, and says
# nothing when the option is off, unset or unknown.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/gamma-shift.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
git -C "$fx" init -q; git -C "$fx" remote add origin https://example.invalid/r.git
mkdir -p "$fx/docs/agents"; : > "$fx/docs/agents/issue-tracker.md"; export CLAUDE_PROJECT_DIR="$fx"
fail=0
check() { # option want-pattern (empty: no output)
  got=$(CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT="$1" "$hook" </dev/null); code=$?
  if [ $code -ne 0 ]; then echo "FAIL $1: exit $code"; fail=1; return; fi
  if [ -z "$2" ]; then
    [ -z "$got" ] && echo "ok   '$1' -> silent" || { echo "FAIL '$1' printed: $got"; fail=1; }
  else
    grep -q "$2" <<<"$got" && echo "ok   '$1' -> $2" || { echo "FAIL '$1' printed: $got"; fail=1; }
  fi
}
check remind 'remind mode'
check engage 'engage mode'
check off ''
check '' ''
check bogus ''
got=$(env -u CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT "$hook" </dev/null)
[ -z "$got" ] && echo "ok   unset -> silent" || { echo "FAIL unset printed: $got"; fail=1; }
exit $fail
