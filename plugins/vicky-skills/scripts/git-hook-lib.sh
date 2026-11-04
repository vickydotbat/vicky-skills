# shellcheck shell=bash
# Sourced by the git guards. The caller sets GUARD (its name) and OPTION (the
# value of its plugin option) first. Leaves `code` (the command with quoted
# strings and heredoc bodies cut out), the shell in the target repository, and
# `refuse`. Exits 0, letting the command run, when the guard is off or the
# command is no git command in a repository.
case "$OPTION" in true|1) ;; *) exit 0 ;; esac
# Needs jq and git; without either it says so and stays off.
set -u
for tool in jq git; do
  command -v "$tool" >/dev/null || { echo "$GUARD: $tool is missing, so this guard is off." >&2; exit 0; } # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
done
payload=$(cat)
command=$(jq -r ".tool_input.command // \"\"" <<<"$payload")
cwd=$(jq -r ".cwd // \"\"" <<<"$payload")
grep -Eq "git[[:space:]]|(gh|tea)[[:space:]]+(pr|pulls?)[[:space:]]+(ready|reopen)" <<<"$command" || exit 0 # mutant-ok delete: a fast path: the checks below find nothing to refuse in such a command
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
target=${target//[\"\']/}
target=${target/#\~\//$HOME/}
[ -n "$target" ] && { cd "$target" 2>/dev/null || exit 0; }
git rev-parse --git-dir >/dev/null 2>&1 || exit 0 # mutant-ok delete: outside a repository each guard's own git calls fail and it refuses nothing
# The command with quoted strings and heredoc bodies cut out, so a commit
# message that mentions `git push` is text, not a command.
# shellcheck disable=SC2034 # read by the guard that sources this
code=$(awk -f "$(dirname "${BASH_SOURCE[0]}")/heredoc-strip.awk" <<<"$command" | sed -zE "s/'[^']*'//g; s/\"([^\"\\\\]|\\\\.)*\"//g")
refuse() { printf "%s\n" "$@" "Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2; exit 2; }
# is_trunk <top>: 0 when the repository takes every change on main. Its
# AGENTS.md, CLAUDE.md or a docs/agents/*.md holds the line "Trunk: on", or
# the git_guard_trunk_repos setting names it (owner/repo, comma-separated).
is_trunk() {
  local origin repo repos # mutant-ok delete: the names only stay local, and no caller reads them
  grep -qsx 'Trunk:[[:space:]]*on' "$1/AGENTS.md" "$1/CLAUDE.md" "$1"/docs/agents/*.md && return 0
  origin=$(git -C "$1" remote get-url origin 2>/dev/null) || return 1
  origin=${origin%/}; origin=${origin%.git}
  # owner/repo ends the origin URL, after a / or the : of an ssh address.
  repos=${CLAUDE_PLUGIN_OPTION_GIT_GUARD_TRUNK_REPOS:-}
  for repo in ${repos//,/ }; do
    [[ $origin == *[/:]"$repo" ]] && return 0
  done
  return 1
}

# The remote's default branch as "<remote>/<name>": its recorded HEAD, else a
# main or master it has. Empty when none is known.
default_ref_of() {
  local ref name # mutant-ok delete: a local declaration: no caller reads these names
  ref=$(git symbolic-ref -q --short "refs/remotes/$1/HEAD" 2>/dev/null)
  for name in main master; do
    [ -z "$ref" ] && git rev-parse -q --verify "refs/remotes/$1/$name" >/dev/null && ref="$1/$name"
  done
  printf '%s' "$ref"
}
# The branch checked out, or empty on a detached HEAD.
# shellcheck disable=SC2034 # read by the guard that sources this
current=$(git symbolic-ref --short -q HEAD) || current=""
# push_args_of <segment>: when the segment runs git push, fill push_args with
# the words after `push`, flags included, and return 0. Return 1 otherwise.
push_args_of() {
  local word words seen=0 # mutant-ok delete: a local declaration: no caller reads these names
  push_args=()
  grep -Eq '(^|[[:space:]])git([[:space:]]|$)' <<<"$1" || return 1
  read -ra words <<<"$1"
  for word in ${words[@]+"${words[@]}"}; do
    if [ "$seen" = 1 ]; then push_args+=("$word"); elif [ "$word" = push ]; then seen=1; fi
  done
  [ "$seen" = 1 ]
}
