# shellcheck shell=bash
# Sourced by auto-tidy and fork-sweep.
#
# url_parts <url> prints "<host> <owner/name>" for an https, ssh or scp-style
# URL, and nothing for any other form.
url_parts() {
  local u=$1 h p
  case "$u" in
    http://* | https://*) u=${u#*://}; u=${u#*@}; h=${u%%/*}; p=${u#*/} ;;
    ssh://*) u=${u#ssh://}; u=${u#*@}; h=${u%%/*}; h=${h%%:*}; p=${u#*/} ;;
    *@*:*) u=${u#*@}; h=${u%%:*}; p=${u#*:} ;;
    *) return 0 ;;
  esac
  p=${p%/}
  printf '%s %s' "$h" "${p%.git}"
}
# tea_login <host> prints the name of the tea login on that host, if any.
tea_login() {
  timeout 10 tea logins list -o json </dev/null 2>/dev/null \
    | jq -r --arg h "$1" '.[] | select((.url | sub("^https?://"; "") | sub("[/:].*$"; "")) == $h or .ssh_host == $h) | .name' 2>/dev/null | head -1
}
# forge_of <url> prints "<forge> <login> <owner/name>": "gh -" for github.com,
# "tea <login>" for a host a tea login names, and nothing for any other.
forge_of() {
  local h p l # mutant-ok delete: callers read forge_of through $(...), so its names never leak
  read -r h p <<<"$(url_parts "$1")"
  if [ "$h" = github.com ]; then printf 'gh - %s' "$p"
  elif l=$(tea_login "$h") && [ -n "$l" ]; then printf 'tea %s %s' "$l" "$p"
  fi
}
# tea_pulls <owner/name> [login] prints the repo's pull requests, newest first, as
# "<branch> <OPEN|MERGED|CLOSED> <head sha>", reading Gitea's pages of 50 up to 10
# pages. It fails when the first page does.
tea_pulls() {
  local pg page l=() # mutant-ok delete: callers read tea_pulls through $(...), so its names never leak
  [ -n "${2:-}" ] && l=(-l "$2")
  for pg in $(seq 10); do
    page=$(timeout 10 tea api "${l[@]}" "repos/$1/pulls?state=all&limit=50&page=$pg" </dev/null 2>/dev/null) || { [ "$pg" -gt 1 ]; return; }
    [ "$(jq length <<<"$page" 2>/dev/null)" -gt 0 ] 2>/dev/null || return 0 # mutant-ok delete: past the last page each page is empty, so the loop only takes longer
    jq -r '.[] | "\(.head.ref) \(if .merged then "MERGED" elif .state == "open" then "OPEN" else "CLOSED" end) \(.head.sha)"' <<<"$page" 2>/dev/null
  done
}
# forge_user <forge> <login> prints the signed-in account's name.
forge_user() {
  if [ "$1" = gh ]; then timeout 10 gh api user --jq .login 2>/dev/null
  else timeout 10 tea api -l "$2" user </dev/null 2>/dev/null | jq -r '.login // empty' 2>/dev/null
  fi
}
# repo_owner_parent <forge> <login> <owner/name> prints "<owner> <parent owner/name>".
repo_owner_parent() {
  local info # mutant-ok delete: callers read it through $(...), so info never leaks
  if [ "$1" = gh ]; then
    info=$(timeout 10 gh repo view "$3" --json owner,parent 2>/dev/null) || return 1
    jq -r '"\(.owner.login) \(.parent.owner.login // "")/\(.parent.name // "")"' <<<"$info" 2>/dev/null
  else
    info=$(timeout 10 tea api -l "$2" "repos/$3" </dev/null 2>/dev/null) || return 1
    jq -r '"\(.owner.login) \(.parent.full_name // "")"' <<<"$info" 2>/dev/null
  fi
}
# drop_runs <forge> <login> <owner/name> <branch> deletes the branch's workflow runs.
drop_runs() {
  local id # mutant-ok delete: no caller reads id after drop_runs
  if [ "$1" = gh ]; then
    for id in $(timeout 10 gh run list -R "$3" --branch "$4" --limit 100 --json databaseId 2>/dev/null | jq -r '.[].databaseId' 2>/dev/null); do
      timeout 10 gh run delete "$id" -R "$3" >/dev/null 2>&1
    done
  else
    for id in $(timeout 10 tea api -l "$2" "repos/$3/actions/runs?branch=$4&limit=50" </dev/null 2>/dev/null | jq -r '.workflow_runs[]?.id' 2>/dev/null); do
      timeout 10 tea api -l "$2" -X DELETE "repos/$3/actions/runs/$id" </dev/null >/dev/null 2>&1
    done
  fi
}
# fork_tidy <push target> <forge> <login> <fork slug> <ref prefix> <base ref> <fork default>
# deletes each fork branch under the ref prefix whose pull request to the
# parent merged at that very commit, with its workflow runs, and keeps every
# other. A kept branch with commits the base lacks goes in fork_unmerged. The
# caller defines pr <branch> <field> over the parent's pull requests.
fork_tidy() {
  local dest=$1 forge=$2 login=$3 slug=$4 prefix=$5 base=$6 fdefault=$7 ref sha b
  fork_gone=() fork_unmerged=()
  while read -r ref sha; do
    b=${ref#"$prefix"}
    { [ "$b" = HEAD ] || [ "$b" = "$fdefault" ]; } && continue
    if [ "$(pr "$b" 2)" = MERGED ] && [ "$(pr "$b" 3)" = "$sha" ]; then
      GIT_TERMINAL_PROMPT=0 timeout 15 git push -q "$dest" --delete "$b" >/dev/null 2>&1 || continue
      fork_gone+=("$b")
      drop_runs "$forge" "$login" "$slug" "$b"
    elif [ "$(pr "$b" 2)" != OPEN ] && [ -n "$(git rev-list -1 "$base..$sha" 2>/dev/null)" ]; then
      fork_unmerged+=("$b")
    fi
  done < <(git for-each-ref --format='%(refname) %(objectname)' "$prefix")
}
# unmerged_note <delete command>: names up to three unmerged branches, or counts more.
unmerged_note() {
  local n=${#fork_unmerged[@]} list
  [ "$n" -gt 0 ] || return 0
  if [ "$n" -le 3 ]; then
    list=$(printf '%s, ' "${fork_unmerged[@]}")
    printf 'Kept unmerged: %s. Delete one with %s <branch>.' "${list%, }" "$1"
  else
    printf '%s unmerged branches kept. Delete one with %s <branch>.' "$n" "$1"
  fi
}
