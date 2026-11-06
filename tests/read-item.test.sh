#!/usr/bin/env bash
# read-item.sh fails loudly when the repo has no tracker doc or no Read, whole
# row, and quotes the id so it can't run as a command.
set -u
reader="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/read-item.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
mkdir -p "$dir/none" "$dir/norow/docs/agents" "$dir/cmd/docs/agents"
echo '| Find | `grep x` |' > "$dir/norow/docs/agents/issue-tracker.md"
echo '| Read, whole | `echo <n>` |' > "$dir/cmd/docs/agents/issue-tracker.md"
check "no tracker doc exits 2" 2 "$(cd "$dir/none" && bash "$reader" 1 >/dev/null 2>&1; echo $?)"
check "no Read, whole row exits 2" 2 "$(cd "$dir/norow" && bash "$reader" 1 >/dev/null 2>&1; echo $?)"
check "an id is quoted, never run" '1;touch hit' "$(cd "$dir/cmd" && bash "$reader" '1;touch hit' 2>&1)"
check "the quoted id ran nothing" no "$([ -e "$dir/cmd/hit" ] && echo yes || echo no)"
check "no id exits non-zero" 1 "$(cd "$dir/cmd" && bash "$reader" >/dev/null 2>&1; echo $?)"
exit $fail
