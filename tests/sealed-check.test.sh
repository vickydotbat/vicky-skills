#!/usr/bin/env bash
# sealed-check.sh's guards, beyond its approved examples: the usage refusals,
# the reset that touches only a copy in the temp folder, and a worktree edit
# to a file git doesn't track yet.
# shellcheck disable=SC2016,SC2034 # check evals its condition strings, which read these variables
set -u
# A runner with no git identity still commits in the test's own clones.
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
dm="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/shipping/deathmatch/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
s=$(mktemp -d); trap 'rm -rf "$s"' EXIT; mkdir "$s/w" && git -C "$s/w" init -qb main && git -C "$s/w" config user.email t@t && git -C "$s/w" config user.name t
echo a > "$s/w/a" && git -C "$s/w" add a && git -C "$s/w" commit -qm a && spin=$(git -C "$s/w" rev-parse HEAD)
git clone -q "$s/w" "$s/c" && echo b > "$s/c/a"
mkdir "$s/elsewhere"; TMPDIR="$s/elsewhere" bash "$dm/sealed-check.sh" reset "$s/c" "$spin" 2>/dev/null; r=$?
check "sealed reset refuses a copy outside the temp folder, and leaves it be" '[ $r = 2 ] && [ "$(cat "$s/c/a")" = b ]'
bash "$dm/sealed-check.sh" sweep "$s/c" >/dev/null 2>&1; r=$?
check "sealed-check refuses a mode it doesn't know" '[ $r = 2 ]'
bash "$dm/sealed-check.sh" snapshot "$s/elsewhere" >/dev/null 2>&1; r=$?
check "sealed snapshot refuses a folder that is no checkout" '[ $r = 2 ]'
bash "$dm/sealed-check.sh" check "$s/c" "$spin" "$s/w" "$s/none" >/dev/null 2>&1; r=$?
check "sealed check refuses a worktree with no snapshot file" '[ $r = 2 ]'
bash "$dm/sealed-check.sh" check "$s/c" 0000000 >/dev/null 2>&1; r=$?
check "sealed check refuses a pinned commit that doesn't exist" '[ $r = 2 ]'
echo n > "$s/w/notes"; bash "$dm/sealed-check.sh" snapshot "$s/w" > "$s/snap"; echo m > "$s/w/notes"
git -C "$s/c" checkout -q -- a
out=$(bash "$dm/sealed-check.sh" check "$s/c" "$spin" "$s/w" "$s/snap" 2>&1); r=$?
check "an edit to a new file in the worktree fails the check" '[ $r = 1 ] && grep -q "worktree: ?? notes" <<<"$out"'
mkdir "$s/w/sub"; bash "$dm/sealed-check.sh" check "$s/w/sub" "$spin" >/dev/null 2>&1; r=$?
check "sealed check refuses a folder inside a checkout" '[ $r = 2 ]'
bash "$dm/sealed-check.sh" check "$s/gone" "$spin" >/dev/null 2>&1; r=$?
check "sealed check refuses a path that doesn't exist" '[ $r = 2 ]'
rm -f "$s/w/notes"; bash "$dm/sealed-check.sh" snapshot "$s/w" > "$s/snap"
out=$(bash "$dm/sealed-check.sh" check "$s/c" "$spin" "$s/w" "$s/snap" 2>&1); r=$?
check "an untouched copy and worktree pass, and say so" '[ $r = 0 ] && grep -qx "sealed: as pinned" <<<"$out"'
echo n > "$s/w/notes"; bash "$dm/sealed-check.sh" snapshot "$s/w" > "$s/snap"; mv "$s/w/notes" "$s/w/notes2"
out=$(bash "$dm/sealed-check.sh" check "$s/c" "$spin" "$s/w" "$s/snap" 2>&1); r=$?; rm -f "$s/w/notes2"
check "a renamed new file in the worktree fails the check" '[ $r = 1 ] && grep -q "notes2" <<<"$out"'
git -C "$s/c" commit -q --allow-empty -m empty
out=$(bash "$dm/sealed-check.sh" check "$s/c" "$spin" 2>&1); r=$?
check "an empty commit in the copy still fails the check" '[ $r = 1 ] && grep -qi "pinned commit" <<<"$out"'
echo b > "$s/c/a"; TMPDIR="$s" bash "$dm/sealed-check.sh" reset "$s/c" 0000000 >/dev/null 2>&1; r=$?
check "sealed reset refuses a pinned commit that doesn't exist, and leaves the copy" '[ $r = 2 ] && [ "$(cat "$s/c/a")" = b ]'
bash "$dm/sealed-check.sh" snapshot "$s/gone" >/dev/null 2>&1; r=$?
(cd "$s/w" && bash "$dm/sealed-check.sh" snapshot "" >/dev/null 2>&1); r2=$?
check "sealed snapshot refuses a missing or empty path, even from inside a checkout" '[ $r = 2 ] && [ $r2 = 2 ]'
git clone -q "$s/w" "$s/t" && mkdir "$s/t/sub" && echo b > "$s/t/a"
TMPDIR="$s" bash "$dm/sealed-check.sh" reset "$s/t/sub" "$spin" >/dev/null 2>&1; r=$?
check "sealed reset refuses a folder inside a checkout, and leaves the checkout" '[ $r = 2 ] && [ "$(cat "$s/t/a")" = b ]'
# Found in the deathmatch: git state outside the work tree hides an edit, or plants code step 5 runs.
fresh() { rm -rf "${s:?}/$1"; git clone -q "$s/w" "$s/$1"; }
fresh h; echo z >> "$s/h/a"; git -C "$s/h" update-index --assume-unchanged a
out=$(bash "$dm/sealed-check.sh" check "$s/h" "$spin" 2>&1); r=$?
check "an edit hidden by assume-unchanged fails the check" '[ $r = 1 ] && grep -q "^hidden: .* a$" <<<"$out"'
TMPDIR="$s" bash "$dm/sealed-check.sh" reset "$s/h" "$spin"; out=$(bash "$dm/sealed-check.sh" check "$s/h" "$spin" 2>&1); r=$?
check "a reset clears a hidden edit, and the copy passes" '[ $r = 0 ] && [ "$(cat "$s/h/a")" = a ]'
fresh k; git -C "$s/k" update-index --skip-worktree a
bash "$dm/sealed-check.sh" check "$s/k" "$spin" >/dev/null 2>&1; r=$?
check "a skip-worktree mark fails the check" '[ $r = 1 ]'
fresh g; git -C "$s/g" config core.hooksPath "$s/zz"
out=$(bash "$dm/sealed-check.sh" check "$s/g" "$spin" 2>&1); r=$?
check "a local git setting the clone never had fails the check" '[ $r = 1 ] && grep -q "^git: core.hookspath" <<<"$out"'
fresh p; printf '#!/bin/sh\n' > "$s/p/.git/hooks/post-checkout"
out=$(bash "$dm/sealed-check.sh" check "$s/p" "$spin" 2>&1); r=$?
check "a planted git hook fails the check" '[ $r = 1 ] && grep -q "^git: hook post-checkout" <<<"$out"'
fresh q; bash "$dm/sealed-check.sh" check "$s/q" "$spin" >/dev/null 2>&1; r=$?
check "a fresh clone passes" '[ $r = 0 ]'
bash "$dm/sealed-check.sh" copy "$s/q" holds >/dev/null; out=$(bash "$dm/sealed-check.sh" copy "$s/q" holds 2>&1); r=$?
check "a second copy for one angle reuses the first and nests no clone" '[ $r = 0 ] && [ "$out" = "$s/q-holds" ] && [ ! -e "$s/q-holds/q" ] && [ ! -e "$s/q-holds/q-holds" ]'
bash "$dm/sealed-check.sh" check "$s/q-holds" "$spin" >/dev/null 2>&1; r=$?
check "an angle's copy passes the check as made" '[ $r = 0 ]'
# Found in the deathmatch: an interrupted cp left a folder the next call took as whole.
mkdir "$s/q-half"; bash "$dm/sealed-check.sh" copy "$s/q" half >/dev/null 2>&1; r=$?
check "a half-made copy is refused, never reused" '[ $r = 1 ]'
rm -rf "$s/q-f"; out=$(bash "$dm/sealed-check.sh" copy "$s/q" f 2>/dev/null); r=$?
check "a first copy prints its path and passes" '[ $r = 0 ] && [ "$out" = "$s/q-f" ] && [ -d "$s/q-f/.git" ]'
bash "$dm/sealed-check.sh" copy "$s/q" >/dev/null 2>&1; r=$?
bash "$dm/sealed-check.sh" copy "$s/elsewhere" x >/dev/null 2>&1; r2=$?
check "copy refuses a missing angle or a folder that is no checkout" '[ $r = 2 ] && [ $r2 = 2 ] && [ ! -e "$s/elsewhere-x" ]'
exit $fail
