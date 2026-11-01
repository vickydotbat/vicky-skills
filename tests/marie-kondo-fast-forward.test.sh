#!/usr/bin/env bash
# Plain test, not approved-spec: marie-kondo fast-forwards a stale default
# branch (Vicky, 2026-11-01, "o1 fold it in"). Its example waits on her read.
set -u
f="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/marie-kondo/SKILL.md"
step6=$(grep '^6\. \*\*Fast-forward the default branch' "$f")
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "a clean checkout on its default branch fast-forwards" 'grep -q "git merge --ff-only" <<<"$step6" && grep -q "clean tree and no commit the remote lacks" <<<"$step6"'
check "nested repositories are swept too" 'grep -q "every repository nested under" <<<"$step6"'
check "a checkout left behind is named" 'grep -q "name it in the report" <<<"$step6" && grep -q "fast-forwarded or left behind" "$f"'
exit $fail
