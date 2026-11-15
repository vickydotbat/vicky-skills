#!/usr/bin/env bash
# Finds the newest **Handoff** for this branch and names every place it looked,
# so sup can't miss a posted handoff in silence. Output format: sup/SKILL.md step 1.
# Arguments are more ticket keys. FIND_HANDOFF_BRANCH overrides the branch.
set -u
plugin=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}
projects=${FIND_HANDOFF_PROJECTS_DIR:-$HOME/.claude/projects}
searched=() unread=() found=0
hit() { printf 'found: %s: %s\n' "$1" "$2"; found=1; }
branch=${FIND_HANDOFF_BRANCH:-$(git branch --show-current 2>/dev/null)}
[ -n "$branch" ] || unread+=("pull request, HEAD is detached")
pr_text="" # mutant-ok delete: every later read is "${pr_text}" in a quoted printf or jq, and an unset name prints the same empty text
if [ -n "$branch" ]; then
  if git remote get-url origin 2>/dev/null | grep -q 'github\.com'; then
    if command -v gh >/dev/null; then
      json=$(timeout 15 gh pr view "$branch" --json url,title,body,comments,state 2>/dev/null </dev/null)
      if [ -n "$json" ] && [ "$(jq -r .state <<<"$json")" = OPEN ]; then
        searched+=("pull request $(jq -r .url <<<"$json")")
        pr_text=$(jq -r '.title + "\n" + .body' <<<"$json")
        url=$(jq -r '[.comments[] | select(.body | startswith("**Handoff**"))] | last | .url // empty' <<<"$json")
        [ -n "$url" ] && hit "pull request comment" "$url"
      else unread+=("pull request, no open one for $branch"); fi
    else unread+=("pull request, gh is not installed"); fi
  elif command -v tea >/dev/null; then
    pr=$(timeout 15 tea pr list --state open --fields index,head,url,title,body -o json </dev/null 2>/dev/null |
      jq -c --arg b "$branch" '[.[] | select(.head == $b)] | first // empty' 2>/dev/null)
    if [ -n "$pr" ]; then
      searched+=("pull request $(jq -r .url <<<"$pr")")
      pr_text=$(jq -r '.title + "\n" + .body' <<<"$pr")
      n=$(jq -r .index <<<"$pr")
      url=$(timeout 15 tea api "repos/{owner}/{repo}/issues/$n/comments" </dev/null 2>/dev/null |
        jq -r '[.[] | select(.body | startswith("**Handoff**"))] | last | .html_url // empty' 2>/dev/null)
      [ -n "$url" ] && hit "pull request comment" "$url"
    else unread+=("pull request, no open one for $branch"); fi
  else unread+=("pull request, neither gh nor tea is installed"); fi
fi
# Ticket keys look like ABC-123.
mapfile -t keys < <({ printf '%s\n' "$@"; printf '%s\n%s\n' "$branch" "$pr_text" | grep -oE '\b[A-Z][A-Z0-9]+-[0-9]+\b'; } | awk 'NF && !seen[$0]++')
for k in "${keys[@]}"; do
  out=$(timeout 15 bash "$plugin/scripts/read-item.sh" "$k" </dev/null 2>/dev/null)
  if [ -z "$out" ] || grep -q "^Read $k whole: " <<<"$out"; then unread+=("ticket $k, read it by hand: read-item.sh printed no comments"); continue; fi
  searched+=("ticket $k")
  line=$(grep -E '^[[:space:]>*-]*([0-9]{4}-[0-9]{2}-[0-9]{2}:[[:space:]]*)?\*\*Handoff\*\*' <<<"$out" | tail -n 1)
  [ -n "$line" ] && hit "ticket $k" "${line:0:200}"
done
# Earlier sessions of this repo, its worktrees included, that name the branch or a key.
# The default branch names nearly every session, so only a key matches there.
default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); default=${default#origin/}
terms=() ; case "$branch" in ""|main|master|"$default") ;; *) terms+=(-e "$branch") ;; esac; for k in "${keys[@]}"; do terms+=(-e "$k"); done
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ -n "$common" ] && [ "${#terms[@]}" -gt 0 ]; then
  prefix=$(dirname "$common" | sed 's#[/.]#-#g')
  n=0
  while IFS= read -r f; do
    [ "$(basename "$f" .jsonl)" = "${CLAUDE_CODE_SESSION_ID:-}" ] && continue
    grep -qF "${terms[@]}" "$f" || continue
    n=$((n + 1))
    url=$(grep -F '**Handoff**' "$f" | grep -oE 'https?://[^ ")\\]*' | tail -n 1)
    [ -n "$url" ] && { hit "earlier session $(basename "$f" .jsonl)" "$url"; break; }
    [ "$n" -ge 5 ] && break
  done < <(ls -t "$projects/$prefix"/*.jsonl "$projects/$prefix"--claude-worktrees-*/*.jsonl 2>/dev/null)
  searched+=("$n earlier session transcripts naming ${branch:-the keys}")
else unread+=("earlier sessions, no branch other than the default and no ticket key to match"); fi
list=$(printf '%s; ' "${searched[@]}"); list=${list%; }
if [ "$found" = 0 ]; then printf 'none found in: %s\n' "${list:-nothing}"
else printf 'searched: %s\n' "$list"; fi
for u in "${unread[@]}"; do printf 'not read: %s\n' "$u"; done
