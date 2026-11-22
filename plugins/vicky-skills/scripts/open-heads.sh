# shellcheck shell=bash
# Sourced by merged-branch-guard and pr-guard: the heads of the user's open
# pull requests in one repository. open_heads <remote url> <seconds> prints
# one head per line, from gh on GitHub and tea elsewhere, each call held to
# <seconds>, and returns 1 when the forge's tool is missing or cannot answer.
open_heads() {
  local out me # mutant-ok delete: a local declaration: no caller reads these names
  if [[ $1 == *github.com* ]]; then
    out=$(timeout "$2" gh pr list --author @me --state open --json headRefName </dev/null 2>/dev/null) || return 1
    jq -r '.[].headRefName' <<<"$out" 2>/dev/null
  else
    me=$(timeout "$2" tea api user </dev/null 2>/dev/null | jq -r '.login // ""' 2>/dev/null)
    out=$(timeout "$2" tea pulls list --state open --output json --fields index,head,author </dev/null 2>/dev/null) || return 1
    jq -r --arg me "$me" '.[] | select(.author == $me) | .head' <<<"$out" 2>/dev/null
  fi
}
