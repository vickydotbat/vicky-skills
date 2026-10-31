#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git push of a branch that lacks the tip of
# origin's default branch, because the push would build on a base that moved.
# The default branch comes from origin/HEAD; origin is fetched first (10
# seconds at most) and a failed fetch lets the push through. Pushing the
# default branch itself, deleting a branch and pushing to another remote are
# not checked. Off unless the plugin option guard_push_behind is true.
GUARD=push-behind-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_PUSH_BEHIND:-}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"

grep -Eq 'git[[:space:]].*push([[:space:]]|$)' <<<"$code" || exit 0
grep -Eq -- '--delete|[[:space:]]-d([[:space:]]|$)' <<<"$code" && exit 0

current=$(git symbolic-ref --short -q HEAD) || current=""
default_ref=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)
[ -n "$default_ref" ] || exit 0
dflt=${default_ref#origin/}
fetched=""

while IFS= read -r segment; do
  grep -Eq '(^|[[:space:]])git([[:space:]]|$)' <<<"$segment" || continue
  read -ra words <<<"$segment"
  seen_push=0
  args=()
  for word in ${words[@]+"${words[@]}"}; do
    if [ "$seen_push" -eq 0 ]; then
      [ "$word" = "push" ] && seen_push=1
      continue
    fi
    case "$word" in -*) continue ;; esac
    args+=("$word")
  done
  [ "$seen_push" -eq 1 ] || continue
  # Another remote is not the one origin/HEAD speaks for.
  if [ ${#args[@]} -gt 0 ] && [ "${args[0]}" != "origin" ]; then continue; fi
  src=$current
  if [ ${#args[@]} -gt 1 ]; then
    src=${args[1]%%:*}
    src=${src#+}
    src=${src//\"/}; src=${src//\'/}
    [ "$src" = "HEAD" ] && src=$current
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
      "Settle each conflict, rerun the checks, then push again."
  fi
done < <(tr ';&|' '\n' <<<"$command")
exit 0 # mutant-ok delete: the loop above ends with status 0 on every path
