#!/usr/bin/env bash
# approved-spec: the sealed-copy check, ticked on the drafts page on 2026-11-21.
# After each opponent reports, deathmatch checks that the sealed copy still sits
# at the pinned commit with no changed or new tracked files, and that the
# effort's worktree is as it was when the fight started. Whether the main
# thread acts on the check is proven by evals/deathmatch/sealed-check-after-report
# and evals/deathmatch/sealed-check-second-failure.
# shellcheck disable=SC2016,SC2034 # check evals its condition strings, which read these variables
set -u
dm="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/shipping/deathmatch/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
# A repo with one tracked file, one test and an ignored build folder, cloned as
# the sealed copy the way deathmatch step 3 makes it.
mkdir "$t/w" && cd "$t/w" && git init -qb main && git config user.email t@t && git config user.name t
printf 'build/\n' > .gitignore; printf 'add() { echo $(($1 + $2)); }\n' > lib.sh; printf 'check add\n' > lib.test.sh
git add -A && git commit -qm base && pin=$(git rev-parse HEAD)
copy() { rm -rf "$t/c"; git clone -q "$t/w" "$t/c" && git -C "$t/c" config user.email t@t && git -C "$t/c" config user.name t; }

# Given an opponent that changed a tracked file in the sealed copy and left it changed
# When the main thread checks the sealed copy after that opponent reports
# Then the check fails and names the changed file
# And the main thread discards that opponent's findings
copy; printf 'add() { echo 0; }\n' > "$t/c/lib.sh"
out=$(bash "$dm/sealed-check.sh" check "$t/c" "$pin" 2>&1); r=$?
check "E1 a file an opponent changed voids its findings" \
  '[ $r = 1 ] && grep -q "lib.sh" <<<"$out" && grep -qi "discard" <<<"$out"'

# Given an opponent that added a new file git does not ignore, such as a test, in the sealed copy
# When the main thread checks the sealed copy after that opponent reports
# Then the check fails and names the new file
copy; printf 'check nothing\n' > "$t/c/extra.test.sh"
out=$(bash "$dm/sealed-check.sh" check "$t/c" "$pin" 2>&1); r=$?
check "E2 a new file an opponent added voids its findings" \
  '[ $r = 1 ] && grep -q "extra.test.sh" <<<"$out"'

# Given an opponent that committed in the sealed copy
# When the main thread checks the sealed copy after that opponent reports
# Then the check fails and says the copy is no longer at the pinned commit
copy; printf 'add() { echo 0; }\n' > "$t/c/lib.sh"; git -C "$t/c" commit -qam rigged
out=$(bash "$dm/sealed-check.sh" check "$t/c" "$pin" 2>&1); r=$?
check "E3 a commit an opponent made voids its findings" \
  '[ $r = 1 ] && grep -qi "pinned commit" <<<"$out"'

# Given an opponent that built the project, so ignored build folders filled up
# And it made a mutant and restored the file afterwards
# When the main thread checks the sealed copy after that opponent reports
# Then the check passes
copy; mkdir -p "$t/c/build" && echo obj > "$t/c/build/lib.o"
cp "$t/c/lib.sh" "$t/lib.keep" && printf 'add() { echo 0; }\n' > "$t/c/lib.sh" && cp "$t/lib.keep" "$t/c/lib.sh"
out=$(bash "$dm/sealed-check.sh" check "$t/c" "$pin" 2>&1); r=$?
check "E4 build output and a restored mutant pass" '[ $r = 0 ]'

# Given the effort's worktree as it stood when the fight started
# When an opponent changes a file in it or moves its branch, and the main thread checks after the opponent reports
# Then the check fails and names the worktree change
copy; bash "$dm/sealed-check.sh" snapshot "$t/w" > "$t/snap"
printf 'add() { echo 0; }\n' > "$t/w/lib.sh"
out=$(bash "$dm/sealed-check.sh" check "$t/c" "$pin" "$t/w" "$t/snap" 2>&1); r=$?
git -C "$t/w" checkout -q -- lib.sh
git -C "$t/w" commit -q --allow-empty -m moved
out2=$(bash "$dm/sealed-check.sh" check "$t/c" "$pin" "$t/w" "$t/snap" 2>&1); r2=$?
git -C "$t/w" reset -q --hard "$pin"
check "E5 a change to the effort's own branch fails the check" \
  '[ $r = 1 ] && grep -q "lib.sh" <<<"$out" && grep -qi "worktree" <<<"$out" && [ $r2 = 1 ] && grep -qi "worktree" <<<"$out2"'

# Given a sealed copy that failed the check
# When the main thread resets it
# Then the copy is back at the pinned commit with no changed or new tracked files
# And the ignored build folders are still there, so the next opponent need not rebuild
copy; mkdir -p "$t/c/build" && echo obj > "$t/c/build/lib.o"
printf 'add() { echo 0; }\n' > "$t/c/lib.sh"; git -C "$t/c" commit -qam rigged; echo x > "$t/c/extra.test.sh"
bash "$dm/sealed-check.sh" reset "$t/c" "$pin" >/dev/null 2>&1; rr=$?
out=$(bash "$dm/sealed-check.sh" check "$t/c" "$pin" 2>&1); r=$?
check "E6 a failed check leaves a clean copy for the next opponent" \
  '[ $rr = 0 ] && [ $r = 0 ] && [ "$(git -C "$t/c" rev-parse HEAD)" = "$pin" ] && [ ! -e "$t/c/extra.test.sh" ] && [ -f "$t/c/build/lib.o" ]'

# Given a path that is not a git checkout, or no pinned commit
# When the main thread runs the check on it
# Then the check fails with its usage line and never says the copy is clean
mkdir "$t/plain"
o1=$(bash "$dm/sealed-check.sh" check "$t/plain" "$pin" 2>&1); r1=$?
copy; o2=$(bash "$dm/sealed-check.sh" check "$t/c" 2>&1); r2=$?
check "E7 a path that is not a checkout never passes" \
  '[ $r1 -ne 0 ] && [ $r2 -ne 0 ] && grep -qi "usage" <<<"$o1$o2" && ! grep -qi "clean" <<<"$o1$o2"'

exit $fail
