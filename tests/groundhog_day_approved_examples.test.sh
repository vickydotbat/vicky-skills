#!/usr/bin/env bash
# approved-spec: the examples ticked on the reader-cost drafts page. The ticket
# guard lets a session that started groundhog-day file a bug report, and still
# refuses a session that started neither filing skill.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/ticket-filing-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
run() { # transcript command: the guard's exit code, its stderr in $dir/err
  jq -nc --arg c "$2" --arg t "$1" '{tool_input:{command:$c},transcript_path:$t}' |
    CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING=true "$guard" >/dev/null 2>"$dir/err"
}
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a session that started groundhog-day and never started mission-brief
# When the agent runs gh issue create
# Then the ticket guard lets the command run
{ started vicky-skills:do; started vicky-skills:groundhog-day; } >"$dir/bug.jsonl"
check "E1 a bug report files without mission-brief" \
  'run "$dir/bug.jsonl" "gh issue create --title T --body-file b.md"'

# Given a session that started neither groundhog-day nor mission-brief
# When the agent runs gh issue create
# Then the ticket guard refuses it, and the refusal names both skills
started vicky-skills:do >"$dir/none.jsonl"
run "$dir/none.jsonl" "gh issue create --title T --body-file b.md"; got=$?
check "E2 neither skill started is still refused, naming both skills" \
  '[ "$got" = 2 ] && grep -q "mission-brief" "$dir/err" && grep -q "groundhog-day" "$dir/err"'

exit $fail
