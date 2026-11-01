#!/usr/bin/env bash
# Plain regression test, not approved-spec: the behaviour was built before
# its example was approved on 2026-11-01, so the test could not go red first.
# Given a checkout on main with a clean tree, six merges behind its remote
# When marie-kondo runs
# Then that checkout's main matches its remote, and a checkout with local
# work stays as it was and is named in the report
set -u
f="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/marie-kondo/SKILL.md"
step6=$(grep '^6\. \*\*Fast-forward the default branch' "$f")
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "a clean checkout on its default branch fast-forwards" 'grep -q "git merge --ff-only" <<<"$step6" && grep -q "clean tree and no commit the remote lacks" <<<"$step6"'
check "nested repositories are swept too" 'grep -q "every repository nested under" <<<"$step6"'
check "a checkout left behind is named" 'grep -q "name it in the report" <<<"$step6" && grep -q "fast-forwarded or left behind" "$f"'
exit $fail
