#!/usr/bin/env bash
# approved-spec: the examples approved on the notes "FS-1 groundhog-day files
# any ticket or issue" and "FS-2 mission-brief charts stars", on 2026-11-25.
# groundhog-day files one ticket of any kind, mission-brief charts a plan, and
# the ticket guard says so. FS-1 E4 and FS-2's hand-off are agent behaviour,
# proven by the eval case mission-brief/docs-only-files-a-task.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/ticket-filing-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:do"}}]}}' >"$dir/none.jsonl"

# Given an agent runs gh issue create before any filing skill started
# When ticket-filing-guard refuses it
# Then the refusal names groundhog-day for one ticket and mission-brief for a chart
jq -nc --arg t "$dir/none.jsonl" '{tool_input:{command:"gh issue create --title T --body-file b.md"},transcript_path:$t}' |
  CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING=true bash "$guard" >/dev/null 2>"$dir/err"
s=$?
[ $s = 2 ] && grep -Eq 'groundhog-day for (one|a single) ticket' "$dir/err" && grep -Eq 'mission-brief for a (star )?chart' "$dir/err"
check "FS-1 E3 the refusal names groundhog-day for one ticket and mission-brief for a chart" $?

exit $fail
