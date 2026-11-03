#!/usr/bin/env bash
# The clone takeover's decisions beyond E1 to E5. E6 and E7 held before the
# build, so they are plain regression tests.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/auto-tidy.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
mkdir "$dir/bin" "$dir/nogh"
cat > "$dir/bin/gh" <<EOF
#!/usr/bin/env bash
f="$dir/pr-\$3"
[ -f "\$f" ] || exit 1
cat "\$f"
EOF
chmod +x "$dir/bin/gh"
# A PATH with git and the shell tools but no gh.
for t in git bash timeout grep awk cut tr sed cat dirname; do ln -s "$(command -v "$t")" "$dir/nogh/$t"; done
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { PATH="${BIN:-$dir/bin:$PATH}" CLAUDE_PLUGIN_OPTION_AUTO_TIDY="${OPT-true}" CLAUDE_PROJECT_DIR="${2:-$dir/repo}" bash "$hook" </dev/null; }
commit() { echo "$2" > "$dir/repo/$1"; git -C "$dir/repo" add "$1"; git -C "$dir/repo" commit -q -m "$3"; }
setup() {
  rm -rf "$dir/origin.git" "$dir/away.git" "$dir/repo" "$dir"/pr-* "$dir/wt"
  git init -q --bare -b main "$dir/origin.git"
  git clone -q "$dir/origin.git" "$dir/repo" 2>/dev/null
  git -C "$dir/repo" commit -q --allow-empty -m base
  git -C "$dir/repo" push -q origin HEAD:main 2>/dev/null
  git -C "$dir/repo" switch -q -c feat
  commit work.txt work work
  git -C "$dir/repo" push -q -u origin feat 2>/dev/null
  git clone -q "$dir/origin.git" "$dir/merger" 2>/dev/null
  git -C "$dir/merger" merge -q --squash origin/feat >/dev/null 2>&1; git -C "$dir/merger" commit -q -m "feat (#1)"
  git -C "$dir/merger" push -q origin main 2>/dev/null; rm -rf "$dir/merger"
  git -C "$dir/origin.git" branch -q -D feat
}
on() { git -C "$dir/repo" symbolic-ref --short -q HEAD; }

# E6. Given your clone sits on a branch with no pull request and commits that exist nowhere else
#     When a session starts in it
#     Then the clone stays on that branch
setup; git -C "$dir/repo" switch -q -c solo main; commit solo.txt solo solo
out=$(run)
check "E6 unpushed work is never taken over" '[ "$(on)" = solo ] && ! grep -q "solo" <<<"$out"'

# E7. Given the auto_tidy setting switched off
#     When a session starts in a clone on a merged branch
#     Then the clone stays on that branch and nothing is said about it
setup; echo MERGED > "$dir/pr-feat"
out=$(OPT=false run)
check "E7 switched off, nothing moves" '[ "$(on)" = feat ] && [ -z "$out" ]'

setup; echo MERGED > "$dir/pr-feat"; git -C "$dir/repo" switch -q --detach origin/main; git -C "$dir/repo" worktree add -q "$dir/wt" feat 2>/dev/null
out=$(run x "$dir/wt")
check "a session in a worktree on a merged branch moves nothing" '[ "$(git -C "$dir/wt" symbolic-ref --short HEAD)" = feat ] && ! grep -q "stands on" <<<"$out"'

# Fetch records origin's default branch again, so origin goes out of reach here.
setup; echo MERGED > "$dir/pr-feat"; git -C "$dir/repo" fetch -q origin; git -C "$dir/repo" remote set-head origin -d; mv "$dir/origin.git" "$dir/away.git"
out=$(run)
check "with origin out of reach and no recorded default, origin's main is the default" '[ "$(on)" = main ] && grep -q "now stands on main" <<<"$out"'

setup; git -C "$dir/origin.git" branch -q -m main trunk; git -C "$dir/origin.git" symbolic-ref HEAD refs/heads/trunk
git -C "$dir/repo" remote set-head origin -d
out=$(run)
check "a remote whose default is trunk hands the clone to trunk" '[ "$(on)" = trunk ] && grep -q "now stands on trunk at origin/trunk" <<<"$out"'

setup; git -C "$dir/repo" fetch -q origin; git -C "$dir/repo" reset -q --hard origin/main
out=$(run)
check "a branch whose commits all sit on main moves to main" '[ "$(on)" = main ] && grep -q "now stands on main" <<<"$out"'

setup
out=$(BIN="$dir/nogh" run)
check "without gh, a gone upstream still counts as merged" '[ "$(on)" = main ] && grep -q "now stands on main" <<<"$out"'

setup; git -C "$dir/repo" switch -q main; git -C "$dir/repo" merge -q --ff-only origin/main
out=$(run)
check "a clone on main stays and hears nothing of it" '[ "$(on)" = main ] && ! grep -q "auto_tidy: the clone\|stands on" <<<"$out"'

setup; echo MERGED > "$dir/pr-feat"; echo changed > "$dir/repo/work.txt"; git -C "$dir/repo" commit -q --amend -am reworded
out=$(run)
check "a branch with no merge point stays put" '[ "$(on)" = feat ] && grep -q "none of its commits match" <<<"$out"'

setup; echo MERGED > "$dir/pr-feat"; git -C "$dir/repo" branch -q -f main main; git -C "$dir/repo" switch -q main
commit local.txt l "local only"; git -C "$dir/repo" switch -q feat
out=$(run)
check "a local main with commits origin lacks keeps the clone" '[ "$(on)" = feat ] && grep -q "local main has commits" <<<"$out"'

setup; echo MERGED > "$dir/pr-feat"
git clone -q "$dir/origin.git" "$dir/other" 2>/dev/null; echo theirs > "$dir/other/work.txt"
git -C "$dir/other" commit -qam theirs; git -C "$dir/other" push -q origin main 2>/dev/null; rm -rf "$dir/other"
git -C "$dir/repo" fetch -q origin; commit work.txt mine "after the merge"
out=$(run)
check "commits that clash with main keep the clone and leave no stray branch" '[ "$(on)" = feat ] && grep -q "did not apply cleanly" <<<"$out" \
  && ! git -C "$dir/repo" rev-parse -q --verify refs/heads/feat-after-merge >/dev/null && [ -z "$(git -C "$dir/repo" status --porcelain)" ]'

setup; echo MERGED > "$dir/pr-feat"; git -C "$dir/repo" branch -q feat-after-merge main
git -C "$dir/repo" switch -q feat-after-merge; commit keep.txt k "only here"; git -C "$dir/repo" switch -q feat
commit more.txt more "after the merge"
out=$(run)
check "an existing after-merge branch is never touched" '[ "$(on)" = feat ] && grep -q "already exists" <<<"$out" \
  && [ "$(git -C "$dir/repo" log -1 --format=%s feat-after-merge)" = "only here" ]'

exit $fail
