# shellcheck shell=bash
# Sourced by merged-branch-guard and auto-tidy. `merge_point <default ref>`
# prints the newest commit on HEAD whose tree a default-branch commit since
# the fork holds, since a squash merge copies the branch's last tree. It
# prints nothing when no commit matches.
merge_point() {
  local base trees sha tree # mutant-ok delete: a local declaration: no caller reads these names
  base=$(git merge-base HEAD "$1" 2>/dev/null) # mutant-ok delete: the tree list then reaches back to the first commit and finds the same merge point, only slower
  trees=$(git log --format=%T "${base:+$base..}$1" 2>/dev/null)
  while read -r sha tree; do
    if grep -Fxq "$tree" <<<"$trees"; then printf '%s' "$sha"; return; fi
  done < <(git log --format='%H %T' "$1..HEAD" 2>/dev/null)
}
