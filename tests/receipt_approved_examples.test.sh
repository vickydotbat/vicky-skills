#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Chat shows a receipt of
# red, green and mutation". Each check is named after its example. The
# behaviour is the agent's, so each check reads the instruction that drives it.
set -u
do="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/do/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
r=$(grep -A8 '^## Receipts' "$do")
check "once do turns an approved example green, chat shows its receipt before the next example: the red run, the green run and the mutation result, each as the command and its outcome line, with no question" \
  'grep -q "before you start the next example" <<<"$r" && grep -q "red run, the green run and the mutation result" <<<"$r" && grep -q "the command and the line that shows its outcome" <<<"$r" && grep -q "asks nothing" <<<"$r" && grep "Go red to green" "$do" | grep -q "Receipts"'
check "an approved example only a person can check gets a receipt that says unchecked and names the over-to-you checklist that holds it" \
  'grep -q "says \`unchecked\` and names the \`over-to-you\` checklist" <<<"$r"'
exit $fail
