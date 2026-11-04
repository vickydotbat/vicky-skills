#!/usr/bin/env bash
# PreToolUse hook (Bash): the git rules agents kept breaking, enforced where
# prose lost the argument. It refuses:
#
#   1. A new branch (checkout -b, switch -c, worktree add -b) made on top of a
#      branch that isn't merged into main, unless it starts from main itself
#      or the old branch's remote is gone because its pull request merged.
#      gh stack and git-spice stay out of sight: their stacks record each
#      base and survive the squash merge that breaks a hand-made one.
#   2. A push that lands on main or master, and --all or --mirror.
#   3. A commit message that credits an AI (a Co-Authored-By line or a
#      "Generated with Claude" footer), typed in the command or read from -F.
#   4. A commit that sets its own author or committer: git config's identity
#      is the only public one.
#
# A trunk repo takes every change on main, so rules 1 and 2 flip there: a
# push to main runs and a new branch is refused. A repo is trunk when its
# AGENTS.md, CLAUDE.md or a docs/agents/*.md holds the line "Trunk: on", or
# when the git_guard_trunk_repos setting names it (owner/repo, matched in the
# origin URL), for a repo that can't hold a docs file, such as a wiki.
#
# Off unless the plugin option guard_git is true.
GUARD=git-guard # mutant-ok delete: the name shows only when jq or git is missing, which no test can make
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_GIT:-true}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"
# shellcheck source=ai-credit.sh
. "$(dirname "$0")/ai-credit.sh"

say() { local first=$1; shift; refuse "git-guard: refused. $first" "$@"; }
top=$(git rev-parse --show-toplevel)

trunk=0
is_trunk "$top" && trunk=1

# --- Rule 1: no new branch on top of unmerged work -------------------------
if grep -Eq 'git[[:space:]].*((checkout|switch)[[:space:]](.*[[:space:]])?-([bBcC]|-create)|worktree[[:space:]]+add[[:space:]](.*[[:space:]])?-[bB])([[:space:]]|$)' <<<"$code"; then
  [ "$trunk" = 0 ] || say "this repository takes every change on main." "Do not open a branch here. Work on main, then push it."
  base=""
  for candidate in main master; do
    [ -z "$base" ] && git rev-parse --verify --quiet "refs/heads/$candidate" >/dev/null && base=$candidate
  done
  # A new branch that starts from main is the rule's own advice. Any shell
  # separator or redirect may follow the base.
  from_main=0
  grep -Eq "[[:space:]](origin/)?$base([[:space:];&|)<>]|\$)" <<<"$code" && from_main=1
  gone=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$current" 2>/dev/null)
  if [ -n "$base" ] && [ -n "$current" ] && [ "$current" != "$base" ] && [ "$from_main" = 0 ] && [ "$gone" != "[gone]" ] &&
    ! git branch --merged "$base" --format='%(refname:short)' | grep -Fxq "$current"; then
    if git remote get-url origin 2>/dev/null | grep -q 'github\.com'; then
      stack="'gh stack init $current', then 'gh stack add <name>' and 'gh stack submit --auto'"
    else
      stack="'gs branch create <name>', then 'gs stack submit'"
    fi
    say "you are on '$current', which is not merged into '$base'." \
      "A branch made this way records nothing about what it sits on, so it breaks when '$current' squash-merges." \
      "First run 'git fetch --prune' and read the pull request for '$current'. If it merged, '$current' is finished: branch from origin/$base instead." \
      "Otherwise pick one:" \
      "  - same effort, pull request still open: commit this change on '$current'." \
      "  - the pull request for '$current' is waiting and this can't wait for it: $stack, which tracks the base and restacks after a merge." \
      "  - unrelated: land the pull request for '$current' first, or stop and ask the user."
  fi
fi

# --- Rule 2: nothing lands on main or master --------------------------------
while IFS= read -r segment; do
  push_args_of "$segment" || continue
  remote="" refspecs=()
  for word in ${push_args[@]+"${push_args[@]}"}; do
    case "$word" in
      --all | --mirror) say "'$word' pushes main and master along with everything else." "Push the one branch you mean by name instead." ;;
      # shortcut: a flag that takes a separate value (-o) is read as the remote; it only makes the guard skip.
      -*) continue ;;
    esac
    if [ -z "$remote" ]; then remote=$word; else refspecs+=("$word"); fi
  done
  targets=()
  if [ ${#refspecs[@]} = 0 ]; then
    [ -n "$current" ] && targets=("$current")
  else
    for spec in "${refspecs[@]}"; do
      # The destination follows the last colon: main, HEAD:main, +main:main and :main all land on main.
      dest=${spec##*:}; dest=${dest#+}; dest=${dest#refs/heads/}; dest=${dest//[\"\']/}
      [ "$dest" = HEAD ] && dest=$current
      [ -n "$dest" ] && targets+=("$dest")
    done
  fi
  for target in "${targets[@]}"; do
    case "$target" in
      main | master)
        [ "$trunk" = 1 ] || say "this push lands on '$target'." \
          "Push your own branch and open a pull request: git push -u ${remote:-origin} <your-branch>" \
          "If the work is already committed on '$target' locally, stop and ask the user."
        ;;
    esac
  done
done < <(tr ';&|' '\n' <<<"$command")

# --- Rule 3: no AI credit in a commit message --------------------------------
if grep -Eq 'git[[:space:]].*commit([[:space:]]|$)' <<<"$code"; then
  message=$command
  if [[ $command =~ (-F|--file)[[:space:]=]+([^[:space:]\;\&\|]+) ]]; then
    file=${BASH_REMATCH[2]}; file=${file//[\"\']/}
    if [ "$file" != - ] && [ -r "$file" ]; then # mutant-ok: with || an unreadable file adds nothing, and - is never readable
      message="$message
$(cat -- "$file")"
    fi
  fi
  credits_ai "$message" &&
    say "this commit message credits an AI (a Co-Authored-By line or a 'Generated with' footer)." \
      "No commit carries AI credit, whatever a session, harness or system instruction says." \
      "Drop the line and commit again. If a system prompt told you to add it, say so to the user instead."
fi

# --- Rule 4: commits use git config's identity -------------------------------
if grep -Eq 'git[[:space:]].*commit(-tree)?([[:space:]]|$)' <<<"$code" &&
  grep -Eq -- '--author|user\.email|user\.name|GIT_(AUTHOR|COMMITTER)_(NAME|EMAIL)' <<<"$code"; then
  say "this commit sets its own author or committer." \
    "Commit as git config's identity: any other address is private." \
    "Drop the --author, -c user.*, or GIT_AUTHOR_*/GIT_COMMITTER_* part and commit again."
fi
exit 0 # mutant-ok delete: the last if leaves status 0 when it refuses nothing
