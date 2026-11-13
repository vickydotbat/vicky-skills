#!/usr/bin/env bash
# adr-scope-hint adds the record scope rule as context when an edit or write
# targets a decision record, stays silent on any other file, and is off only
# when its setting says false.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/adr-scope-hint.sh"
fail=0
run() { # tool path [option]
  jq -n --arg t "$1" --arg f "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$f}}' \
    | env ${3+CLAUDE_PLUGIN_OPTION_ADR_SCOPE_HINT="$3"} bash "$hook"
}
hints() { # name tool path [option]
  out=$(run "$2" "$3" ${4+"$4"}); code=$?
  if [ $code = 0 ] && jq -e '.hookSpecificOutput.hookEventName == "PreToolUse" and (.hookSpecificOutput.additionalContext | test("macro") and test("Scope") and test("comment at the code") and test("decision-record") and test("appended Status line"))' <<<"$out" >/dev/null 2>&1
  then echo "ok   $1"; else echo "FAIL $1: exit $code, '$out'"; fail=1; fi
}
silent() { # name tool path [option]
  out=$(run "$2" "$3" ${4+"$4"}); code=$?
  if [ $code = 0 ] && [ -z "$out" ]; then echo "ok   $1"; else echo "FAIL $1: exit $code, '$out'"; fail=1; fi
}
hints "a write to a record under docs/adr" Write /repo/docs/adr/0012-one-store.md
hints "an edit to a record" Edit /repo/docs/adr/0012-one-store.md
hints "a multi-edit to a record" MultiEdit /repo/docs/adr/0012-one-store.md
hints "a record path relative to the repo" Write docs/adr/0001-x.md
hints "a package's own record folder" Write /repo/pkg/a/docs/adr/0003-y.md
hints "the setting on" Write /repo/docs/adr/0012-a.md true
silent "the setting off" Write /repo/docs/adr/0012-a.md false
silent "the setting off as 0" Write /repo/docs/adr/0012-a.md 0
silent "a plain file" Write /repo/src/main.rs
silent "a doc beside the records" Write /repo/docs/adr/README.md
silent "a three-digit number" Write /repo/docs/adr/012-a.md
silent "a record-like name outside an adr folder" Write /repo/docs/0012-a.md
silent "a folder whose name ends in adr" Write /repo/docs/radr/0012-a.md
silent "a record in a folder below adr" Write /repo/docs/adr/old/0012-a.md
silent "a text file numbered like a record" Write /repo/docs/adr/0012-a.txt
silent "a Bash call" Bash /repo/docs/adr/0012-a.md
out=$(echo 'not json' | bash "$hook"); code=$?
if [ $code = 0 ] && [ -z "$out" ]; then echo "ok   input that isn't JSON"; else echo "FAIL not json: $code '$out'"; fail=1; fi
exit $fail
