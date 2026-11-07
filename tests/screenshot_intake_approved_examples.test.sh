#!/usr/bin/env bash
# approved-spec: the screenshot-intake examples, approved 2026-11-07 on a
# drafts page. The hint hook runs on a typed prompt the way Claude Code sends
# one, and the skill is read the way an agent reads it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
hook="$root/scripts/screenshot-intake-hint.sh"
skill="$root/skills/productivity/screenshot-intake/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
said() { jq -nc --arg p "$1" '{hook_event_name:"UserPromptSubmit",prompt:$p}' | bash "$hook" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }

# SI1
# Given a prompt that holds the path of a PNG screenshot
# When the prompt is submitted
# Then the agent gets one line telling it to start screenshot-intake before it forms a theory
check "SI1 a screenshot path in a prompt is hinted" '[ -f "$hook" ] && out=$(said "look at pics/shot_1.png please") && [ "$(wc -l <<<"$out")" = 1 ] && grep -q "screenshot-intake" <<<"$out" && grep -qi "theory" <<<"$out"'

# SI2
# Given a prompt that holds a file:// link to a JPG whose name has %20 spaces
# When the prompt is submitted
# Then the agent gets the same one line
check "SI2 a percent-encoded file link is hinted" '[ -f "$hook" ] && a=$(said "see file://pics/My%20Shot.jpg") && b=$(said "look at pics/shot_1.png please") && [ -n "$a" ] && [ "$(sed "s/[0-9]* image.*//" <<<"$a")" = "$(sed "s/[0-9]* image.*//" <<<"$b")" ]'

# SI3
# Given a prompt that holds three screenshot links
# When the prompt is submitted
# Then the agent gets one line, not three, and it says how many images the prompt holds
check "SI3 several images give one line" '[ -f "$hook" ] && out=$(said "file://pics/one.png file://pics/two.png file://pics/three.png") && [ "$(wc -l <<<"$out")" = 1 ] && grep -q "3" <<<"$out"'

# SI4
# Given a prompt that mentions the word png or holds the path of a Markdown file
# When the prompt is submitted
# Then the agent gets no line
check "SI4 a prompt with no image path gets nothing" '[ -f "$hook" ] && [ -z "$(said "convert it to png and read notes/todo.md")" ] && [ -n "$(said "see pics/a.png")" ]'

# SI5
# Given the hook receives input that is not valid
# When the prompt is submitted
# Then the prompt goes through unchanged and the hook reports no error
check "SI5 bad input is harmless" '[ -f "$hook" ] && out=$(echo "not json" | bash "$hook" 2>&1); [ $? = 0 ] && [ -z "$out" ]'

# SI6
# Given the agent starts screenshot-intake
# When it follows the Steps in order
# Then it reads, says what it shows, zooms, records one line per image, and compares before a theory
walks() {
  [ -f "$skill" ] || return 1
  local steps i=0 n w
  steps=$(awk '/^## Steps/{f=1;next}/^## /{f=0}f' "$skill" | grep -E '^[0-9]+\. ')
  [ -n "$steps" ] || return 1
  [ "$(grep -c 'Done when' <<<"$steps")" = "$(wc -l <<<"$steps")" ] || return 1
  for w in Read shows zoom record compare; do
    n=$(grep -ni -m1 -- "$w" <<<"$steps" | cut -d: -f1)
    [ -n "$n" ] && [ "$n" -ge "$i" ] || return 1
    i=$n
  done
}
check "SI6 the skill walks read, say, crop, record, compare" 'walks'

# SI7
# Given a screenshot whose file name already has a recorded line
# When the user sends it again
# Then the agent says it is the one recorded earlier, quotes that line, and asks nothing about it
check "SI7 a resent screenshot matches its recorded line" '[ -f "$skill" ] && grep -qi "already" "$skill" && grep -qi "quote" "$skill" && grep -qi "ask nothing\|asks nothing\|never ask" "$skill"'
exit $fail
