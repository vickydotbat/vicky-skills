#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a command that takes a pull request out of
# draft while another pull request in the repo is out of draft, or a CI run
# started in the last two hours is going for another branch. CI on a pull
# request that is not first in line is wasted: the one ahead merges, this
# one rebases, and CI runs again. A draft is not in line: CI runs only to merge. Two runs side by side also slow each other.
# Forges: GitHub (gh pr ready, gh pr create without --draft), Gitea (tea pr
# edit or tea pr create with a title that drops WIP:), GitLab (glab mr update
# --ready, glab mr create without --draft). A raw API call is not caught.
# When the forge's tool can't answer, the command is refused, since the queue
# can't be shown clear. On by default; the plugin option guard_ready_queue set
# to false or 0 turns it off.
case "${CLAUDE_PLUGIN_OPTION_GUARD_READY_QUEUE:-}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the command reads back empty, and the hook exits 0 the same way
cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
# The title's quotes are kept for tea, where the title is the draft marker.
bare=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<<"$cmd")
s='(^|[;&|[:space:]])'; e='([[:space:];&|]|$)'
num() { grep -oE "$1[[:space:]]+#?!?[0-9]+" <<<"$bare" | grep -oE '[0-9]+$' | head -1; }
title() { grep -oE -- "(-t|--title)[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:]]+)" <<<"$cmd" | head -1 | sed -E "s/^(-t|--title)[[:space:]]+[\"']?//"; }
if grep -qE "${s}gh[[:space:]]+pr[[:space:]]+ready$e" <<<"$bare"; then
  forge=gh; grep -qE -- '--undo' <<<"$bare" && exit 0
  n=$(num 'gh[[:space:]]+pr[[:space:]]+ready'); [ -n "$n" ] || n=$(gh pr view --json number --jq .number 2>/dev/null)
elif grep -qE "${s}gh[[:space:]]+pr[[:space:]]+create$e" <<<"$bare"; then
  forge=gh; grep -qE -- '(^|[[:space:]])(--draft|-d)([[:space:]=]|$)' <<<"$bare" && exit 0; n=999999999
elif grep -qE "${s}tea[[:space:]]+(pr|pulls)[[:space:]]+(edit|create)$e" <<<"$bare"; then
  forge=tea; t=$(title); [ -n "$t" ] || exit 0
  grep -qiE '^(WIP:|\[WIP\]|Draft:)' <<<"$t" && exit 0
  n=$(num 'tea[[:space:]]+(pr|pulls)[[:space:]]+edit'); [ -n "$n" ] || n=999999999
elif grep -qE "${s}glab[[:space:]]+mr[[:space:]]+update$e" <<<"$bare" && grep -qE -- '(^|[[:space:]])(--ready|-r)([[:space:]]|$)' <<<"$bare"; then
  forge=glab; n=$(num 'glab[[:space:]]+mr[[:space:]]+update')
elif grep -qE "${s}glab[[:space:]]+mr[[:space:]]+create$e" <<<"$bare"; then
  forge=glab; grep -qE -- '(^|[[:space:]])(--draft|--wip)([[:space:]]|$)' <<<"$bare" && exit 0; n=999999999
else
  exit 0 # mutant-ok delete: the deny is already printed, and the checks after it print no second one on any input that reached it
fi
deny() {
  jq -n --arg r "ready-queue-guard: refused, $1 Nothing in this command ran. Keep this pull request a draft, and mark it ready once the queue is clear: no other pull request out of draft and no CI run for another branch. Wait for that with watch.sh, and work on what doesn't wait." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0 # mutant-ok delete: the deny is already printed, and the checks after it print no second one on any input that reached it
}
mine=$(git branch --show-current 2>/dev/null)
# Each forge's lists, as [{number,branch,title,draft}] and [{branch,title,status,started}].
case $forge in
  gh)
    prs=$(gh pr list --state open --json number,headRefName,title,isDraft --limit 100 2>/dev/null | jq -c '[.[]|{number,branch:.headRefName,title,draft:.isDraft}]' 2>/dev/null) || prs=""
    runs=$(gh run list --json headBranch,displayTitle,status,createdAt --limit 50 2>/dev/null | jq -c '[.[]|{branch:.headBranch,title:.displayTitle,status,started:.createdAt}]' 2>/dev/null) || runs="" ;;
  tea)
    prs=$(tea pr list --state open -o json -f index,head,title </dev/null 2>/dev/null | jq -c '[.[]|{number:(.index|tonumber),branch:.head,title,draft:(.title|test("^(WIP:|\\[WIP\\]|Draft:)";"i"))}]' 2>/dev/null) || prs=""
    runs=$(tea actions runs list -o json </dev/null 2>/dev/null | jq -c '[.[]|{branch,title:.workflow,status,started}]' 2>/dev/null) || runs="" ;;
  glab)
    prs=$(glab mr list -F json 2>/dev/null | jq -c '[.[]|{number:.iid,branch:.source_branch,title,draft:(.draft // .work_in_progress // false)}]' 2>/dev/null) || prs=""
    runs=$(glab ci list -F json 2>/dev/null | jq -c '[.[]|{branch:.ref,title:"",status,started:.created_at}]' 2>/dev/null) || runs="" ;;
esac
[ -n "$prs" ] || deny "$forge could not list the open pull requests, so the queue can't be shown clear."
[ -n "$runs" ] || deny "$forge could not list the CI runs, so the queue can't be shown clear."
[ -n "$n" ] || deny "no pull request number was found for this branch."
ahead=$(jq -r --argjson n "$n" --arg b "$mine" '[.[]|select(.draft|not)|select(.number != $n and .branch != $b)|"#\(.number)"]|join(" ")' <<<"$prs")
[ -z "$ahead" ] || deny "other pull requests are out of draft: $ahead. Each one ahead merges first, and this one rebases after it."
# A run counts as this branch's when its branch or its title (Gitea leaves the
# branch empty on a pull request's run) matches this branch's pull request.
own=$(jq -r --arg b "$mine" '[.[]|select(.branch==$b)|.title][0] // ""' <<<"$prs")
since=$(( $(date +%s) - 7200 ))
busy=$(jq -r --arg b "$mine" --arg t "$own" --argjson since "$since" '[.[]
  | select(.status|test("^(in_progress|queued|waiting|pending|running|created)$"))
  | select((.started // "" | sub("\\.[0-9]+";"") | try fromdateiso8601 catch 0) >= $since)
  | select(.branch != $b and (.branch != "" or .title != $t))
  | if .branch != "" then .branch else .title end]|unique|join(", ")' <<<"$runs")
[ -z "$busy" ] || deny "CI is running for another branch: $busy. Two runs side by side slow each other down."
