#!/usr/bin/env bash
# patch-tell-hint adds context, never a refusal, when an edit to a CI
# workflow adds a patch tell: a retry, a sleep, continue-on-error, a step or
# job switched off, a skipped test, or a raised timeout. Covers each tell,
# each quiet case, the repo opt-out, the setting off and bad input.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/patch-tell-hint.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
opt=true
git init -q "$fx/r"; mkdir -p "$fx/r/.github/workflows" "$fx/r/.gitea/workflows" "$fx/r/docs/agents"
wf="$fx/r/.github/workflows/ci.yml"
printf 'jobs:\n  test:\n    timeout-minutes: 20\n    steps:\n      - run: make test\n' > "$wf"
run() { CLAUDE_PLUGIN_OPTION_PATCH_TELL_HINT=$opt "$hook" <<<"$1" 2>"$fx/err"; }
edit() { jq -nc --arg p "$1" --arg o "$2" --arg n "$3" '{tool_name:"Edit",cwd:"/",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'; }
hint() { # hint <label> <payload> <word the hint names, or empty for none>
  local out; out=$(run "$2"); local rc=$?
  if [ -z "$3" ]; then
    if [ $rc = 0 ] && [ -z "$out" ] && [ ! -s "$fx/err" ]; then echo "ok   $1"; else echo "FAIL $1: rc=$rc out=$out"; fail=1; fi
  elif [ $rc = 0 ] && jq -e --arg w "$3" '.hookSpecificOutput.hookEventName == "PreToolUse" and (.hookSpecificOutput.additionalContext | contains($w)) and (.hookSpecificOutput.additionalContext | contains("machine-spirit step 7"))' >/dev/null 2>&1 <<<"$out"; then echo "ok   $1"
  else echo "FAIL $1: rc=$rc out=$out"; fail=1; fi
}
hint "an added retry action is named" "$(edit "$wf" '      - run: make test' '      - uses: nick-fields/retry@v3')" "a retry"
hint "an added retry loop is named" "$(edit "$wf" '      - run: make test' '      - run: for i in 1 2 3; do make test && break; done')" "a retry"
hint "an added --reruns is named a retry" "$(edit "$wf" '      - run: make test' '      - run: pytest --reruns 3')" "a retry"
hint "an added sleep is named" "$(edit "$wf" '      - run: make test' '      - run: sleep 30 && make test')" "a sleep"
hint "an added continue-on-error is named" "$(edit "$wf" '      - run: make test' $'      - run: make test\n        continue-on-error: true')" "continue-on-error"
hint "a step switched off is named" "$(edit "$wf" '      - run: make test' $'      - if: false\n        run: make test')" "switched off"
hint "a step switched off by expression is named" "$(edit "$wf" '      - run: make test' $'      - if: ${{ false }}\n        run: make test')" "switched off"
hint "an added test skip is named" "$(edit "$wf" '      - run: make test' '      - run: go test -skip TestFlaky ./...')" "a skipped test"
hint "a raised timeout is named" "$(edit "$wf" '    timeout-minutes: 20' '    timeout-minutes: 40')" "a raised timeout"
hint "a lowered timeout is quiet" "$(edit "$wf" '    timeout-minutes: 20' '    timeout-minutes: 10')" ""
hint "a first timeout, a crash guard, is quiet" "$(edit "$wf" '    steps:' $'    timeout-minutes: 15\n    steps:')" ""
hint "a tell already in the old text is quiet" "$(edit "$wf" $'      - run: sleep 5 && make test' $'      - run: sleep 5 && make test\n      - run: make lint')" ""
hint "an edit with no tell is quiet" "$(edit "$wf" '      - run: make test' '      - run: make test lint')" ""
hint "a Gitea workflow is read too" "$(edit "$fx/r/.gitea/workflows/pr.yaml" 'x' '        continue-on-error: true')" "continue-on-error"
hint "a file outside the workflow folders is quiet" "$(edit "$fx/r/scripts/ci.sh" 'x' 'sleep 30')" ""
w=$(jq -nc --arg p "$wf" --arg c $'jobs:\n  test:\n    timeout-minutes: 60\n    steps:\n      - run: make test\n' '{tool_name:"Write",cwd:"/",tool_input:{file_path:$p,content:$c}}')
hint "a Write is compared with the file on disk" "$w" "a raised timeout"
w=$(jq -nc --arg p "$fx/r/.github/workflows/new.yml" --arg c $'jobs:\n  t:\n    timeout-minutes: 30\n    steps:\n      - run: make\n' '{tool_name:"Write",cwd:"/",tool_input:{file_path:$p,content:$c}}')
hint "a new workflow's first timeout is quiet" "$w" ""
m=$(jq -nc --arg p "$wf" '{tool_name:"MultiEdit",cwd:"/",tool_input:{file_path:$p,edits:[{old_string:"make test",new_string:"make test"},{old_string:"timeout-minutes: 20",new_string:"timeout-minutes: 45"}]}}')
hint "a MultiEdit reads every edit" "$m" "a raised timeout"
out=$(run "$(edit "$wf" '      - run: make test' '      - run: sleep 9 && pytest --reruns 2')")
if jq -e '.hookSpecificOutput.additionalContext | (contains("a retry") and contains("a sleep") and contains("not the scripts it calls") and contains("Patch-tell hint: off"))' >/dev/null 2>&1 <<<"$out"; then echo "ok   two tells are named together, with the hint's limit and its opt-out"; else echo "FAIL two tells together: $out"; fail=1; fi
printf 'Patch-tell hint: off\n' > "$fx/r/docs/agents/domain.md"
hint "a repo that switched it off in docs/agents is quiet" "$(edit "$wf" '      - run: make test' '      - run: sleep 30')" ""
rm "$fx/r/docs/agents/domain.md"; printf '# Agents\n\nPatch-tell hint: off\n' > "$fx/r/AGENTS.md"
hint "a repo that switched it off in AGENTS.md is quiet" "$(edit "$wf" '      - run: make test' '      - run: sleep 30')" ""
rm "$fx/r/AGENTS.md"
opt=false; hint "setting off is quiet" "$(edit "$wf" '      - run: make test' '      - run: sleep 30')" ""
opt=0; hint "setting 0 is quiet" "$(edit "$wf" '      - run: make test' '      - run: sleep 30')" ""; opt=true
hint "another tool on a workflow file is quiet" "$(jq -nc --arg p "$wf" '{tool_name:"NotebookEdit",tool_input:{file_path:$p,new_source:"sleep 30"}}')" ""
hint "another tool is quiet" '{"tool_name":"Bash","tool_input":{"command":"sleep 30"}}' ""
hint "input that isn't JSON is quiet" 'not json' ""
got=$(PATH=/nonexistent CLAUDE_PLUGIN_OPTION_PATCH_TELL_HINT=true "$BASH" "$hook" <<<"$(edit "$wf" 'a' 'sleep 30')" 2>/dev/null; echo "|$?")
if [ "$got" = "|0" ]; then echo "ok   without jq it is quiet"; else echo "FAIL without jq: $got"; fail=1; fi
exit $fail
