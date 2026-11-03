#!/usr/bin/env bash
# The preview examples run in Claude Code's mod test kit, from
# the preview test file beside the mod in plugins/vicky-skills/hooks.
set -u
plugin="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "every preview example passes on the terminal and the desktop" \
  'out=$(timeout 120 claude plugin test "$plugin" 2>&1); [ "$(grep -c "^(pass) preview > " <<<"$out")" = 10 ]'
exit $fail
