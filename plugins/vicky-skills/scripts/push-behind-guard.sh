#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git push of a branch that lacks the tip of
# origin's default branch, because the push would build on a base that moved.
# The default branch comes from origin/HEAD; origin is fetched first (10
# seconds at most) and a failed fetch lets the push through. Pushing the
# default branch itself, deleting a branch and pushing to another remote are
# not checked. Marking a pull request ready or reopening it (gh, tea) is
# checked like a push of the current branch: CI would test a stale base.
# On unless the plugin option guard_push_behind is false or 0.
GUARD=push-behind-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_PUSH_BEHIND:-true}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"

ready='(gh|tea)[[:space:]]+(pr|pulls?)[[:space:]]+(ready|reopen)'
grep -Eq "git[[:space:]].*push([[:space:]]|\$)|$ready" <<<"$code" || exit 0
grep -Eq -- '--delete|[[:space:]]-d([[:space:]]|$)' <<<"$code" && exit 0

default_ref=$(default_ref_of origin)
[ -n "$default_ref" ] || exit 0
dflt=${default_ref#origin/}
fetched=""

while IFS= read -r segment; do
  if grep -Eq "$ready" <<<"$segment"; then
    src=$current
  else
  push_args_of "$segment" || continue
  args=()
  for word in ${push_args[@]+"${push_args[@]}"}; do [[ $word == -* ]] || args+=("$word"); done
  # Another remote is not the one origin/HEAD speaks for.
  if [ ${#args[@]} -gt 0 ] && [ "${args[0]}" != "origin" ]; then continue; fi
  src=$current
  if [ ${#args[@]} -gt 1 ]; then
    src=${args[1]%%:*}
    src=${src#+}
    src=${src//[\"\']/}
    [ "$src" = "HEAD" ] && src=$current
  fi
  fi
  if [ -z "$src" ] || [ "$src" = "$dflt" ] || ! git rev-parse --verify -q "$src" >/dev/null 2>&1; then
    continue
  fi
  # One fetch per command, so several pushes stay inside the hook's timeout.
  if [ -z "$fetched" ]; then
    GIT_TERMINAL_PROMPT=0 timeout 10 git fetch -q origin "$dflt" >/dev/null 2>&1 && fetched=yes || fetched=no
  fi
  if [ "$fetched" = no ]; then
    echo "push-behind-guard: could not fetch origin/$dflt, so the push is not checked for being behind it." >&2
    continue
  fi
  if ! git merge-base --is-ancestor "origin/$dflt" "$src" 2>/dev/null; then
    refuse "push-behind-guard: '$src' lacks commits that origin/$dflt has." \
      "Bring it up to date first:" \
      "  git fetch origin && git rebase origin/$dflt" \
      "Settle each conflict, rerun the checks, push, then mark it ready or reopen it."
  fi
done < <(tr ';&|' '\n' <<<"$command")
exit 0 # mutant-ok delete: the loop above ends with status 0 on every path
