#!/usr/bin/env bash
# lines.sh: first-contact runs it from inside a repo. Writes the security
# kit's two opt-out lines into docs/agents/security.md when no docs/agents
# file holds them yet: Advisories (github on a GitHub remote, else file) and
# Security levels (all four). A line already there stays as it is.
set -u
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "lines: run this inside a repo."; exit 1; }
has() { grep -qsE "^(- )?$1:" "$top"/docs/agents/*.md; }
mkdir -p "$top/docs/agents"
file="$top/docs/agents/security.md"
[ -s "$file" ] || printf '# Security\n\nThe security kit reads these lines. Change a value to switch part of it off in this repo.\n\n' > "$file" # mutant-ok delete: the heading is for a person reading the file, and no tool reads it
if ! has Advisories; then
  case "$(git -C "$top" config remote.origin.url 2>/dev/null)" in
    https://github.com/* | git@github.com:* | ssh://git@github.com/*) route=github ;;
    *) route=file ;;
  esac
  printf 'Advisories: %s\n' "$route" >> "$file"; echo "lines: wrote Advisories: $route"
fi
if ! has 'Security levels'; then
  printf 'Security levels: baseline, secrets, ci, dependencies\n' >> "$file"; echo "lines: wrote Security levels: baseline, secrets, ci, dependencies"
fi
