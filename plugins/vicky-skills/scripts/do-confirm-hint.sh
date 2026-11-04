#!/usr/bin/env bash
# UserPromptSubmit hook: a typed /do whose objective is the user's own words
# gets one line of context. Stated in full, the agent says "Going with" and
# builds; read into from a question or a hedge, do's step 0 confirms it at a
# gate first. A typed command never passes through the Skill tool, so
# step-hint never sees it. A /do that names a ticket, a ticket note or a
# star chart gets nothing: its objective is already written down.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
prompt=$(jq -r '.prompt // ""' 2>/dev/null)
grep -q '<command-name>/\(vicky-skills:\)\?do</command-name>' <<<"$prompt" || exit 0
args=$(sed -n '/<command-args>/,/<\/command-args>/p' <<<"$prompt" | sed 's/<\/\?command-args>//g')
[ -n "${args//[[:space:]]/}" ] || exit 0
# A ticket key (GAME-12, never a standard such as UTF-8), an issue number
# (#87), a ticket note named by its timestamp, an issue or pull request link,
# or a chart.
sed -E 's/\b(UTF|UCS|SHA|MD|ISO|RFC|AES|TLS|HTTP|IPV|PEP|ES|X)-[0-9]+\b//g' <<<"$args" | grep -qE '\b[A-Z][A-Z0-9]+-[0-9]+\b|(^|[[:space:]])#[0-9]+\b|\b[0-9]{14} [^/]*\.md\b|https?://[^[:space:]]*/(issues|pulls?)/[0-9]+|Star Chart' && exit 0
# An objective stated in full is taken: it holds no question and no hedge.
if ! grep -qiE '\?|\b(maybe|perhaps|might|could|can|should|would|what about|how about|not sure|or so|i guess|wonder)\b' <<<"$args"; then
  hint='The objective of this /do is stated in full in the user'"'"'s own words, so do step 0 takes it: your first message says "Going with: <the objective>" in one line, then the build starts, with no gate. Every later choice that is cheap to undo takes its pick and says "Going with".'
  jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$h}}'
  exit 0
fi
hint='The objective of this /do is one you read into from the user'"'"'s words (a question or a hedge), so do step 0 applies: your first message is a 🚪 Waiting on you: gate that says the objective back, and nothing is built until the user answers. Only that first question waits: every later choice that is cheap to undo takes its pick and says "Going with".'
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$h}}'
