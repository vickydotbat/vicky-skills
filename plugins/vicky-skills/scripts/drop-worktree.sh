# shellcheck shell=bash
# Sourced by worktree-place and auto-tidy. `drop_script <main clone>` prints the
# repo's own worktree removal script, relative to the main clone, from a
# "Drop worktree: <path>" line of docs/agents/testing.md, or nothing. The file
# must be executable, and its path stays inside the main clone.
drop_script() {
  local rel # mutant-ok delete: the name would only be global, and nothing else reads it
  rel=$(sed -n 's/^Drop worktree:[[:space:]]*//p' "$1/docs/agents/testing.md" 2>/dev/null | head -n1)
  case "$rel" in /* | *..*) return 0 ;; esac # a path stays inside the main clone
  [ -n "$rel" ] && [ -f "$1/$rel" ] && [ -x "$1/$rel" ] && printf '%s' "$rel" # mutant-ok: a blank line names the main clone, a folder, and -f refuses it
}
