#!/usr/bin/env bash
# Reads the state of every pull request and ticket each .todo line names, so
# sup's Still want never offers a line whose work already finished. One line
# out per .todo line (format: sup/SKILL.md step 3). A ref it cannot read keeps
# the line: only a line whose every ref was read and finished prints done.
# PARKED_STATE_LIMIT caps the seconds one lookup may take.
set -u
plugin=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}
limit=${PARKED_STATE_LIMIT:-10}
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$top/.todo" ] || exit 0
github=0; git remote get-url origin 2>/dev/null | grep -q 'github\.com' && github=1
pr_state() { # pr_state <n>: merged, closed, open or unread
  local s="" stub # mutant-ok delete: every path below sets s or leaves it empty, and an unset s reads unread the same
  # A repo-local stub file of "<n> <state>" lines stands in for the forge, so an eval with no forge can name a merged pull request.
  stub=$(git config --get parked-state.stub 2>/dev/null)
  if [ -n "$stub" ]; then
    case "$stub" in /*) ;; *) stub="$top/$stub" ;; esac
    s=$(awk -v n="$1" '$1 == n {print toupper($2)}' "$stub" 2>/dev/null)
  elif [ "$github" = 1 ]; then
    command -v gh >/dev/null && s=$(timeout "$limit" gh pr view "$1" --json state -q .state </dev/null 2>/dev/null)
  elif command -v tea >/dev/null; then
    s=$(timeout "$limit" tea api "repos/{owner}/{repo}/pulls/$1" </dev/null 2>/dev/null |
      jq -r 'if .merged == true then "MERGED" else (.state // "" | ascii_upcase) end' 2>/dev/null)
  fi
  case "$s" in MERGED) echo merged ;; CLOSED) echo closed ;; OPEN) echo open ;; *) echo unread ;; esac
}
ticket_state() { # ticket_state <key>: done, open or unread, from the thread's first column-0 state: or status: line
  local s # mutant-ok delete: the assignment below always sets s
  s=$(timeout "$limit" bash "$plugin/scripts/read-item.sh" "$1" </dev/null 2>/dev/null |
    grep -m1 -iE '^(state|status):' | sed -E 's/^[^:]*:[[:space:]]*//' | tr '[:upper:]' '[:lower:]')
  case "$s" in "") echo unread ;; "done"*|closed*|completed*|cancel*|resolved*) echo "done" ;; *) echo open ;; esac
}
# Each distinct ref is read once, all at once, so the run takes one lookup's time.
cache=$(mktemp -d); trap 'rm -rf "$cache"' EXIT
body=$(grep -vE '^(#|- Handoff:|N[0-9])' "$top/.todo")
for p in $(grep -oE '(![0-9]+|\bPR [0-9]+)\b' <<<"$body" | tr -dc '0-9\n' | sort -u); do pr_state "$p" > "$cache/pr-$p" & done
while read -r k; do [ -n "$k" ] && ticket_state "$k" > "$cache/tk-$k" & done < <(grep -oE '\b[A-Z][A-Z0-9]+-[0-9]+\b' <<<"$body" | sort -u)
wait
while IFS= read -r line; do
  case "$line" in ""|"#"*|"- Handoff:"*|N[0-9]*) continue ;; esac
  # Refs: !<n> and "PR <n>" are pull requests, KEY-<n> is a ticket. A bare #<n>
  # is too often a post or issue number to read as a pull request, so it reads unread.
  mapfile -t prs < <(grep -oE '(![0-9]+|\bPR [0-9]+)\b' <<<"$line" | tr -dc '0-9\n' | awk 'NF && !seen[$0]++')
  mapfile -t keys < <(grep -oE '\b[A-Z][A-Z0-9]+-[0-9]+\b' <<<"$line" | awk '!seen[$0]++')
  hashes=$(grep -oE '(^|[^&A-Za-z0-9])#[0-9]+\b' <<<"$line" | tr -dc '#0-9\n')
  states=() pr_open=0 tk_open=0 unread=0 n=0
  for p in "${prs[@]}"; do s=$(cat "$cache/pr-$p"); states+=("!$p $s"); n=$((n + 1))
    case "$s" in merged) ;; open|closed) pr_open=1 ;; *) unread=1 ;; esac; done # closed unmerged is abandoned, not finished
  for k in "${keys[@]}"; do s=$(cat "$cache/tk-$k"); states+=("$k $s"); n=$((n + 1))
    case "$s" in done) ;; open) tk_open=1 ;; *) unread=1 ;; esac; done
  for h in $hashes; do states+=("$h unread"); unread=1; n=$((n + 1)); done
  if [ "$n" = 0 ]; then v="no ref"
  elif [ "$unread" = 1 ]; then v=unread
  elif [ "$pr_open" = 1 ]; then v=open
  elif [ "$tk_open" = 0 ]; then v="done"
  elif [ "${#prs[@]}" -gt 0 ]; then v=merged-ticket-open
  else v=open; fi
  st=$(printf '%s, ' "${states[@]}"); st=${st%, }
  printf '%s: %s%s\n' "$v" "$line" "${st:+ [$st]}"
done < "$top/.todo"
