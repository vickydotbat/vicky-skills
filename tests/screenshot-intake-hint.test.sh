#!/usr/bin/env bash
# The screenshot-intake hint's decisions beyond its approved examples: which
# extensions and forms of path count, how paths are counted, and bad input.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/screenshot-intake-hint.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { jq -nc --arg p "$1" '{prompt:$p}' | bash "$hook" 2>/dev/null; }
said() { run "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
hinted() { run "$1" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and (.hookSpecificOutput.additionalContext | test("screenshot-intake"))' >/dev/null 2>&1; }
for e in png jpg jpeg webp PNG JPG; do
  check "a .$e path is hinted" 'hinted "see pics/shot.'$e'"'
done
check "a gif or a text file is not an image here" '[ -z "$(run "see pics/a.gif and pics/a.txt")" ]'
check "an extension that only starts like one gets nothing" '[ -z "$(run "see pics/a.pngx and pics/b.jpgs")" ]'
check "a bare file name with no folder gets nothing" '[ -z "$(run "see shot.png")" ]'
check "a quoted path is hinted" 'hinted "see \"pics/shot.png\" now" && hinted "see '"'"'pics/shot.png'"'"' now"'
check "a path closing a sentence is hinted" 'hinted "it is in pics/shot.png."'
check "the same path twice counts once" 'said "pics/a.png and pics/a.png" | grep -q "holds 1 image path "'
check "two paths count two and use the plural" 'said "pics/a.png pics/b.png" | grep -q "holds 2 image paths "'
check "an empty prompt gets nothing" '[ -z "$(run "")" ]'
check "a missing prompt field gets nothing" '[ -z "$(echo "{}" | bash "$hook" 2>/dev/null)" ]'
check "bad input exits 0 with nothing" 'out=$(echo "not json" | bash "$hook" 2>&1); [ $? = 0 ] && [ -z "$out" ]'
check "a hint exits 0" 'run "pics/a.png" >/dev/null; [ $? = 0 ]'
check "the hint is one line of valid JSON" '[ "$(run "pics/a.png" | wc -l)" = 1 ] && run "pics/a.png" | jq -e . >/dev/null'
exit $fail
