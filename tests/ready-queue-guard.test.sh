#!/usr/bin/env bash
# ready-queue-guard refuses taking a pull request out of draft on GitHub, Gitea
# or GitLab while another one is out of draft or CI runs for another branch,
# refuses when the forge tool fails, and lets drafts, other drafts, stale or
# own runs, other commands, bad input and the setting off through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/ready-queue-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir "$dir/bin"
for t in gh tea glab; do
  cat > "$dir/bin/$t" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *"pr list"*|*"mr list"*) [ -n "${FAIL_PRS:-}" ] && exit 1; echo "${PRS:-[]}" ;;
  *"run list"*|*"runs list"*|*"ci list"*) [ -n "${FAIL_RUNS:-}" ] && exit 1; echo "${RUNS:-[]}" ;;
  *"pr view"*) [ -n "${VIEW:-}" ] && echo "$VIEW" || exit 1 ;;
esac
STUB
  chmod +x "$dir/bin/$t"
done
git -C "$dir" init -q -b mine
now=$(date -u +%Y-%m-%dT%H:%M:%SZ); old=$(date -u -d '-3 hours' +%Y-%m-%dT%H:%M:%SZ)
fail=0
run() {
  local out code
  out=$(cd "$dir" && jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' |
    PATH="$dir/bin:$PATH" CLAUDE_PLUGIN_OPTION_GUARD_READY_QUEUE=${OPT:-true} bash "$hook"); code=$?
  [ "$code" = 0 ] || { echo "exit $code"; return; }
  jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out"
}
reason() { cd "$dir" && jq -n --arg c "$1" '{tool_input:{command:$c}}' | PATH="$dir/bin:$PATH" bash "$hook" | jq -r .hookSpecificOutput.permissionDecisionReason; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
# GitHub
ready='[{"number":5,"headRefName":"old","title":"a","isDraft":false},{"number":7,"headRefName":"mine","title":"m","isDraft":true}]'
drafts='[{"number":5,"headRefName":"old","title":"a","isDraft":true},{"number":7,"headRefName":"mine","title":"m","isDraft":true},{"number":9,"headRefName":"n","title":"b","isDraft":true}]'
newer='[{"number":7,"headRefName":"mine","title":"m","isDraft":true},{"number":9,"headRefName":"n","title":"b","isDraft":false}]'
busy="[{\"headBranch\":\"other\",\"displayTitle\":\"x\",\"status\":\"in_progress\",\"createdAt\":\"$now\"}]"
check "another pull request out of draft refuses ready" deny "$(PRS=$ready run "gh pr ready 7")"
check "the refusal names it" 1 "$(PRS=$ready reason "gh pr ready 7" | grep -c '#5')"
check "a newer one out of draft refuses too" deny "$(PRS=$newer run "gh pr ready 7")"
check "other drafts are not in line" "" "$(PRS=$drafts run "gh pr ready 7")"
check "a #-number counts" deny "$(PRS=$ready run "gh pr ready #7")"
check "with no number, the branch's pull request counts" deny "$(PRS=$ready VIEW=7 run "gh pr ready")"
check "with no number and none found, it refuses" deny "$(PRS=$drafts run "gh pr ready")"
for s in in_progress queued waiting pending; do
  check "a $s run for another branch refuses" deny "$(PRS=$drafts RUNS="[{\"headBranch\":\"other\",\"displayTitle\":\"x\",\"status\":\"$s\",\"createdAt\":\"$now\"}]" run "gh pr ready 7")"
done
check "the refusal names the busy branch" 1 "$(PRS=$drafts RUNS=$busy reason "gh pr ready 7" | grep -c 'other')"
check "a run for this branch does not block" "" "$(PRS=$drafts RUNS="[{\"headBranch\":\"mine\",\"displayTitle\":\"m\",\"status\":\"in_progress\",\"createdAt\":\"$now\"}]" run "gh pr ready 7")"
check "a finished run does not block" "" "$(PRS=$drafts RUNS="[{\"headBranch\":\"other\",\"displayTitle\":\"x\",\"status\":\"completed\",\"createdAt\":\"$now\"}]" run "gh pr ready 7")"
check "a run stuck for hours does not block" "" "$(PRS=$drafts RUNS="[{\"headBranch\":\"other\",\"displayTitle\":\"x\",\"status\":\"in_progress\",\"createdAt\":\"$old\"}]" run "gh pr ready 7")"
check "gh failing on pull requests refuses" deny "$(FAIL_PRS=1 run "gh pr ready 7")"
check "gh failing on runs refuses" deny "$(PRS=$drafts FAIL_RUNS=1 run "gh pr ready 7")"
check "a non-draft create with one out of draft refuses" deny "$(PRS=$ready run "gh pr create --title x --body-file b")"
check "a non-draft create with CI busy refuses" deny "$(RUNS=$busy run "gh pr create --title x")"
check "a draft create passes" "" "$(PRS=$ready RUNS=$busy run "gh pr create --draft --title x")"
check "a -d create passes" "" "$(PRS=$ready run "gh pr create -d --title x")"
check "a non-draft create on a clear queue passes" "" "$(PRS=$drafts run "gh pr create --title x")"
check "ready --undo passes" "" "$(PRS=$ready run "gh pr ready 7 --undo")"
check "a chained ready counts" deny "$(PRS=$ready run "git push && gh pr ready 7")"
check "a quoted mention passes" "" "$(PRS=$ready run "git commit -m 'gh pr ready 7 later'")"
check "another command passes" "" "$(PRS=$ready run "gh pr view 7")"
# Gitea: the WIP: title is the draft marker, and a pull request's run has no branch
tready='[{"index":"5","head":"old","title":"a"},{"index":"7","head":"mine","title":"WIP: m"}]'
tdrafts='[{"index":"5","head":"old","title":"WIP: a"},{"index":"7","head":"mine","title":"WIP: m"}]'
check "tea: dropping WIP: with another out of draft refuses" deny "$(PRS=$tready run "tea pr edit 7 -t 'm' </dev/null")"
check "tea: other WIP: drafts are not in line" "" "$(PRS=$tdrafts run "tea pr edit 7 -t \"m\" </dev/null")"
check "tea: a title kept WIP: passes" "" "$(PRS=$tready run "tea pr edit 7 -t 'WIP: m2' </dev/null")"
check "tea: an edit with no title passes" "" "$(PRS=$tready run "tea pr edit 7 --add-labels x </dev/null")"
check "tea: a create without WIP: refuses" deny "$(PRS=$tready run "tea pr create --title 'new' </dev/null")"
check "tea: another pull request's run refuses" deny "$(PRS=$tdrafts RUNS="[{\"branch\":\"\",\"workflow\":\"WIP: a\",\"status\":\"in_progress\",\"started\":\"$now\"}]" run "tea pr edit 7 -t 'm' </dev/null")"
check "tea: this pull request's own run does not block" "" "$(PRS=$tdrafts RUNS="[{\"branch\":\"\",\"workflow\":\"WIP: m\",\"status\":\"in_progress\",\"started\":\"$now\"}]" run "tea pr edit 7 -t 'm' </dev/null")"
check "tea: retitling a pull request already out of draft passes" "" "$(PRS='[{"index":"7","head":"elsewhere","title":"m"}]' run "tea pr edit 7 -t 'm2' </dev/null")"
check "tea: failing refuses" deny "$(FAIL_PRS=1 run "tea pr edit 7 -t 'm' </dev/null")"
# GitLab
gready='[{"iid":5,"source_branch":"old","title":"a","draft":false},{"iid":7,"source_branch":"mine","title":"m","draft":true}]'
gdrafts='[{"iid":5,"source_branch":"old","title":"a","draft":true}]'
check "glab: --ready with another out of draft refuses" deny "$(PRS=$gready run "glab mr update 7 --ready")"
check "glab: other drafts are not in line" "" "$(PRS=$gdrafts run "glab mr update 7 --ready")"
check "glab: a running pipeline elsewhere refuses" deny "$(PRS=$gdrafts RUNS="[{\"ref\":\"other\",\"status\":\"running\",\"created_at\":\"$now\"}]" run "glab mr update 7 --ready")"
check "glab: an update without --ready passes" "" "$(PRS=$gready run "glab mr update 7 --title x")"
check "glab: a --draft create passes" "" "$(PRS=$gready run "glab mr create --draft")"
check "glab: a non-draft create refuses" deny "$(PRS=$gready run "glab mr create --fill")"
# A pull request whose last run failed is not in line
check "gh: one out of draft with a failed run does not block" "" "$(PRS='[{"number":5,"headRefName":"old","title":"a","isDraft":false,"statusCheckRollup":[{"conclusion":"FAILURE"}]}]' run "gh pr ready 7")"
check "gh: one out of draft with a passing run still blocks" deny "$(PRS='[{"number":5,"headRefName":"old","title":"a","isDraft":false,"statusCheckRollup":[{"conclusion":"SUCCESS"}]}]' run "gh pr ready 7")"
check "gh: one out of draft with a status error does not block" "" "$(PRS='[{"number":5,"headRefName":"old","title":"a","isDraft":false,"statusCheckRollup":[{"state":"ERROR"}]}]' run "gh pr ready 7")"
check "tea: one out of draft with failed ci does not block" "" "$(PRS='[{"index":"5","head":"old","title":"a","ci":"failure"}]' run "tea pr edit 7 -t 'm' </dev/null")"
check "tea: one out of draft with pending ci still blocks" deny "$(PRS='[{"index":"5","head":"old","title":"a","ci":"pending"}]' run "tea pr edit 7 -t 'm' </dev/null")"
check "glab: one out of draft with a failed pipeline does not block" "" "$(PRS='[{"iid":5,"source_branch":"old","title":"a","draft":false,"head_pipeline":{"status":"failed"}}]' run "glab mr update 7 --ready")"
check "glab: one out of draft with a running pipeline still blocks" deny "$(PRS='[{"iid":5,"source_branch":"old","title":"a","draft":false,"head_pipeline":{"status":"running"}}]' run "glab mr update 7 --ready")"
# Off and bad input
check "the setting off passes" "" "$(OPT=false PRS=$ready run "gh pr ready 7")"
check "the setting 0 passes" "" "$(OPT=0 PRS=$ready run "gh pr ready 7")"
check "bad input passes" "" "$(cd "$dir" && echo 'not json' | PATH="$dir/bin:$PATH" bash "$hook")"
exit $fail
