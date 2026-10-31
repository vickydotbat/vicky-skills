#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git commit or push on a branch whose remote
# branch is gone, because its pull request merged and the branch is finished.
# It asks origin whether the branch still exists (5 seconds at most), fetches
# origin's default when it is gone, and falls back to the last fetch's record
# when origin can't answer. The refusal holds
# the move: a fresh branch from origin's default, plus the commits made after
# the merge, found as those after the newest commit whose tree the default
# branch holds. A branch that was never pushed is not checked. Off unless the
# plugin option guard_merged_branch is true.
GUARD=merged-branch-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_MERGED_BRANCH:-}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"

grep -Eq '(^|[^[:alnum:]_-])git[[:space:]]([^;&|]*[[:space:]])?(commit|push)([[:space:]]|$)' <<<"$code" || exit 0
grep -Eq -- 'push[^;&|]*(--delete|[[:space:]]-d([[:space:]]|$))' <<<"$code" && exit 0

current=$(git symbolic-ref --short -q HEAD) || exit 0
upstream=$(git for-each-ref --format='%(upstream:short)' "refs/heads/$current")
[ -n "$upstream" ] || exit 0 # mutant-ok delete: the remote and branch read below come back empty, so origin is asked for nothing and the record check exits 0 the same way
remote=$(git config "branch.$current.remote")
merge_ref=$(git config "branch.$current.merge")
GIT_TERMINAL_PROMPT=0 timeout 5 git ls-remote --exit-code "$remote" "$merge_ref" >/dev/null 2>&1
reach=$?
case $reach in
  0) exit 0 ;;
  2) ;;
  *) [ "$(git for-each-ref --format='%(upstream:track)' "refs/heads/$current")" = "[gone]" ] || exit 0 ;;
esac

default_ref=$(git symbolic-ref -q --short "refs/remotes/$remote/HEAD" 2>/dev/null)
if [ -z "$default_ref" ]; then
  for name in main master; do
    git rev-parse -q --verify "refs/remotes/$remote/$name" >/dev/null && { default_ref="$remote/$name"; break; }
  done
fi
[ -n "$default_ref" ] || default_ref="$remote/main"
# Origin answered, so bring its default branch in: the merge is on it.
[ "$reach" = 2 ] && GIT_TERMINAL_PROMPT=0 timeout 5 git fetch -q "$remote" "${default_ref#"$remote"/}" >/dev/null 2>&1

# The merge point: the newest branch commit whose tree a default-branch commit
# since the fork holds. A squash merge copies the branch's last tree.
base=$(git merge-base HEAD "$default_ref" 2>/dev/null) # mutant-ok delete: the tree list then reaches back to the first commit and finds the same merge point, only slower
trees=$(git log --format=%T "${base:+$base..}$default_ref" 2>/dev/null)
point=""
while read -r sha tree; do
  if grep -Fxq "$tree" <<<"$trees"; then point=$sha; break; fi
done < <(git log --format='%H %T' "$default_ref..HEAD" 2>/dev/null)

if [ -z "$(git rev-list "$default_ref..HEAD" 2>/dev/null)" ]; then
  moving="Every commit here is already in $default_ref, so nothing needs moving."
elif [ -n "$point" ]; then
  after=$(git log --reverse --format='  %h %s' "$point..HEAD")
  if [ -z "$after" ]; then
    moving="The merge holds every commit here, so nothing needs moving."
  else
    moving="Carry the commits made after the merge onto it with 'git cherry-pick ${point:0:12}..$current':
$after"
  fi
else
  moving="The merge point is unknown. Compare 'git log $default_ref..HEAD' with the pull request's merged head ('gh pr view --json headRefOid') before carrying anything over."
fi
refuse "$GUARD: '$current' is finished: its remote branch is gone, so its pull request merged or the branch was deleted." \
  "Carry on from a fresh branch:" \
  "  git fetch --prune && git switch -c <new-branch> ${default_ref}" \
  "$moving"
