#!/usr/bin/env bash
# Approved examples for D1: at session start, auto-tidy hands a clone whose
# branch merged back to the latest main, and leaves a clone that still holds
# work where it is. A fake gh stands in for GitHub's pull request state.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/auto-tidy.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null
# The hook commits when it carries commits over, so the run needs an identity.
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
g() { git -c user.name=t -c user.email=t@example.invalid "$@"; }
mkdir "$dir/bin"
# The fake gh answers `gh pr view <branch> --json state -q .state` with the
# state in $dir/pr-<branch>, and fails like gh does when no pull request exists.
cat > "$dir/bin/gh" <<EOF
#!/usr/bin/env bash
[ "\$1 \$2" = "pr view" ] || exit 1
f="$dir/pr-\$3"
[ -f "\$f" ] || { echo "no pull requests found for branch \$3" >&2; exit 1; }
cat "\$f"
EOF
chmod +x "$dir/bin/gh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { PATH="$dir/bin:$PATH" CLAUDE_PLUGIN_OPTION_AUTO_TIDY="${OPT-true}" CLAUDE_PROJECT_DIR="$1" bash "$hook" </dev/null; }
# A clone with a branch pushed and squash-merged on origin's main. Pass "keep"
# to leave the branch on origin, as a merge that never deleted it does.
setup() {
  rm -rf "$dir/origin.git" "$dir/repo" "$dir"/pr-*
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
# Then before its first reply the clone stands on the latest main, and the reply says so in one line
setup; echo MERGED > "$dir/pr-feat"
out=$(run "$dir/repo")
check "E1 a merged branch hands the clone back to the latest main" '[ "$(on)" = main ] && at_main && grep -q "now stands on main" <<<"$out"'

# Given your clone sits on a branch whose pull request merged, and the branch was never deleted on GitHub
# When a session starts in it
# Then the clone stands on the latest main, the same as when the branch is gone
setup keep; echo MERGED > "$dir/pr-feat"
out=$(run "$dir/repo")
check "E2 merged with the branch still on origin, the clone stands on main" '[ "$(on)" = main ] && at_main && grep -q "now stands on main" <<<"$out"'

# Given your clone sits on a branch with an open pull request
# When a session starts in it
# Then the clone stays on that branch, and the session does its work in a worktree of its own
setup keep; echo OPEN > "$dir/pr-feat"
out=$(run "$dir/repo")
check "E3 an open pull request keeps the clone and sends the work to a worktree" '[ "$(on)" = feat ] && grep -q "worktree of its own" <<<"$out"'

# Given your clone sits on a merged branch and holds uncommitted changes
# When a session starts in it
# Then the clone stays put, and the first reply names the changed files without asking what to do with them
setup; echo MERGED > "$dir/pr-feat"; echo half > "$dir/repo/notes.txt"
out=$(run "$dir/repo")
check "E4 uncommitted changes keep the clone where it is, and are named" '[ "$(on)" = feat ] && grep -q "notes.txt" <<<"$out" && grep -q "do not ask" <<<"$out"'

# Given your clone sits on a merged branch that has commits made after the merge
# When a session starts in it
# Then those commits move to a fresh branch from the latest main, and the reply names that branch
setup; echo MERGED > "$dir/pr-feat"
echo more > "$dir/repo/more.txt"; g -C "$dir/repo" add more.txt; g -C "$dir/repo" commit -q -m "after the merge"
out=$(run "$dir/repo")
check "E5 commits after the merge move to a fresh branch from main" '[ "$(on)" = feat-after-merge ] \
  && [ "$(git -C "$dir/repo" log --format=%s origin/main..HEAD)" = "after the merge" ] && grep -q "feat-after-merge" <<<"$out"'

exit $fail
