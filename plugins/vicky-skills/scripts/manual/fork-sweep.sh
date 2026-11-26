#!/usr/bin/env bash
# fork-sweep: run by hand, never as a hook. For each of your forks, on GitHub
# through gh and on each Gitea host tea is signed in to, it deletes each branch
# whose pull request to the parent merged at that very commit, with its
# workflow runs, and fast-forwards the fork's default branch to the parent's
# when it holds nothing the parent lacks. Every other branch stays. One line
# per fork says what went and what stayed. Needs jq, and gh or tea signed in.
set -u
# shellcheck source=../fork-tidy.sh
. "$(dirname "$0")/../fork-tidy.sh"
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
pr() { awk -v b="$1" -v f="$2" '$1 == b { print $f; exit }' <<<"$prs"; }
head_of() { GIT_TERMINAL_PROMPT=0 timeout 15 git ls-remote --symref "$1" HEAD 2>/dev/null | sed -n 's#^ref: refs/heads/\(.*\)\tHEAD$#\1#p'; }
# parent_prs <forge> <login> <parent>: its pull requests as <branch> <state> <head sha>.
parent_prs() {
  local out # mutant-ok delete: callers read parent_prs through $(...), so out never leaks
  if [ "$1" = gh ]; then
    out=$(timeout 20 gh pr list -R "$3" --state all --limit 500 --json headRefName,state,headRefOid 2>/dev/null) || return 1
    jq -r '.[] | "\(.headRefName) \(.state) \(.headRefOid)"' <<<"$out"
  else
    tea_pulls "$3" "$2"
  fi
}
# Every fork, one per line: <forge> <login> <fork> <parent> <fork url> <parent url>.
forks=$(
  timeout 30 gh repo list --fork --limit 1000 --json nameWithOwner,parent 2>/dev/null \
    | jq -r '.[] | "gh - \(.nameWithOwner) \(.parent.owner.login)/\(.parent.name) https://github.com/\(.nameWithOwner).git https://github.com/\(.parent.owner.login)/\(.parent.name).git"' 2>/dev/null
  for l in $(timeout 10 tea logins list -o json </dev/null 2>/dev/null | jq -r '.[].name' 2>/dev/null); do
    for page in $(seq 20); do
      got=$(timeout 20 tea api -l "$l" "user/repos?limit=50&page=$page" </dev/null 2>/dev/null \
        | jq -r --arg l "$l" '.[] | select(.fork and .parent != null) | "tea \($l) \(.full_name) \(.parent.full_name) \(.clone_url) \(.parent.clone_url)"' 2>/dev/null)
      [ -n "$got" ] || break # mutant-ok delete: past the last page each page is empty, so the loop only takes longer
      echo "$got"
    done
  done
)
[ -n "$forks" ] || { echo "fork-sweep: found no forks of yours, or could not list them."; exit 1; }
while read -r forge login fork parent furl purl; do
  g="$work/${forge}_${fork//\//_}"
  git init -q --bare "$g" || continue # mutant-ok delete: the cd on the next line fails on a folder that is not there and skips the fork the same way
  cd "$g" || continue
  prs="" pdef=$(head_of "$purl") fdef=$(head_of "$furl")
  if [ -z "$pdef" ] || [ -z "$fdef" ] \
    || ! GIT_TERMINAL_PROMPT=0 timeout 120 git fetch -q "$purl" "+refs/heads/$pdef:refs/p/$pdef" 2>/dev/null \
    || ! GIT_TERMINAL_PROMPT=0 timeout 120 git fetch -q "$furl" '+refs/heads/*:refs/f/*' 2>/dev/null \
    || ! prs=$(parent_prs "$forge" "$login" "$parent"); then
    echo "$fork: could not compare with $parent, so every branch stays."
    continue # mutant-ok delete: with nothing read, prs is empty and no base ref exists, so nothing is deleted or pushed
  fi
  fork_tidy "$furl" "$forge" "$login" "$fork" "refs/f/" "refs/p/$pdef" "$fdef"
  line="$fork:"
  if [ ${#fork_gone[@]} -gt 0 ]; then gone=$(printf '%s, ' "${fork_gone[@]}"); line+=" Gone: ${gone%, }."; fi
  n=$(unmerged_note "git push $furl --delete")
  [ -n "$n" ] && line+=" $n"
  fsha=$(git rev-parse "refs/f/$fdef") psha=$(git rev-parse "refs/p/$pdef")
  if [ "$fsha" != "$psha" ]; then
    if ! git merge-base --is-ancestor "$fsha" "$psha"; then line+=" $fdef has commits $parent lacks, so it stays."
    elif GIT_TERMINAL_PROMPT=0 timeout 30 git push -q "$furl" "$psha:refs/heads/$fdef" 2>/dev/null; then line+=" $fdef caught up with $parent."
    else line+=" $fdef could not be brought up to $parent."
    fi
  fi
  [ "$line" = "$fork:" ] && line+=" nothing to tidy."
  echo "$line"
done <<<"$forks"
