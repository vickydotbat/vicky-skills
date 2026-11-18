#!/usr/bin/env bash
# SessionStart hook (startup), and PostToolUse hook (Bash) after `gh pr merge`
# or `tea pr merge`: deletes merged branches and worktrees, your own merged
# remote branches, and fast-forwards clean checkouts on main, so no agent runs
# a cleanup. Work on no remote and uncommitted changes always stay. On unless
# the plugin option auto_tidy is false or 0: the user chose on by default.
#
# It writes nothing the agent reads. Its one-line report goes to the user as
# systemMessage. It runs in the foreground, since an async hook's
# systemMessage goes to the agent instead.
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
# The folder the session stands in, whose worktree is never removed.
here=$(sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$payload"); here=${here%%$'\n'*}
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0 # mutant-ok delete: outside a repo the default-branch check below exits the same way
GIT_TERMINAL_PROMPT=0 timeout 15 git fetch --prune --quiet origin >/dev/null 2>&1
default=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
default=${default:-origin/main}
git rev-parse -q --verify "$default" >/dev/null || exit 0 # mutant-ok delete: with no default branch every comparison below fails, so nothing goes
main_name=${default#origin/}
top=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
notes=() went=() kept=()

# The forge's pull requests, one per line: <branch> <OPEN|MERGED|CLOSED> <head sha>, newest first.
prs=$(
  if out=$(timeout 10 gh pr list --state all --limit 200 --json headRefName,state,headRefOid 2>/dev/null) && [ -n "$out" ]; then # mutant-ok: gh answers either a list or a failure, never success with no output
    jq -r '.[] | "\(.headRefName) \(.state) \(.headRefOid)"' <<<"$out" 2>/dev/null
  elif out=$(timeout 10 tea api 'repos/{owner}/{repo}/pulls?state=all&limit=50' </dev/null 2>/dev/null) && [ -n "$out" ]; then # mutant-ok: tea answers either a list or a failure, never success with no output
    jq -r '.[] | "\(.head.ref) \(if .merged then "MERGED" elif .state == "open" then "OPEN" else "CLOSED" end) \(.head.sha)"' <<<"$out" 2>/dev/null
  fi
)
pr() { awk -v b="$1" -v f="$2" '$1 == b { print $f; exit }' <<<"$prs"; }

# landed <ref>: main since the fork holds the ref's last tree, as a squash merge does.
landed() {
  local tree base # mutant-ok delete: a local declaration: no caller reads these names
  tree=$(git rev-parse "$1^{tree}" 2>/dev/null) || return 1
  base=$(git merge-base "$1" "$default" 2>/dev/null) || return 1
  git log --format=%T "$base..$default" 2>/dev/null | grep -Fxq "$tree"
}
# all_picked <ref>: the ref has commits main lacks, and main holds a copy of each.
all_picked() {
  [ -n "$(git rev-list -1 "$default..$1" 2>/dev/null)" ] && ! git cherry "$default" "$1" 2>/dev/null | grep -q '^+'
}
# merged <branch> <upstream track>: the forge says merged, the upstream went
# with no closed pull request, or main holds a copy of every commit.
merged() {
  local state; state=$(pr "$1" 2)
  [ "$state" = MERGED ] || { [ "$2" = "[gone]" ] && [ "$state" != CLOSED ]; } || all_picked "$1"
}
# in_use <path>: the session or some process stands in the folder. With no way to tell, it counts as in use.
in_use() {
  local cwds # mutant-ok delete: a local declaration: no caller reads this name
  case "$here/" in "$1"/*) return 0 ;; esac
  if [ -d /proc/self ]; then
    cwds=$(for c in /proc/[0-9]*/cwd; do readlink "$c" 2>/dev/null; done)
  elif command -v lsof >/dev/null 2>&1; then
    cwds=$(lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p') # mutant-ok: only a machine with no /proc reaches this line, and the tests run on Linux
  else
    return 0 # mutant-ok: only a machine with no /proc and no lsof reaches this line; shortcut: no /proc and no lsof keeps every worktree, until a portable check exists
  fi
  awk -v p="$1/" 'index($0 "/", p) == 1 { f = 1 } END { exit !f }' <<<"$cwds"
}
# The repo's own worktree removal script, from a "Drop worktree: <path>" line.
drop_script() {
  local rel # mutant-ok delete: a local declaration: no caller reads this name
  rel=$(sed -n 's/^Drop worktree:[[:space:]]*//p' "$top/docs/agents/testing.md" 2>/dev/null | head -n1)
  case "$rel" in /* | *..*) return 0 ;; esac
  [ -n "$rel" ] && [ -f "$top/$rel" ] && [ -x "$top/$rel" ] && printf '%s' "$top/$rel" # mutant-ok: a blank line names the main clone, a folder, and -x alone then runs a folder, which fails and keeps the worktree
}

clone() {
  # Only the first working tree is the clone: a worktree is some session's own.
  [ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ] || return 0
  local current state point after dirty fresh # mutant-ok delete: a local declaration: no caller reads these names
  current=$(git symbolic-ref --short -q HEAD) || return 0
  [ "$current" = "$main_name" ] && return 0 # mutant-ok delete: the default branch never counts as merged below, so the clone returns the same way
  [ "$(pr "$current" 2)" = OPEN ] && return 0
  merged "$current" "$(git for-each-ref --format='%(upstream:track)' "refs/heads/$current")" || return 0
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
  git switch -q "$main_name" 2>/dev/null || return 0 # the fast-forward below brings it to $default
  notes+=("The clone was on '$current', whose pull request merged, so it now stands on $main_name at $default.")
}
clone

git worktree prune >/dev/null 2>&1 # mutant-ok delete: a worktree whose folder is gone only adds entries no check below matches
# Each local branch: delete it, and its worktree, when it merged and its work landed.
while read -r b track; do
  [ "$b" = "$main_name" ] && continue # mutant-ok delete: the default branch never counts as merged, so the loop skips it anyway
  sha=$(git rev-parse "refs/heads/$b")
  [ "$(pr "$b" 2)" = OPEN ] && continue
  merged "$b" "$track" || continue
  if ! { { [ "$(pr "$b" 2)" = MERGED ] && [ "$sha" = "$(pr "$b" 3)" ]; } || [ -n "$(git branch -r --contains "$sha" 2>/dev/null)" ] || landed "$b" || all_picked "$b"; }; then
    kept+=("$b (commits made after the merge)")
    continue
  fi
  wt=$(git worktree list --porcelain | awk -v r="refs/heads/$b" '/^worktree /{p=substr($0, 10)} $0 == "branch " r {print p; exit}')
  if [ -n "$wt" ]; then
    [ "$wt" = "$top" ] && continue # mutant-ok delete: the clone stands in its own folder, so the in-use check keeps it anyway
    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then kept+=("$b (uncommitted changes)"); continue; fi
    if git worktree list --porcelain | awk -v p="worktree $wt" '$0 == p {f = 1; next} /^worktree /{f = 0} f && /^locked/ {l = 1} END {exit !l}'; then kept+=("$b (locked worktree)"); continue; fi
    if in_use "$wt"; then kept+=("$b (a session is working in it)"); continue; fi
    drop=$(drop_script)
    if [ -n "$drop" ]; then (cd "$top" && "$drop" "$wt") >/dev/null 2>&1; else git worktree remove "$wt" >/dev/null 2>&1; fi
    [ -d "$wt" ] && { kept+=("$b (its worktree would not come off)"); continue; }
    git worktree prune >/dev/null 2>&1 # mutant-ok delete: the next git worktree list only lists a removed worktree as prunable
  fi
  git branch -q -D "$b" >/dev/null 2>&1 && went+=("$b")
done < <(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads)

# The user's own remote branches whose work landed.
me=$(git config user.email)
while read -r rb; do
  b=${rb#origin/}
  [ "$b" = "$main_name" ] && continue # mutant-ok delete: main has no commits beyond itself, so the author check below skips it too
  [ "$(pr "$b" 2)" = OPEN ] && continue # mutant-ok delete: an open pull request fails the merged check on the line after next
  authors=$(git log --format=%ae "$default..$rb" 2>/dev/null | sort -u)
  [ "$authors" = "$me" ] || continue
  sha=$(git rev-parse "$rb")
  if [ -n "$(pr "$b" 1)" ]; then [ "$(pr "$b" 2)" = MERGED ] && [ "$(pr "$b" 3)" = "$sha" ] || continue
  else landed "$rb" || all_picked "$rb" || continue
  fi
  GIT_TERMINAL_PROMPT=0 timeout 15 git push -q origin --delete "$b" >/dev/null 2>&1 && went+=("origin/$b")
done < <(git for-each-ref --format='%(refname:short)' refs/remotes/origin)

# Fast-forward each clean checkout, the clone or a worktree, that stands on the default branch.
while read -r p; do
  [ "$(git -C "$p" symbolic-ref --short -q HEAD)" = "$main_name" ] || continue
  [ -z "$(git -C "$p" status --porcelain 2>/dev/null)" ] || continue
  [ "$(git -C "$p" rev-parse HEAD)" = "$(git rev-parse "$default")" ] && continue
  git -C "$p" merge -q --ff-only "$default" >/dev/null 2>&1 && notes+=("${p##*/} caught up with $default.")
done < <(git worktree list --porcelain | sed -n 's/^worktree //p')

[ ${#went[@]} -gt 0 ] || [ ${#kept[@]} -gt 0 ] || [ ${#notes[@]} -gt 0 ] || exit 0
line="✨ Tidied: ${#went[@]} branches."
join() { local out="" x; for x; do out+="${out:+, }$x"; done; printf '%s' "$out"; }
[ ${#went[@]} -gt 0 ] && line+=" Gone: $(join "${went[@]}")."
[ ${#kept[@]} -gt 0 ] && line+=" Kept: $(join "${kept[@]}")."
[ ${#notes[@]} -gt 0 ] && line+=" ${notes[*]}"
line=$(tr -d '\000-\037' <<<"$line"); line=${line//\\/\\\\}; line=${line//\"/\\\"}
printf '{"systemMessage":"%s"}\n' "$line"
exit 0 # mutant-ok delete: the line above leaves status 0, so the script ends the same way
