#!/usr/bin/env bash
# approved-spec: robot-voice names every rule by a strong leading word,
# first and throughout. Each check reads the instruction that drives it.
set -u
f="$(dirname "$0")/../plugins/vicky-skills/skills/writing/robot-voice/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "a rule opens with its leading word, then the rule that pins it" \
  'grep -q "Name each rule" "$f" && grep -qF "<Leading word>: <the rule that pins its meaning here>." "$f"'
check "the leading word is used throughout, never paraphrased" \
  'grep -q "no later line names the rule by a paraphrase" "$f" && grep -q "Use the word throughout, not only at the top" "$f"'
check "the lint flags a sentence heading and filler" \
  'grep -q "opens with a leading word, not a sentence" "$f" && grep -q "No filler:" "$f"'
check "the debugging list catches a letter-not-spirit miss" \
  'grep -q "satisfy the letter and miss the point" "$f"'
exit $fail
