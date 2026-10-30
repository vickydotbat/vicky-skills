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
# shellcheck disable=SC2034 # read by the guard that sources this
code=$(awk '
  tag != "" { t = $0; sub(/^\t+/, "", t); if (t == tag) tag = ""; next }
  match($0, /<<-?[[:space:]]*["\047]?[A-Za-z_][A-Za-z0-9_]*/) {
    tag = substr($0, RSTART, RLENGTH); sub(/^<<-?[[:space:]]*["\047]?/, "", tag)
  }
  { print }
' <<<"$command" | sed -zE "s/'[^']*'//g; s/\"([^\"\\\\]|\\\\.)*\"//g")
refuse() { printf "%s\n" "$@" >&2; exit 2; }
