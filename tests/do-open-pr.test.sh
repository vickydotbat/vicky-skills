#!/usr/bin/env bash
# do builds on an open pull request that already holds the work, and opens a
# new draft only when there is none.
set -u
do="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/do/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
two=$(grep '^2\. ' "$do")
check "an open pull request takes the build, with nothing new opened" 'grep -q "When an open pull request already holds the work you build on" <<<"$two" && grep -q "open nothing new" <<<"$two"'
check "a new draft opens only when there is none" 'grep -q "Otherwise open a \*\*draft\*\* pull request" <<<"$two"'
exit $fail
