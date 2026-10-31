#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git commit that adds a path into this
# machine. Such a path means nothing to a reader and shows a stranger how the
# machine is laid out. Scanned in the added lines only: your home directory,
# /home/<name>/, /Users/<name>/, /nix/store/, /<your user>/ and <your user>@.
# Off unless the plugin option guard_local_paths is true. Repositories listed
# in local_path_exempt_repos (space-separated owner/repo, matched against the
# end of origin's URL) are skipped. Binary untracked files are not scanned.
GUARD=local-path-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_LOCAL_PATHS:-}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"

grep -Eq 'git[[:space:]].*commit([[:space:]]|$)' <<<"$code" || exit 0

origin_url=$(git remote get-url origin 2>/dev/null) || origin_url=""
for repo in ${CLAUDE_PLUGIN_OPTION_LOCAL_PATH_EXEMPT_REPOS:-}; do
  [ -n "$origin_url" ] && [[ ${origin_url%.git} =~ [:/]"$repo"$ ]] && exit 0
done

# What the commit would add: staged lines, plus tracked changes and untracked
# files when the command stages them itself (`git add`, `commit -a`).
if grep -Eq 'git[[:space:]].*add([[:space:]]|$)|commit[^;&|]*[[:space:]]-[a-zA-Z]*a' <<<"$code"; then
  added=$({ git diff HEAD 2>/dev/null || git diff --cached 2>/dev/null || true; } | grep -E '^\+' | grep -Ev '^\+\+\+ ' || true)
  while IFS= read -r untracked; do
    grep -Iq . "$untracked" || continue
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
