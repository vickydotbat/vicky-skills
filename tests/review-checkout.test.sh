#!/usr/bin/env bash
# review finds the checkout the work sits in, a worktree included, and asks
# the user with a list of worktrees and pull requests when it can't tell.
# Every reviewer runs in the checkout it is given.
set -u
p="$(dirname "$0")/../plugins/vicky-skills"
rev="$p/skills/engineering/review/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
one=$(grep '^1\. ' "$rev")
check "review pins the checkout first, with the fixed point" 'grep -q "^1\. \*\*Pin the checkout and the fixed point\.\*\*" "$rev" && grep -q "Done when you hold one checkout path" <<<"$one"'
check "a build's own worktree is taken without asking" 'grep -q "the build.s own worktree when .do., .warp. or .gamma-shift. calls this skill" <<<"$one"'
check "when nothing settles it, the user sees the worktrees and pull requests and is asked" 'grep -q "git worktree list" <<<"$one" && grep -q "gh pr list" <<<"$one" && grep -q "ask the user which one to review and what they want reviewed" <<<"$one"'
check "each reviewer is handed the checkout path" 'grep -q "Give each the checkout path and the fixed point" "$rev"'
check "every reviewer agent works in the checkout it is given" '(for a in standards spec simplicity; do grep -q "in the \*\*checkout\*\* the caller names" "$p/agents/$a-reviewer.md" || exit 1; done)'
check "the step numbers read 1 to 5 in order" '[ "$(sed -n "/^## Steps/,\$p" "$rev" | grep -o "^[0-9]\." | tr -d . | tr "\n" " ")" = "1 2 3 4 5 " ]'
exit $fail
