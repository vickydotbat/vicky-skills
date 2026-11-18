#!/usr/bin/env bash
# SessionStart hook (startup), and PostToolUse hook (Bash) after `gh pr merge`
# or `tea pr merge`: tidies the repo's branches and worktrees, so no agent ever
# runs a cleanup or reads about one. On unless the plugin option auto_tidy is
# false or 0.
#
# A branch or worktree holds work while it has commits on no remote or
# uncommitted changes, and that work is never deleted. The tidy:
# - hands a clone left on a merged branch back to main, moving commits made
#   after the merge to a fresh branch;
# - deletes each merged local branch whose work landed, and its worktree when
#   the worktree is clean, unlocked and no process stands in it;
# - deletes the user's own remote branches whose pull request merged at their
#   last commit;
# - fast-forwards each clean checkout standing on the default branch.
# Merged means the forge says so (one gh or tea call), the upstream is gone,
# or main already holds every change.
#
# It writes nothing the agent reads. Its one-line report goes to the user as
# systemMessage, and a run with nothing done prints nothing.
set -u
# shellcheck source=merge-point.sh
. "$(dirname "$0")/merge-point.sh"
case "${CLAUDE_PLUGIN_OPTION_AUTO_TIDY:-}" in false|0) exit 0 ;; esac
# Read without jq, so a machine without it still tidies: after a tool call,
# only a command that merged a pull request starts the tidy.
payload=$(cat 2>/dev/null)
if grep -Eq '"hook_event_name"[[:space:]]*:[[:space:]]*"PostToolUse"' <<<"$payload"; then
  grep -Eq '"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*[;&|( ])?(gh|tea) +(pr|pulls) +merge([ "\\]|$)' <<<"$payload" || exit 0
fi
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
GIT_TERMINAL_PROMPT=0 timeout 15 git fetch --prune --quiet origin >/dev/null 2>&1
default=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
default=${default:-origin/main}
git rev-parse -q --verify "$default" >/dev/null || exit 0
main_name=${default#origin/}
top=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
notes=() went=() kept=()

# The forge's pull requests, one per line: <branch> <OPEN|MERGED|CLOSED> <head sha>, newest first.
prs=$(
  if out=$(timeout 10 gh pr list --state all --limit 200 --json headRefName,state,headRefOid 2>/dev/null) && [ -n "$out" ]; then
    jq -r '.[] | "\(.headRefName) \(.state) \(.headRefOid)"' <<<"$out" 2>/dev/null
  elif out=$(timeout 10 tea api 'repos/{owner}/{repo}/pulls?state=all&limit=50' </dev/null 2>/dev/null) && [ -n "$out" ]; then
    jq -r '.[] | "\(.head.ref) \(if .merged then "MERGED" elif .state == "open" then "OPEN" else "CLOSED" end) \(.head.sha)"' <<<"$out" 2>/dev/null
  fi
)
pr() { awk -v b="$1" -v f="$2" '$1 == b { print $f; exit }' <<<"$prs"; }

# landed <ref>: main since the fork holds the ref's last tree, as a squash merge does.
landed() {
  local tree base
  tree=$(git rev-parse "$1^{tree}" 2>/dev/null) || return 1
  base=$(git merge-base "$1" "$default" 2>/dev/null) || return 1
  git log --format=%T "$base..$default" 2>/dev/null | grep -Fxq "$tree"
}
# all_picked <ref>: the ref has commits main lacks, and main holds a copy of each.
all_picked() {
  [ -n "$(git rev-list -1 "$default..$1" 2>/dev/null)" ] && ! git cherry "$default" "$1" 2>/dev/null | grep -q '^+'
}
# in_use <path>: some process stands in the folder. With no way to tell, it counts as in use.
in_use() {
  local cwds
  if [ -d /proc/self ]; then
    cwds=$(for c in /proc/[0-9]*/cwd; do readlink "$c" 2>/dev/null; done)
  elif command -v lsof >/dev/null 2>&1; then
    cwds=$(lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  else
    return 0 # shortcut: no /proc and no lsof keeps every worktree, until a portable check exists
  fi
  awk -v p="$1/" 'index($0 "/", p) == 1 { f = 1 } END { exit !f }' <<<"$cwds"
}
# The repo's own worktree removal script, from a "Drop worktree: <path>" line.
drop_script() {
  local rel
  rel=$(sed -n 's/^Drop worktree:[[:space:]]*//p' "$top/docs/agents/testing.md" 2>/dev/null | head -n1)
  case "$rel" in /* | *..*) return 0 ;; esac
  [ -n "$rel" ] && [ -f "$top/$rel" ] && [ -x "$top/$rel" ] && printf '%s' "$top/$rel"
}

clone() {
  # Only the first working tree is the clone: a worktree is some session's own.
  [ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ] || return 0
  local current state point after dirty fresh
  current=$(git symbolic-ref --short -q HEAD) || return 0
  [ "$current" = "$main_name" ] && return 0
  state=$(pr "$current" 2)
  [ "$state" = OPEN ] && return 0
  [ "$state" = MERGED ] || [ "$(git for-each-ref --format='%(upstream:track)' "refs/heads/$current")" = "[gone]" ] || return 0
  dirty=$(git status --porcelain | cut -c4- | tr '\n' ' ')
  if [ -n "$dirty" ]; then
    notes+=("The clone stays on '$current', which merged, because it holds uncommitted changes: ${dirty% }.")
    return 0
  fi
  point=$(merge_point "$default")
  if [ -z "$point" ] && [ -n "$(git rev-list -1 "$default..HEAD")" ]; then
    notes+=("The clone stays on '$current': it looks merged, but none of its commits match $default.")
    return 0
  fi
  after=$(git rev-list -1 "${point:-HEAD}..HEAD")
  if [ -n "$after" ]; then
    fresh="$current-after-merge"
    if git rev-parse -q --verify "refs/heads/$fresh" >/dev/null; then
      notes+=("The clone stays on '$current': it has commits made after the merge, and a branch '$fresh' already exists.")
    elif git switch -q -c "$fresh" "$default" 2>/dev/null && git cherry-pick "$point..$current" >/dev/null 2>&1; then
      notes+=("The commits made on '$current' after its merge now sit on '$fresh', a fresh branch from $default.")
    else
      git cherry-pick --abort >/dev/null 2>&1
      git switch -q "$current" 2>/dev/null && git branch -q -D "$fresh" 2>/dev/null
      notes+=("The clone stays on '$current': its commits made after the merge did not apply cleanly to $default.")
    fi
    return 0
  fi
  if git rev-parse -q --verify "refs/heads/$main_name" >/dev/null && ! git merge-base --is-ancestor "$main_name" "$default"; then
    notes+=("The clone stays on '$current': the local $main_name has commits $default lacks.")
    return 0
  fi
  git switch -q "$main_name" 2>/dev/null && git merge -q --ff-only "$default" >/dev/null 2>&1 || return 0
  notes+=("The clone was on '$current', whose pull request merged, so it now stands on $main_name at $default.")
}
clone

git worktree prune >/dev/null 2>&1
# Each local branch: delete it, and its worktree, when it merged and its work landed.
while read -r b track; do
  [ "$b" = "$main_name" ] && continue
  sha=$(git rev-parse "refs/heads/$b")
  state=$(pr "$b" 2)
  [ "$state" = OPEN ] && continue
  { [ "$state" = MERGED ] || [ "$track" = "[gone]" ] || all_picked "$b"; } || continue
  if ! { [ "$sha" = "$(pr "$b" 3)" ] || [ -n "$(git branch -r --contains "$sha" 2>/dev/null)" ] || landed "$b" || all_picked "$b"; }; then
    kept+=("$b (commits made after the merge)")
    continue
  fi
  wt=$(git worktree list --porcelain | awk -v r="refs/heads/$b" '/^worktree /{p=substr($0, 10)} $0 == "branch " r {print p; exit}')
  if [ -n "$wt" ]; then
    [ "$wt" = "$top" ] && continue
    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then kept+=("$b (uncommitted changes)"); continue; fi
    if git worktree list --porcelain | awk -v p="worktree $wt" '$0 == p {f = 1; next} /^worktree /{f = 0} f && /^locked/ {l = 1} END {exit !l}'; then kept+=("$b (locked worktree)"); continue; fi
    if in_use "$wt"; then kept+=("$b (a session is working in it)"); continue; fi
    drop=$(drop_script)
    if [ -n "$drop" ]; then (cd "$top" && "$drop" "$wt") >/dev/null 2>&1; else git worktree remove "$wt" >/dev/null 2>&1; fi
    [ -d "$wt" ] && { kept+=("$b (its worktree would not come off)"); continue; }
    git worktree prune >/dev/null 2>&1
  fi
  git branch -q -D "$b" >/dev/null 2>&1 && went+=("$b")
done < <(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads)

# The user's own remote branches whose work landed.
me=$(git config user.email)
while read -r rb; do
  b=${rb#origin/}
  [ "$b" = "$main_name" ] || [ "$b" = HEAD ] || [ -z "$me" ] && continue
  [ "$(pr "$b" 2)" = OPEN ] && continue
  authors=$(git log --format=%ae "$default..$rb" 2>/dev/null | sort -u)
  [ "$authors" = "$me" ] || continue
  sha=$(git rev-parse "$rb")
  if [ -n "$(pr "$b" 1)" ]; then [ "$(pr "$b" 2)" = MERGED ] && [ "$(pr "$b" 3)" = "$sha" ] || continue
  else landed "$rb" || all_picked "$rb" || continue
  fi
  GIT_TERMINAL_PROMPT=0 timeout 15 git push -q origin --delete "$b" >/dev/null 2>&1 && went+=("origin/$b")
done < <(git for-each-ref --format='%(refname:short)' refs/remotes/origin)

# Fast-forward each clean checkout on the default branch, worktrees and nested repos.
for p in $(git worktree list --porcelain | sed -n 's/^worktree //p') "$top"/*/.git "$top"/*/*/.git; do
  p=${p%/.git}
  [ -e "$p/.git" ] || continue
  d=$(git -C "$p" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null); d=${d:-origin/main}
  [ "$(git -C "$p" symbolic-ref --short -q HEAD)" = "${d#origin/}" ] || continue
  [ -z "$(git -C "$p" status --porcelain 2>/dev/null)" ] || continue
  [ "$(git -C "$p" rev-parse --git-common-dir 2>/dev/null)" = "$(git rev-parse --git-common-dir)" ] || GIT_TERMINAL_PROMPT=0 timeout 15 git -C "$p" fetch -q origin >/dev/null 2>&1
  [ "$(git -C "$p" rev-parse HEAD)" = "$(git -C "$p" rev-parse "$d" 2>/dev/null)" ] && continue
  git -C "$p" merge -q --ff-only "$d" >/dev/null 2>&1 && notes+=("$(basename "$p") caught up with $d.")
done

[ ${#went[@]} -gt 0 ] || [ ${#kept[@]} -gt 0 ] || [ ${#notes[@]} -gt 0 ] || exit 0
line="✨ Tidied: ${#went[@]} branches."
join() { local out="" x; for x; do out+="${out:+, }$x"; done; printf '%s' "$out"; }
[ ${#went[@]} -gt 0 ] && line+=" Gone: $(join "${went[@]}")."
[ ${#kept[@]} -gt 0 ] && line+=" Kept: $(join "${kept[@]}")."
[ ${#notes[@]} -gt 0 ] && line+=" ${notes[*]}"
line=$(tr -d '\000-\037' <<<"$line"); line=${line//\\/\\\\}; line=${line//\"/\\\"}
printf '{"systemMessage":"%s"}\n' "$line"
exit 0
