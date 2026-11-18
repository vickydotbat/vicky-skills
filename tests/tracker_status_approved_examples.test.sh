#!/usr/bin/env bash
# approved-spec: summit counts only once every note in an Obsidian tracker
# carries a valid status, and familiar writes its debt notes in the tracker's
# format. Each check is named after its example, and pins the text that
# drives the agent.
set -u
r="$(cd "$(dirname "$0")/.." && pwd)"
p="$r/plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$2" '$0 ~ "^"n"\\. "{on=1;print;next} on && /^[0-9]+\. /{on=0} on' "$1"; }
op="List notes off the tracker"
check "given an Obsidian tracker, its operations list the notes off the tracker with tracker-status.sh" \
  '( for f in "$r/docs/agents/issue-tracker.md" "$p/skills/commands/first-contact/issue-tracker-obsidian.md"; do grep -q "$op" "$f" && grep -q "tracker-status.sh" "$f" || exit 1; done )'
check "given notes off the tracker, when summit counts, then it fixes each one before it counts" \
  'step "$p/skills/housekeeping/summit/SKILL.md" 1 | grep -q "$op" && step "$p/skills/housekeeping/summit/SKILL.md" 1 | grep -q "before you count"'
check "given a tracker kept on this machine, when familiar opens a debt note there, then the note has the tracker frontmatter and a timestamped name" \
  'step "$p/skills/commands/familiar/SKILL.md" 2 | grep -q "status: open" && step "$p/skills/commands/familiar/SKILL.md" 2 | grep -q "named the way the tracker names a note"'
check "given a debt note whose list is closed, then familiar sets it done" \
  'step "$p/skills/commands/familiar/SKILL.md" 6 | grep -q "status: done"'
exit $fail
