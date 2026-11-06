#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for the hook audit, E1
# and E2. An item is read whole through the repo's own tracker doc, so any
# tracker works, and a ticket skill's start points at the reader.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
reader="$root/plugins/vicky-skills/scripts/read-item.sh"
hint="$root/plugins/vicky-skills/scripts/step-hint.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
mkdir -p "$dir/cmd/docs/agents" "$dir/note/docs/agents"
printf '| Action | How |\n| --- | --- |\n| Read, whole | `echo item <n> with comments` |\n' > "$dir/cmd/docs/agents/issue-tracker.md"
printf '| Action | How |\n| --- | --- |\n| Read, whole | Read the note, frontmatter and `## Comments` included. |\n' > "$dir/note/docs/agents/issue-tracker.md"

# Given a repo whose issue-tracker doc has a Read, whole row with a command
# When an agent runs read-item.sh 12
# Then the row's command runs with 12 in place of the id, and its output is printed
check "E1 a Read, whole command runs with the id" \
  '[ "$(cd "$dir/cmd" && bash "$reader" 12 2>&1)" = "item 12 with comments" ]'

# Given a Read, whole row that names no command, as Obsidian's does
# When an agent runs read-item.sh on a note
# Then it prints the row's instruction so the agent reads the note whole
check "E1 a Read, whole row with no command prints its instruction" \
  'out=$(cd "$dir/note" && bash "$reader" "Some note" 2>&1); grep -q "Read the note, frontmatter" <<<"$out" && grep -q "Some note" <<<"$out"'

# Given a session that starts do, gamma-shift, warp or loose-ends
# When the skill starts
# Then the agent is told to read each ticket with read-item.sh
for s in do gamma-shift warp loose-ends; do
  check "E2 $s points at read-item.sh" \
    "jq -nc --arg s vicky-skills:$s '{tool_input:{skill:\$s}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash \"$hint\" | grep -q 'read-item.sh'"
done
exit $fail
