#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Reader panel on big
# drafts". Each check is named after its example. The behaviour is the
# agent's, so each check reads the instruction that drives it.
set -u
root="$(dirname "$0")/.."
voice="$root/plugins/vicky-skills/skills/productivity/human-voice/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
panel=$(awk '/^[0-9]+\. /{on = index($0, "**Seat a reader panel") > 0} on' "$voice")
setting=$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))["userConfig"]["reader_panel"]))' "$root/plugins/vicky-skills/.claude-plugin/plugin.json")

check "a 600-word runbook meets a panel from its audience, with a seat that dry-runs the steps, and each seat lists the questions it's left with" \
  'grep -q "over about 400 words" <<<"$panel" && grep -q "from its audience" <<<"$panel" && grep -q "runbook or doc gets a seat that does a dry run" <<<"$panel" && grep -q "lists the questions it is left with" <<<"$panel"'
check "a 300-word PR body meets no panel" \
  'grep -q "A shorter draft skips this step" <<<"$panel"'
check "a 900-word lore page's panel has a canon keeper who checks it against the setting's other pages" \
  'grep -q "Lore gets a canon keeper, who checks it against the setting.s other pages" <<<"$panel"'
check "with three questions left and two answerable from the source, the draft answers those two and I see the third as an open question" \
  'grep -q "Answer each question in the draft, from the source" <<<"$panel" && grep -q "Keep a question the source can.t answer for the user" <<<"$panel" && grep -q "Show the draft\*\*, with the panel.s kept questions beside it" "$voice"'
check "at the reader panel setting's default, one agent plays every seat in turn" \
  'grep -q "\"default\": \"one agent\"" <<<"$setting" && grep -q "At \`one agent\`, play every seat yourself, one at a time" <<<"$panel" && grep -qF "\${user_config.reader_panel}" <<<"$panel"'
check "at one agent per seat, each seat is its own agent, run side by side" \
  'grep -q "\"agent per seat\"" <<<"$setting" && grep -q "At \`agent per seat\`, start one subagent per seat, side by side" <<<"$panel"'
exit $fail
