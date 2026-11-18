#!/usr/bin/env bash
# Approved examples for D1: at session start, auto-tidy hands a clone whose
# branch merged back to the latest main, and leaves a clone that still holds
# work where it is. A fake gh stands in for GitHub's pull request state.
set -u
# The shared fixture's fake gh answers from $dir/prs, one pull request a line.
. "$(dirname "$0")/lib/auto-tidy-fixture.sh"
g() { git -c user.name=t -c user.email=t@example.invalid "$@"; }
run() { PATH="$dir/gh:$PATH" CLAUDE_PLUGIN_OPTION_AUTO_TIDY="${OPT-true}" CLAUDE_PROJECT_DIR="$1" bash "$hook" </dev/null; }
# A clone with a branch pushed and squash-merged on origin's main. Pass "keep"
# to leave the branch on origin, as a merge that never deleted it does.
setup() {
  rm -rf "$dir/origin.git" "$dir/repo" "$dir/prs"
  g init -q --bare -b main "$dir/origin.git"
  g clone -q "$dir/origin.git" "$dir/repo" 2>/dev/null
  g -C "$dir/repo" commit -q --allow-empty -m base
  g -C "$dir/repo" push -q origin HEAD:main 2>/dev/null
  g -C "$dir/repo" switch -q -c feat
  echo work > "$dir/repo/work.txt"; g -C "$dir/repo" add work.txt; g -C "$dir/repo" commit -q -m work
  g -C "$dir/repo" push -q -u origin feat 2>/dev/null
  g clone -q "$dir/origin.git" "$dir/merger" 2>/dev/null
  g -C "$dir/merger" merge -q --squash origin/feat >/dev/null 2>&1; g -C "$dir/merger" commit -q -m "feat (#1)"
  g -C "$dir/merger" push -q origin main 2>/dev/null; rm -rf "$dir/merger"
  [ "${1:-}" = keep ] || g -C "$dir/origin.git" branch -q -D feat
}
on() { git -C "$dir/repo" symbolic-ref --short -q HEAD; }
at_main() { [ "$(git -C "$dir/repo" rev-parse HEAD)" = "$(git -C "$dir/repo" rev-parse origin/main)" ]; }

# Given your clone sits on a branch whose pull request merged, with no uncommitted changes
# When a session starts in it
# Then the clone stands on the latest main, and you see one line saying so
setup; echo "feat MERGED" > "$dir/prs"
out=$(run "$dir/repo")
check "E1 a merged branch hands the clone back to the latest main" '[ "$(on)" = main ] && at_main && seen "$out" | grep -q "now stands on main"'

# Given your clone sits on a branch whose pull request merged, and the branch was never deleted on GitHub
# When a session starts in it
# Then the clone stands on the latest main, the same as when the branch is gone
setup keep; echo "feat MERGED" > "$dir/prs"
out=$(run "$dir/repo")
check "E2 merged with the branch still on origin, the clone stands on main" '[ "$(on)" = main ] && at_main && seen "$out" | grep -q "now stands on main"'

# Given your clone sits on a branch with an open pull request
# When a session starts in it
# Then the clone stays on that branch
setup keep; echo "feat OPEN" > "$dir/prs"
out=$(run "$dir/repo")
check "E3 an open pull request keeps the clone" '[ "$(on)" = feat ] && agent_silent "$out"'

# Given your clone sits on a merged branch and holds uncommitted changes
# When a session starts in it
# Then the clone stays put, and you see one line naming the changed files
setup; echo "feat MERGED" > "$dir/prs"; echo half > "$dir/repo/notes.txt"
out=$(run "$dir/repo")
check "E4 uncommitted changes keep the clone where it is, and you see them named" '[ "$(on)" = feat ] && seen "$out" | grep -q "notes.txt" && agent_silent "$out"'

# Given your clone sits on a merged branch that has commits made after the merge
# When a session starts in it
# Then those commits move to a fresh branch from the latest main, and you see one line naming that branch
setup; echo "feat MERGED" > "$dir/prs"
echo more > "$dir/repo/more.txt"; g -C "$dir/repo" add more.txt; g -C "$dir/repo" commit -q -m "after the merge"
out=$(run "$dir/repo")
check "E5 commits after the merge move to a fresh branch from main" '[ "$(on)" = feat-after-merge ] \
  && [ "$(git -C "$dir/repo" log --format=%s origin/main..HEAD)" = "after the merge" ] && seen "$out" | grep -q "feat-after-merge" && agent_silent "$out"'

exit $fail
