#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for the hook audit, E10.
# An open red-pen draft locks nothing: the page edits the draft file only.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a red-pen draft open on a page
# When the agent edits code in the same checkout
# Then the edit goes through
check "E10 no hook locks the checkout while a draft is open" \
  '! grep -q "draft-lock" "$root/plugins/vicky-skills/hooks/hooks.json" && [ ! -e "$root/plugins/vicky-skills/scripts/draft-lock.sh" ]'

# Given the page closes
# When the user's text is written back
# Then it lands in the draft file the agent wrote, whatever else changed meanwhile
check "E10 the page writes only the draft file it opened" \
  'bash "$root/tests/open-draft-page.test.sh" >/dev/null 2>&1'
exit $fail
