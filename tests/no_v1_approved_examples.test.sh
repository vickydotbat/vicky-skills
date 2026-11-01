#!/usr/bin/env bash
# approved-spec: the never-a-V1 examples, approved 2026-11-01. The hook runs
# when the agent ends its turn, on a fixture transcript, so each check sees
# what the session sees; the review check reads the instruction in do.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/no-v1.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
export CLAUDE_PLUGIN_OPTION_GUARD_NO_V1=true
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# A transcript whose last turn is a user request, then the agent's reply.
reply() {
  jq -nc '{type:"user",message:{role:"user",content:"build the export"}}' > "$fx/t.jsonl"
  jq -nc --arg r "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$r}]}}' >> "$fx/t.jsonl"
}
stop() { jq -nc --arg t "$fx/t.jsonl" '{hook_event_name:"Stop",stop_hook_active:false,transcript_path:$t}' | bash "$hook" 2>/dev/null; }
blocked() { stop | jq -e '.decision == "block" and (.reason | test("fold"; "i"))' >/dev/null 2>&1; }
passes() { [ -f "$hook" ] && [ -z "$(stop)" ]; }

# Given an agent that found more work it could do in this effort
# When its reply asks whether to fold it in or leave it for a follow-up
# Then the reply is stopped, and the agent folds the work in and reports that it did
reply "The export works. I also found that empty rows crash the parser. Want me to fold that in, or leave it for a follow-up?"
check "a fold-or-follow-up question never reaches you" 'blocked'

# Given an agent finishing an effort with polish or findings left
# When its reply offers them as a follow-up pull request, a later ticket or a v2
# Then the reply is stopped, and the agent builds them into the same pull request
ok=1
for r in "Done. The column widths could use a follow-up PR." "Shipped. I can file a ticket for the CSV quoting later." "That covers v1. Sorting can come in a v2."; do
  reply "$r"; blocked || ok=0
done
check "an offered follow-up pull request or ticket is stopped" '[ $ok = 1 ]'

# Given work that waits on your decision, another person, a deploy or a repo out of reach
# When the agent's reply names it as waiting, with what it waits on
# Then the reply goes through untouched
reply "Done. The upload step waits on your decision about the bucket. Waits on: you, the bucket name."
check "work that truly waits still gets named" 'passes'

# Given an agent that folded found work into the pull request
# When its reply says what it folded in
# Then the reply goes through untouched
reply "Done. I found that empty rows crashed the parser and folded the fix into this pull request."
check "folded work is reported, not questioned" 'passes'

# Given you said a piece is for a later version
# When the agent's reply names that piece as later, quoting your words
# Then the reply goes through untouched
reply "Done. Sorting stays for v2, as you said: \"sorting can wait for v2\"."
check "a v2 you named stays a v2" 'passes'

# Given review findings on a build
# When do answers them
# Then each one is fixed in the same pull request, and only work that truly waits goes on a ticket
check "review findings land in the same pull request" \
  'grep -q "Fix each finding in the same pull request" "$root/plugins/vicky-skills/skills/engineering/do/SKILL.md" && ! grep -q "record the ones you defer on a ticket" "$root/plugins/vicky-skills/skills/engineering/do/SKILL.md"'

# Given the never-a-V1 setting switched off
# When an agent's reply offers a follow-up
# Then the reply goes through untouched
reply "Done. The column widths could use a follow-up PR."
check "you can switch it off" '[ -z "$(CLAUDE_PLUGIN_OPTION_GUARD_NO_V1=false stop)" ] && [ -z "$(CLAUDE_PLUGIN_OPTION_GUARD_NO_V1= stop)" ] && blocked'
exit $fail
