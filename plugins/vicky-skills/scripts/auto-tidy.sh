#!/usr/bin/env bash
# SessionStart hook (startup only): when the plugin option auto_tidy is on, it
# prunes origin's branches and asks the agent to run marie-kondo if a local
# branch's upstream is gone. A merge done in the browser leaves its branch
# behind, and the next session in the repo is the first to see it. Off by
# default. The deleting stays in the skill, which reads each pull request's state.
#
# It also changes the checkout: a clone left on a merged branch goes back to
# main, so the next effort starts fresh. Anything the move could lose keeps
# the clone where it is.
set -u
# shellcheck source=merge-point.sh
. "$(dirname "$0")/merge-point.sh"
case "${CLAUDE_PLUGIN_OPTION_AUTO_TIDY:-}" in true|1) ;; *) exit 0 ;; esac
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0 # mutant-ok delete: outside a repository every git call below fails and nothing is gone
GIT_TERMINAL_PROMPT=0 timeout 15 git fetch --prune --quiet origin >/dev/null 2>&1

clone() {
  # Only the first working tree is the clone: a worktree is some session's own.
  [ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ] || return 0
  local current default state point after dirty fresh main # mutant-ok delete: a local declaration: no caller reads these names
  current=$(git symbolic-ref --short -q HEAD) || return 0
  default=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
  default=${default:-origin/main}
  [ "$current" = "${default#origin/}" ] && return 0 # mutant-ok delete: a default branch never has a merged pull request of its own, so the checks below return the same way
  state=$(timeout 5 gh pr view "$current" --json state -q .state 2>/dev/null)
  if [ "$state" = OPEN ]; then
    echo "auto_tidy: the clone is on '$current', which has an open pull request, so it is a test stage. Leave the clone there and do this session's work in a worktree of its own."
    return 0 # mutant-ok delete: an open pull request's branch is still on origin, so the merged check below returns the same way
  fi
  [ "$state" = MERGED ] || [ "$(git for-each-ref --format='%(upstream:track)' "refs/heads/$current")" = "[gone]" ] || return 0
  dirty=$(git status --porcelain | cut -c4- | tr '\n' ' ')
  if [ -n "$dirty" ]; then
    echo "auto_tidy: '$current' merged, but the clone holds uncommitted changes, so it stays put: ${dirty% }. These are unpushed work, so they stay. Name these files in your first reply and do not ask."
    return 0
  fi
  point=$(merge_point "$default")
  if [ -z "$point" ] && [ -n "$(git rev-list -1 "$default..HEAD")" ]; then
    echo "auto_tidy: '$current' looks merged, but none of its commits match origin's main, so the clone stays put. Compare it with its pull request before moving anything."
    return 0
  fi
  after=$(git rev-list -1 "${point:-HEAD}..HEAD")
  if [ -n "$after" ]; then
    fresh="$current-after-merge"
    if git rev-parse -q --verify "refs/heads/$fresh" >/dev/null; then
      echo "auto_tidy: '$current' merged and has commits made after the merge, but a branch '$fresh' already exists. The clone stays put: run marie-kondo to carry them over."
    elif git switch -q -c "$fresh" "$default" 2>/dev/null && git cherry-pick "$point..$current" >/dev/null 2>&1; then
      echo "auto_tidy: '$current' merged, and the commits made after the merge now sit on '$fresh', a fresh branch from $default. Name that branch in one line in your first reply."
    else
      git cherry-pick --abort >/dev/null 2>&1
      git switch -q "$current" 2>/dev/null && git branch -q -D "$fresh" 2>/dev/null
      echo "auto_tidy: '$current' merged and has commits made after the merge, which did not apply cleanly to $default. The clone stays put: run marie-kondo to carry them over."
    fi
    return 0
  fi
  main=${default#origin/}
  if git rev-parse -q --verify "refs/heads/$main" >/dev/null && ! git merge-base --is-ancestor "$main" "$default"; then
    echo "auto_tidy: '$current' merged, but the local $main has commits $default lacks, so the clone stays put. Those commits are unpushed work: name them in your first reply and do not ask."
    return 0
  fi
  git switch -q "$main" 2>/dev/null && git merge -q --ff-only "$default" >/dev/null 2>&1 || return 0
  echo "auto_tidy: the clone was on '$current', whose pull request merged, so it now stands on $main at $default. Say so in one line in your first reply."
}
clone

gone=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
  | awk '$2 == "[gone]" { printf "%s ", $1 }')
[ -n "$gone" ] || exit 0
echo "auto_tidy: these local branches lost their upstream: ${gone% }. Before your first reply, run the marie-kondo skill without asking the user, and give its report in one line."
exit 0 # mutant-ok delete: the line above leaves status 0, so the script ends the same way
