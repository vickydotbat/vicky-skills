#!/usr/bin/env bash
# approved-spec: the examples set for counting every engraved lesson in sup,
# relayed from the session that built sup's Lessons part. The ledger script
# is run; the skill checks read the instructions that drive the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
ledger="$root/plugins/vicky-skills/scripts/lesson-ledger.sh"
skills="$root/plugins/vicky-skills/skills"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { CLAUDE_PLUGIN_DATA="$data" bash "$ledger" "$@" 2>/dev/null; }
printf '2026-01-01T10:00:00Z\trepo\tan old snag\n' > "$data/lessons.tsv"
run add plugin "a red check nobody read"; run add setup "a claim made from memory"
out=$(run since 2026-06-01T00:00:00Z)
check "a lesson engrave sent to the plugin's repo or to my CLAUDE.md is counted by sup in another repo, with its snag and where it went" \
  'grep -q "a red check nobody read (plugin)" <<<"$out" && grep -q "a claim made from memory (setup)" <<<"$out" && grep -q "lesson-ledger.sh add" "$skills/engineering/engrave/SKILL.md" && grep -q "lesson-ledger.sh since" "$skills/productivity/sup/SKILL.md"'
check "lessons engraved before my last message are not counted" '! grep -q "an old snag" <<<"$out" && [ "$(wc -l <<<"$out")" = 2 ]'
check "with no lesson since my last message, sup leaves Lessons out" \
  '[ -z "$(run since 2099-01-01T00:00:00Z)" ] && grep -q "With no lesson, leave Lessons out" "$skills/productivity/sup/SKILL.md"'
exit $fail
