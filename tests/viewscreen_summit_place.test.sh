#!/usr/bin/env bash
# The band's summit and place lines run in Claude Code's mod test kit, from
# plugins/vicky-skills/tests/viewscreen_summit_place.test.tsx.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "the place and summit sit above the Claude line, only a line-start summit counts, and the line names the current branch" \
  'out=$(timeout 120 claude plugin test "$plugin" 2>&1) && [ "$(grep -c "^(pass) summit and place lines > " <<<"$out")" = 4 ] && grep -q "^ *0 fail" <<<"$out"'
exit $fail
