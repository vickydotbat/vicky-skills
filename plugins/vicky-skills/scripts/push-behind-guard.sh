#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git push of a branch that lacks the tip of
# origin's default branch, because the push would build on a base that moved.
# The default branch comes from origin/HEAD; origin is fetched first (10
# seconds at most) and a failed fetch lets the push through. Pushing the
# default branch itself, deleting a branch and pushing to another remote are
# not checked. Off unless the plugin option guard_push_behind is true.
GUARD=push-behind-guard
case "${CLAUDE_PLUGIN_OPTION_GUARD_PUSH_BEHIND:-}" in true|1) ;; *) exit 0 ;; esac
# Needs jq and git; without either it says so and stays off.
set -u
for tool in jq git; do
  command -v "$tool" >/dev/null || { echo "$GUARD: $tool is missing, so this guard is off." >&2; exit 0; }
done
payload=$(cat)
command=$(jq -r ".tool_input.command // \"\"" <<<"$payload")
cwd=$(jq -r ".cwd // \"\"" <<<"$payload")
grep -Eq "git[[:space:]]" <<<"$command" || exit 0
[ -n "$cwd" ] && { cd "$cwd" 2>/dev/null || exit 0; }
# The command may aim at another repo with `git -C <dir>` or a leading `cd <dir>`.
# The first one wins.
target=""
before_git=${command%%git[[:space:]]*}
if [[ $command =~ git[[:space:]]+-C[[:space:]]+([^[:space:]\;\&\|]+) ]]; then
  target=${BASH_REMATCH[1]}
elif [[ $before_git =~ (^|[[:space:]\;\&\|])cd[[:space:]]+([^[:space:]\;\&\|]+) ]]; then
  target=${BASH_REMATCH[2]}
fi
target=${target//\"/}; target=${target//\'/}
target=${target/#\~\//$HOME/}
[ -n "$target" ] && { cd "$target" 2>/dev/null || exit 0; }
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
# The command with quoted strings and heredoc bodies cut out, so a commit
# message that mentions `git push` is text, not a command.
code=$(awk '
  tag != "" { t = $0; sub(/^\t+/, "", t); if (t == tag) tag = ""; next }
  match($0, /<<-?[[:space:]]*["\047]?[A-Za-z_][A-Za-z0-9_]*/) {
    tag = substr($0, RSTART, RLENGTH); sub(/^<<-?[[:space:]]*["\047]?/, "", tag)
  }
  { print }
' <<<"$command" | sed -zE "s/'[^']*'//g; s/\"([^\"\\\\]|\\\\.)*\"//g")
refuse() { printf "%s\n" "$@" >&2; exit 2; }

grep -Eq 'git[[:space:]].*push([[:space:]]|$)' <<<"$code" || exit 0
grep -Eq -- '--delete|[[:space:]]-d([[:space:]]|$)' <<<"$code" && exit 0

current=$(git symbolic-ref --short -q HEAD) || current=""
default_ref=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)
[ -n "$default_ref" ] || exit 0
dflt=${default_ref#origin/}

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
  if ! GIT_TERMINAL_PROMPT=0 timeout 10 git fetch -q origin "$dflt" >/dev/null 2>&1; then
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
exit 0
