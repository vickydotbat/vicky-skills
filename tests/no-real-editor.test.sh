#!/usr/bin/env bash
# A test that can open a draft (it names open-draft.sh or open-page.sh) sets
# VISUAL and EDITOR for the whole file first. A mutant can send the script
# down a path the test didn't plan for, and without that line it opens the
# draft in the user's own editor, on their desktop, while they work.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
for t in "$root"/tests/*.sh; do
  [ "$t" = "$root/tests/no-real-editor.test.sh" ] && continue
  grep -qE 'open-draft\.sh|open-page\.sh' "$t" || continue
  if grep -qE '^export VISUAL=[^ ]+ EDITOR=' "$t"; then
    echo "ok   $(basename "$t") fakes the editor for every run"
  else
    echo "FAIL $(basename "$t") can open a draft but does not start with: export VISUAL=<fake> EDITOR=<fake>"
    fail=1
  fi
done
exit $fail
