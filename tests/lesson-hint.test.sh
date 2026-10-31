#!/usr/bin/env bash
# The hook adds the engrave hint to a message that teaches a lesson, and only
# when switched on.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/lesson-hint.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
expect() { # $1 want hint|none, $2 label, $3 option, $4 payload
  local got code
  got=$(printf '%s' "$4" | CLAUDE_PLUGIN_OPTION_LESSON_HINT=$3 "$hook" 2>/dev/null); code=$?
  if [ "$code" != 0 ]; then echo "FAIL $2: exit $code"; fail=1; return; fi
  case "$1" in
    hint) jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and (.hookSpecificOutput.additionalContext | test("engrave"))' <<<"$got" >/dev/null 2>&1 ;;
    none) [ -z "$got" ] ;;
  esac && echo "ok   $2" || { echo "FAIL $2: got '$got'"; fail=1; }
}
p() { jq -nc --arg p "$1" '{prompt:$p}'; }
for phrase in "codify it" "Codified?" "write the lesson" "for the future, wait" "From now on use hooks" "make sure we know how" "prevent this from happening" "Prevent that"; do
  expect hint "hint on: $phrase" true "$(p "$phrase")"
done
expect hint "option 1 counts as on" 1 "$(p "codify it")"
for phrase in "make it so" "prevent" "the future is bright" "now on to the next"; do
  expect none "no hint: $phrase" true "$(p "$phrase")"
done
expect none "option off" false "$(p "codify it")"
expect none "option empty" "" "$(p "codify it")"
expect none "no prompt field" true '{}'
expect none "input that is not JSON" true 'not json'
mkdir "$scratch/bin"; for t in bash cat; do ln -s "$(command -v $t)" "$scratch/bin/$t"; done
got=$(p "codify it" | PATH="$scratch/bin" CLAUDE_PLUGIN_OPTION_LESSON_HINT=true "$(command -v bash)" "$hook" 2>/dev/null); code=$?
[ "$code" = 0 ] && [ -z "$got" ] && echo "ok   without jq it stays quiet" || { echo "FAIL without jq: exit $code, '$got'"; fail=1; }
exit $fail
