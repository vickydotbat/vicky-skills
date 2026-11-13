#!/usr/bin/env bash
# The foreign-post hint: a gh command that posts a pull request, review or
# comment to a repository the user does not administer gets one line of
# context steering its text through red-pen. A post to the user's own
# repository, any other command, the setting off, a missing gh and bad input
# pass silently. It never refuses. A stub gh stands in for the forge.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/foreign-post-hint.sh"
unset CLAUDE_PLUGIN_OPTION_FOREIGN_POST_HINT
fail=0
stub=$(mktemp -d); trap 'rm -rf "$stub"' EXIT
# The stub answers `gh repo view [<repo>] --json ...`: the checkout is a fork
# of stranger/upstream owned by me, and any other named repo is the stranger's.
cat >"$stub/gh" <<'GH'
#!/usr/bin/env bash
[ "$1 $2" = "repo view" ] || exit 1
[ "${FAIL:-}" = all ] && exit 1
[ "${FAIL:-}" = parent ] && [ "${3:-}" = stranger/upstream ] && exit 1
case "${3:-}" in
  --json|"") echo '{"viewerPermission":"ADMIN","isFork":'"${FORK:-true}"',"parent":{"nameWithOwner":"stranger/upstream"}}' ;;
  me/*) echo '{"viewerPermission":"ADMIN","isFork":false,"parent":null}' ;;
  *) echo '{"viewerPermission":"READ","isFork":false,"parent":null}' ;;
esac
GH
chmod +x "$stub/gh"
run() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | PATH="$stub:$PATH" bash "$hook"; }
hinted() { local out; out=$(run "$1"); [ $? = 0 ] && jq -e '.hookSpecificOutput.additionalContext | test("red-pen")' <<<"$out" >/dev/null; }
quiet() { local out; out=$(run "$1"); [ $? = 0 ] && [ -z "$out" ]; }
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

for c in "gh pr create --title T --body-file b.md" "gh pr ready 664" "gh pr comment 664 --body '@coderabbitai review'" "gh pr review 664 --comment -b ok" "gh pr edit 664 --body-file b.md" "gh issue create -t T -b B" "gh issue comment 3 -b hi" "cd x && gh pr create -f" "gh pr create -R stranger/upstream -t T -b B" "gh pr comment 1 --repo other/thing -b hi"; do
  check "a post to a stranger's repo is hinted: $c" "hinted \"\$c\""
done
check "the hint names the target repo" 'run "gh pr create -t T -b B" | jq -e ".hookSpecificOutput.additionalContext | test(\"stranger/upstream\")" >/dev/null'
for c in "gh pr create -R me/mine -t T -b B" "gh issue comment 3 --repo me/mine -b hi" "gh pr view 664" "gh pr list" "gh pr checks 664" "git push" "echo gh pr create" "gh api repos/x/y"; do
  check "anything else passes quietly: $c" "quiet \"\$c\""
done
check "a post to the user's own non-fork checkout passes quietly" 'out=$(FORK=false run "gh pr create -t T -b B"); [ $? = 0 ] && [ -z "$out" ]'
check "the setting off passes quietly" 'out=$(CLAUDE_PLUGIN_OPTION_FOREIGN_POST_HINT=false run "gh pr ready 664"); [ $? = 0 ] && [ -z "$out" ]'
check "the setting 0 passes quietly" 'out=$(CLAUDE_PLUGIN_OPTION_FOREIGN_POST_HINT=0 run "gh pr ready 664"); [ $? = 0 ] && [ -z "$out" ]'
nogh=$(mktemp -d); trap 'rm -rf "$stub" "$nogh"' EXIT
for t in bash jq grep sed head; do ln -s "$(command -v $t)" "$nogh/$t"; done
check "a missing gh passes quietly" 'out=$(jq -nc "{tool_input:{command:\"gh pr ready 1\"}}" | PATH="$nogh" "$nogh/bash" "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "a forge that does not answer passes quietly" 'out=$(FAIL=all run "gh pr ready 1"); [ $? = 0 ] && [ -z "$out" ]'
check "a fork whose parent does not answer passes quietly" 'out=$(FAIL=parent run "gh pr ready 1"); [ $? = 0 ] && [ -z "$out" ]'
check "bad input passes quietly" 'out=$(echo "not json" | PATH="$stub:$PATH" bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
exit $fail
