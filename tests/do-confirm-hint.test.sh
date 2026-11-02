#!/usr/bin/env bash
# The do-confirm hint's decisions beyond its approved examples: which prompts
# count as a typed /do, what counts as a written-down objective, and bad input.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/do-confirm-hint.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { jq -nc --arg p "$1" '{prompt:$p}' | bash "$hook" 2>/dev/null; }
cmd() { printf '<command-name>/%s</command-name>\n<command-args>%s</command-args>' "$1" "$2"; }
hinted() { run "$1" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and (.hookSpecificOutput.additionalContext | test("step 0"))' >/dev/null 2>&1; }
check "the plugin's /do with an objective is hinted" 'hinted "$(cmd vicky-skills:do "zip every download")"'
check "a bare /do with an objective is hinted" 'hinted "$(cmd do "zip every download")"'
check "an objective over several lines is hinted" 'hinted "$(cmd do "zip every download
and gzip single files")"'
check "a /do with no objective gets nothing" '[ -z "$(run "$(cmd do "")")" ] && [ -z "$(run "$(cmd do "   ")")" ]'
for a in "PLAT-3 next" "issue #12" "vicky-skills/20261102150016 do opens.md" "https://example.org/o/r/issues/4" "https://example.org/o/r/pull/9" "Star Chart - depot"; do
  check "a written-down objective gets nothing: $a" '[ -z "$(run "$(cmd do "$a")")" ]'
done
check "a word with a dash and digits is still an objective" 'hinted "$(cmd do "make utf-8 names safe")"'
check "a file or a link in the objective is still an objective" 'hinted "$(cmd do "fix the typo in README.md, as https://example.org/docs says")"'
check "a hash inside a word is still an objective" 'hinted "$(cmd do "rename C#7 notes")"'
check "another command gets nothing" '[ -z "$(run "$(cmd vicky-skills:review "the branch")")" ] && [ -z "$(run "$(cmd dot "zip it")")" ]'
check "plain chat gets nothing" '[ -z "$(run "please do zip every download")" ]'
check "bad input exits 0 with nothing" '[ -z "$(echo "not json" | bash "$hook")" ] && echo "not json" | bash "$hook"; [ $? = 0 ]'
check "no objective exits 0" 'run "$(cmd do "")" >/dev/null; [ $? = 0 ]'
check "a written-down objective exits 0" 'run "$(cmd do "PLAT-3")" >/dev/null; [ $? = 0 ]'
check "a hint exits 0" 'run "$(cmd do "zip it")" >/dev/null; [ $? = 0 ]'
exit $fail
