#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit, NotebookEdit, Bash): while red-pen
# has a draft open in the user's editor, refuses writes to the checkout the
# draft was opened from. The lock is the red-pen-open file in that checkout's
# git folder, holding the editor's process id; a lock whose editor has exited
# counts for nothing. Writes outside the checkout run. A Bash command is a
# write when it holds a write form (sed -i, a redirect, tee, cp, mv, rm, an
# interpreter's own code) aimed at a path inside the checkout.
# Off unless the plugin option guard_draft_lock is true.
case "${CLAUDE_PLUGIN_OPTION_GUARD_DRAFT_LOCK:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
command -v git >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$payload")
[ -n "$cwd" ] && { cd "$cwd" 2>/dev/null || exit 0; }
tool=$(jq -r '.tool_name // empty' <<<"$payload")
if [ "$tool" = Bash ]; then
  command=$(jq -r '.tool_input.command // empty' <<<"$payload")
  # A read-only command passes; a write form sends it to the check below.
  grep -qE 'sed[^|;&]*[[:space:]](-[a-zA-Z]*i|--in-place)|perl[^|;&]*[[:space:]]-[a-zA-Z]*i|>|(^|[[:space:];&|(])(tee|rm|mv|cp|install|ln|truncate|dd|touch|mkdir|python3?|node|ruby|perl|patch)([[:space:]]|$)|git[[:space:]]+([^|;&]*[[:space:]])?(commit|checkout|restore|apply|reset|stash|merge|rebase|mv|rm|am|cherry-pick|switch)([[:space:]]|$)' <<<"$command" || exit 0
  # The command writes inside the checkout unless every path it names is outside.
  dirs=$(tr -s " \t\n;&|()<>'\"=," '\n' <<<"$command" | grep '^/' || true)
  top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
  inside=yes
  if [ -n "$dirs" ] && grep -qE '>|tee|cp|mv|rm|sed|touch|mkdir' <<<"$command"; then
    inside=""
    while IFS= read -r path; do case "$path" in "$top"|"$top"/*) inside=yes ;; esac; done <<<"$dirs"
  fi
  [ -n "$inside" ] || exit 0
  place=$top
else
  file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$payload")
  [ -n "$file" ] || exit 0
  dir=$(dirname -- "$file")
  while [ ! -d "$dir" ]; do dir=$(dirname -- "$dir"); done
  cd "$dir"
  place=$file
fi
gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
lock="$gitdir/red-pen-open"
[ -f "$lock" ] || exit 0 # mutant-ok delete: without the lock, head reads nothing and the case below exits 0
pid=$(head -1 "$lock")
case "$pid" in ''|*[!0-9]*) exit 0 ;; esac
kill -0 "$pid" 2>/dev/null || exit 0
echo "draft-lock: a draft is open in the user's editor ($(sed -n 2p "$lock")), so $place waits until they close it. Work in your scratch folder meanwhile." >&2
exit 2
