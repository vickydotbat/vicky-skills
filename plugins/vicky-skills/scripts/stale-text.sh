# shellcheck shell=bash
# stale_hits <text>: prints each line of <text> that goes stale (a present-tense
# count, "currently" and the like), as human-voice's lint reads it, and returns 0
# when there is one. Returns 1, quietly, when there is none, when python3 is
# missing, or when the repo opts out with a "Stale text: off" line in AGENTS.md
# or a docs/agents/ file.
stale_hits() {
  command -v python3 >/dev/null || return 1 # mutant-ok delete: without python3 the lint below fails and prints nothing, so no hit shows
  local top hits file # mutant-ok delete: a local declaration: no caller reads these names
  top=$(git rev-parse --show-toplevel 2>/dev/null)
  [ -n "$top" ] && grep -qsiE '^(- )?Stale text:[[:space:]]*off$' "$top/AGENTS.md" "$top"/docs/agents/*.md && return 1
  file=$(mktemp)
  printf '%s\n' "$1" >"$file"
  hits=$(python3 -I "$(dirname "${BASH_SOURCE[0]}")/../skills/writing/human-voice/scripts/lint-tells.py" --stale "$file" 2>/dev/null)
  rm -f "$file" # mutant-ok delete: a leftover temporary file changes no decision
  [ -n "$hits" ] || return 1
  printf '%s\n' "$hits"
}
