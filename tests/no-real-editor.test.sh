#!/usr/bin/env bash
# A test that can open a draft (it names open-draft.sh, open-page.sh or
# page.py) sets VISUAL and EDITOR for the whole file first. A test that can
# open a page (it names open-page.sh or page.py) also sets BROWSER, and puts
# a fake systemctl first on PATH: page.py starts the browser with the desktop
# session's environment, read through systemctl, so the fake desktop must
# name the fake browser too. A mutant can send the script down a path the
# test didn't plan for, and without these lines it opens the draft in the
# user's own editor or browser, on their desktop, while they work.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
for t in "$root"/tests/*.sh; do
  [ "$t" = "$root/tests/no-real-editor.test.sh" ] && continue
  grep -qE 'open-draft\.sh|open-page\.sh|page\.py' "$t" || continue
  name=$(basename "$t")
  if ! grep -qE '^export VISUAL=[^ ]+ EDITOR=' "$t"; then
    echo "FAIL $name can open a draft but does not start with: export VISUAL=<fake> EDITOR=<fake>"
    fail=1
  elif ! grep -qE 'open-page\.sh|page\.py' "$t"; then
    echo "ok   $name fakes the editor for every run"
  elif ! grep -qE '^export VISUAL=[^ ]+ EDITOR=[^ ]+ BROWSER=' "$t"; then
    echo "FAIL $name can open a page but does not start with: export VISUAL=<fake> EDITOR=<fake> BROWSER=<fake>"
    fail=1
  elif ! grep -qE '^export PATH=.*desktop' "$t" || ! grep -q '/systemctl"' "$t"; then
    echo "FAIL $name can open a page but puts no fake desktop systemctl first on PATH"
    fail=1
  else
    echo "ok   $name fakes the editor, the browser and the desktop for every run"
  fi
done
exit $fail
