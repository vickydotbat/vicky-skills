#!/usr/bin/env bash
# The page opener records a branch as approved only when the user ticked a box,
# once per branch, in the checkout's shared git folder, and never on a detached HEAD.
set -u
export VISUAL=true EDITOR=true
root="$(cd "$(dirname "$0")/.." && pwd)"
opener="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts/open-draft.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"
git init -q -b main "$repo"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m start
record="$repo/.git/examples-approved"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
page() { printf '# Drafts: x\n\n## E1\nticket: new\n- [ ] approve\n\n```text\nGiven a thing\n```\n' > "$dir/d.md"; }
close_with() { # close_with <sed script, or nothing to leave the file as it was> [checkout]
  printf '#!/bin/sh\n[ -z "%s" ] || sed -i "%s" "$1"\n' "$1" "$1" > "$dir/ed.sh"
  (cd "${2:-$repo}" && EDITOR="sh $dir/ed.sh" VISUAL="" bash "$opener" "$dir/d.md") >/dev/null 2>&1
}
lines() { if [ -f "$record" ]; then grep -c . "$record"; else echo 0; fi; }
tick='s/- \[ \] approve/- [x] approve/'

page; close_with ""
check "a page closed with no tick records nothing" 0 "$(lines)"
printf '# Drafts: x\n\n## Grant\ntests/a_approved_examples.test.sh:4\n- [ ] approve\n\n```text\nThe button reads Save\n```\n' > "$dir/d.md"; close_with "$tick"
check "a tick on a page that holds no example records nothing" 0 "$(lines)"
page; close_with 's/Given a thing/Given another thing/'
check "an edit with no tick records nothing" 0 "$(lines)"
page; close_with "$tick"
check "a tick records the branch" main "$(cat "$record" 2>/dev/null)"
page; close_with "$tick"
check "a second tick on the branch adds no second line" 1 "$(lines)"
git -C "$repo" worktree add -q -b side "$dir/wt"
page; close_with "$tick" "$dir/wt"
check "a tick in another worktree lands in the shared record" "main side" "$(tr '\n' ' ' < "$record" | sed 's/ $//')"
git -C "$repo" checkout -q --detach
page; close_with "$tick"
check "a tick on a detached HEAD records nothing" 2 "$(lines)"
exit $fail
