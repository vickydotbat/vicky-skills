#!/usr/bin/env bash
# PreToolUse and PostToolUse hook (Bash): every worktree lives in its repo's
# own .claude/worktrees folder, and a merged one is cleaned up. Off unless the
# plugin option guard_worktree_place is on.
#
# Before `git worktree add`: refuses a path outside <main clone>/.claude/worktrees,
# with a steer to .claude/worktrees/<branch>. When it lets one through, it adds
# .claude/worktrees/ to the repo's .git/info/exclude unless git already ignores
# it, so the main clone never lists its worktrees.
#
# After `git merge <branch>`: when <branch> is checked out in a worktree and no
# merge is still in progress, it removes the worktree and the branch once every
# commit has landed and nothing is uncommitted. Otherwise the worktree stays,
# and the agent is told what is left: the commits still to land, or the
# uncommitted changes. A pull request merged on the forge is marie-kondo's.
#
# A repo that names its own removal script on a "Drop worktree: <path>" line of
# docs/agents/testing.md (the path is relative to the main clone, and the file
# must be executable) has it named in place of git worktree remove, and run
# with the worktree's path for a landed branch. git worktree remove leaves
# untracked files behind, and files a container owns. A script that fails
# leaves the worktree and branch, and the agent is told its output.
GUARD=worktree-place
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_WORKTREE_PLACE:-}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"
# shellcheck source=assign-expand.sh
. "$(dirname "$0")/assign-expand.sh"

event=$(jq -r '.hook_event_name // "PreToolUse"' <<<"$payload")
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
main=$(dirname "$common")
home="$main/.claude/worktrees"

# Tells the agent something after the command ran.
tell() {
  jq -nc --arg t "$1" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $t}}'
}

# The worktree a local branch is checked out in, other than the main clone.
worktree_of() {
  git worktree list --porcelain | awk -v ref="refs/heads/$1" -v main="$main" '
    /^worktree / { path = substr($0, 10) }
    $0 == "branch " ref && path != main { print path; exit }'
}

# The repo's own worktree removal script, or nothing.
drop_script() {
  local rel # mutant-ok delete: the name would only be global, and nothing else reads it
  rel=$(sed -n 's/^Drop worktree:[[:space:]]*//p' "$main/docs/agents/testing.md" 2>/dev/null | head -n1)
  case "$rel" in /* | *..*) return 0 ;; esac # a path stays inside the main clone
  [ -n "$rel" ] && [ -f "$main/$rel" ] && [ -x "$main/$rel" ] && printf '%s' "$rel" # mutant-ok: a blank line names the main clone, a folder, and -f refuses it
}

check_add() {
  local words=($1) i=0 path="" name="" abs
  while ((i < ${#words[@]})) && [ "${words[i]}" != add ]; do i=$((i + 1)); done
  for ((i = i + 1; i < ${#words[@]}; i++)); do
    case "${words[i]}" in
      -b | -B) name=${words[i + 1]:-}; i=$((i + 1)) ;;
      --reason) i=$((i + 1)) ;;
      -*) ;;
      *) path=${words[i]}; break ;;
    esac
  done
  [ -n "$path" ] || return 0
  # A path named through a variable the same command sets reads as its value.
  path=$(expand_assigns "$path" "$command")
  path=${path/#\~\//$HOME/}
  abs=$(realpath -m -- "$path")
  if [[ $abs != "$home"/* ]]; then
    name=${name:-$(basename -- "$abs")}
    refuse "$GUARD: refused. Worktrees live in this repo's own folder, $home." \
      "Add this one at .claude/worktrees/$name inside the repo: git worktree add ${main}/.claude/worktrees/$name with the same branch and options."
  fi
  if ! git -C "$main" check-ignore -q ".claude/worktrees/x"; then
    mkdir -p "$common/info"
    printf '.claude/worktrees/\n' >>"$common/info/exclude"
  fi
}

check_merge() {
  local words=(${1#*merge}) i branch wt left dirty drop out how
  drop=$(drop_script)
  [ -e "$(git rev-parse --git-dir)/MERGE_HEAD" ] && return 0
  for ((i = 0; i < ${#words[@]}; i++)); do
    case "${words[i]}" in
      -m | -s | -X | -F | --strategy | --strategy-option | --file) i=$((i + 1)); continue ;;
      -*) continue ;;
    esac
    branch=${words[i]}
    wt=$(worktree_of "$branch")
    [ -n "$wt" ] || continue
    how="git worktree remove $wt and git branch -d $branch"
    [ -z "$drop" ] || how="$drop $wt, then git branch -d $branch"
    dirty=$(git -C "$wt" status --porcelain)
    if [ -n "$dirty" ]; then
      tell "$GUARD: $wt, the worktree of $branch, has uncommitted changes, so it stays. Commit or move them, then remove it with $how."
      continue
    fi
    left=$(git log --format='%h %s' "HEAD..refs/heads/$branch")
    if [ -n "$left" ]; then
      tell "$GUARD: $wt stays: these commits of $branch have not landed on $(git rev-parse --abbrev-ref HEAD):
$left
Land them, then remove the worktree with $how."
      continue
    fi
    if [ -n "$drop" ]; then
      if ! out=$(cd "$main" && "$main/$drop" "$wt" 2>&1); then
        tell "$GUARD: $branch has landed, but $drop could not remove $wt, so the worktree and branch stay: $out"
        continue
      fi
      if git branch -q -d "$branch" 2>/dev/null; then
        tell "$GUARD: $branch has landed, so $drop removed its worktree $wt and the branch is removed."
      else
        tell "$GUARD: $drop removed the worktree $wt, but the branch $branch is still there."
      fi
      continue
    fi
    git worktree remove -- "$wt" && git branch -q -d "$branch" &&
      tell "$GUARD: $branch has landed, so its worktree $wt and the branch are removed."
  done
}

while IFS= read -r segment; do
  if [ "$event" = PostToolUse ]; then
    grep -Eq '(^|[[:space:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+merge([[:space:]]|$)' <<<"$segment" && check_merge "$segment"
  else
    grep -Eq '(^|[[:space:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+worktree[[:space:]]+add([[:space:]]|$)' <<<"$segment" && check_add "$segment"
  fi
done < <(tr ';&|\n' '\n' <<<"$code")
exit 0 # mutant-ok delete: the loop above leaves status 0
