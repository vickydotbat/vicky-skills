#!/usr/bin/env bash
# Every numbered step in AGENTS.md ends in "Done when". It checks the form,
# never a heading or a phrase: agents never test prose.
set -u
cd "$(dirname "$0")/.."
check() { awk '/^[0-9]+\. /' "$1" | grep -vc "Done when"; }
fixture=$(mktemp); trap 'rm -f "$fixture"' EXIT
printf '## Any\n\n1. A step. Done when it is.\n2. A step with no end.\n' > "$fixture"
[ "$(check "$fixture")" -eq 1 ] || { echo "FAIL a step with no Done when is counted"; exit 1; }
n=$(check AGENTS.md)
[ "$n" -eq 0 ] || { echo "FAIL AGENTS.md: $n numbered step(s) without Done when"; exit 1; }
echo "ok   agents-doc: every numbered step in AGENTS.md has a Done when"
