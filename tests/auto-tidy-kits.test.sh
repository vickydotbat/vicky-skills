#!/usr/bin/env bash
# auto-tidy removes an over-to-you sitting's kits once its branch's pull
# request merged or closed: only a file the manifest lists whose hash still
# matches, and a folder only once it is empty. An edited kit, an unlisted file
# and an open or unknown pull request's kits stay.
# shellcheck disable=SC2016,SC2034,SC2329 # check() evals its single-quoted condition later, which uses these
set -u
. "$(dirname "$0")/lib/auto-tidy-fixture.sh"
# kits <branch>: a kit folder holding two kits, inside a git-ignored folder the
# kits did not make, listed in the branch's manifest.
kits() {
  local r=$dir/repo m
  printf 'scratch/\n' > "$r/.git/info/exclude"
  mkdir -p "$r/scratch/ot1/deep"; echo a > "$r/scratch/ot1/a.lua"; echo b > "$r/scratch/ot1/deep/b.lua"
  m="$r/.git/over-to-you-kits/${1//\//%2F}"; mkdir -p "${m%/*}"
  { printf 'dir\t%s\n' "$r/scratch/ot1"
    for f in a.lua deep/b.lua; do printf '%s\t%s\n' "$(sha256sum "$r/scratch/ot1/$f" | cut -d' ' -f1)" "$r/scratch/ot1/$f"; done; } > "$m"
}
manifest() { echo "$dir/repo/.git/over-to-you-kits/${1//\//%2F}"; }

setup; branch feat; merge feat; on_main; kits feat
out=$(run)
check "a merged branch's kits whose hashes match are deleted, with their emptied folders" '[ ! -e "$dir/repo/scratch/ot1" ] && [ -d "$dir/repo/scratch" ]'
check "the report names the kits it removed, and calls nothing edited" 'seen "$out" | grep -q "2 over-to-you kits" && ! seen "$out" | grep -q edited'
check "the manifest goes once its kits are dealt with" '[ ! -e "$(manifest feat)" ]'

setup; branch feat; merge feat; on_main; kits feat
echo edited >> "$dir/repo/scratch/ot1/a.lua"; echo mine > "$dir/repo/scratch/ot1/notes.txt"
out=$(run)
check "an edited kit stays, and the report says why" '[ -f "$dir/repo/scratch/ot1/a.lua" ] && seen "$out" | grep -qF "scratch/ot1/a.lua (edited since its sitting)"'
check "an unlisted file stays, and so does the folder that holds it" '[ -f "$dir/repo/scratch/ot1/notes.txt" ]'
check "the unedited kit beside them still goes" '[ ! -e "$dir/repo/scratch/ot1/deep" ]'

setup; branch feat; merge feat; on_main; kits feat; rm "$dir/repo/scratch/ot1/a.lua"
out=$(run)
check "a kit already gone is no edited kit" '! seen "$out" | grep -q edited && [ ! -e "$dir/repo/scratch/ot1" ]'

setup; branch feat; echo "feat OPEN $(git -C "$dir/repo" rev-parse feat)" > "$dir/prs"; kits feat
run >/dev/null
check "an open pull request's kits stay, with their manifest" '[ -f "$dir/repo/scratch/ot1/a.lua" ] && [ -f "$(manifest feat)" ]'

setup; branch feat; echo "feat CLOSED $(git -C "$dir/repo" rev-parse feat)" > "$dir/prs"; kits feat
run >/dev/null
check "a closed pull request's kits are deleted" '[ ! -e "$dir/repo/scratch/ot1" ]'

setup; branch feat; rm -f "$dir/prs"; kits feat
run >/dev/null
check "with no forge answer the kits stay" '[ -f "$dir/repo/scratch/ot1/a.lua" ]'

setup; on_main; echo "fix/x MERGED 0000" > "$dir/prs"; kits fix/x
run >/dev/null
check "a branch name with a slash finds its manifest" '[ ! -e "$dir/repo/scratch/ot1" ]'

setup; branch feat; merge feat; on_main; kits feat
OPT=false run >/dev/null
check "auto_tidy off leaves the kits" '[ -f "$dir/repo/scratch/ot1/a.lua" ]'

setup; branch feat; merge feat; on_main; kits feat
git -C "$dir/repo" add -f scratch/ot1/a.lua && git -C "$dir/repo" commit -qm "keep a.lua"
out=$(run)
check "a kit git tracks stays, and the report says why" '[ -f "$dir/repo/scratch/ot1/a.lua" ] && [ -z "$(git -C "$dir/repo" status --porcelain)" ] && seen "$out" | grep -qF "scratch/ot1/a.lua (tracked)"'
check "the untracked kit beside it still goes" '[ ! -e "$dir/repo/scratch/ot1/deep" ]'
exit "$fail"
