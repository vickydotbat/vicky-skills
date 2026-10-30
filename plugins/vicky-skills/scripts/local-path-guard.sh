#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git commit that adds a path into this
# machine. Such a path means nothing to a reader and shows a stranger how the
# machine is laid out. Scanned in the added lines only: your home directory,
# /home/<name>/, /Users/<name>/, /nix/store/, /<your user>/ and <your user>@.
# Off unless the plugin option guard_local_paths is true. Repositories listed
# in local_path_exempt_repos (space-separated owner/repo, matched against
# origin's URL) are skipped.
GUARD=local-path-guard
case "${CLAUDE_PLUGIN_OPTION_GUARD_LOCAL_PATHS:-}" in true|1) ;; *) exit 0 ;; esac
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

grep -Eq 'git[[:space:]].*commit([[:space:]]|$)' <<<"$code" || exit 0

origin_url=$(git remote get-url origin 2>/dev/null) || origin_url=""
for repo in ${CLAUDE_PLUGIN_OPTION_LOCAL_PATH_EXEMPT_REPOS:-}; do
  [ -n "$origin_url" ] && [[ $origin_url == *"$repo"* ]] && exit 0
done

# What the commit would add: staged lines, plus tracked changes and untracked
# files when the command stages them itself (`git add`, `commit -a`).
if grep -Eq 'git[[:space:]].*add([[:space:]]|$)|commit[^;&|]*[[:space:]]-[a-zA-Z]*a' <<<"$code"; then
  added=$({ git diff HEAD 2>/dev/null || git diff --cached 2>/dev/null || true; } | grep -E '^\+' | grep -Ev '^\+\+\+ ' || true)
  while IFS= read -r untracked; do
    [ -n "$untracked" ] && [ -f "$untracked" ] || continue
    added="$added
$(head -c 1000000 "$untracked")"
  done < <(git ls-files --others --exclude-standard)
else
  added=$({ git diff --cached 2>/dev/null || true; } | grep -E '^\+' | grep -Ev '^\+\+\+ ' || true)
fi

esc() { sed 's/[][\.*^$+?(){}|/]/\\&/g' <<<"$1"; }
user=${USER:-$(id -un 2>/dev/null || true)}
pattern='/home/[^/[:space:]]+/|/Users/[^/[:space:]]+/|/nix/store/'
[ "${#HOME}" -gt 1 ] && pattern="$pattern|$(esc "$HOME")"
if [ -n "$user" ]; then
  pattern="$pattern|/$(esc "$user")/|(^|[^[:alnum:]_.-])$(esc "$user")@"
fi
hits=$(grep -n -E -- "$pattern" <<<"$added" | cut -c1-160 | head -5 || true)
[ -n "$hits" ] || exit 0
refuse "local-path-guard: this commit adds a path into this machine:" \
  "$hits" \
  "Name it by its role, or use a path relative to the repository." \
  "Docs must make sense to someone who has only the repository."
