#!/usr/bin/env bash
# The band's fit and place examples run in Claude Code's mod test kit, from
# plugins/vicky-skills/tests/viewscreen_band_fit.test.tsx.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "the band gets a usable width, cuts its label to fit, and names the worktree or main checkout" \
  'out=$(timeout 120 claude plugin test "$plugin" 2>&1) && [ "$(grep -c "^(pass) band \(fit\|place\) > " <<<"$out")" = 6 ] && grep -q "^ *0 fail" <<<"$out"'
exit $fail
