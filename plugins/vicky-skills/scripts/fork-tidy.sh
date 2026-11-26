# shellcheck shell=bash
# Sourced by auto-tidy and fork-sweep.
#
# gh_slug <url> prints owner/name for a github.com URL, and nothing for any
# other host. shortcut: GitHub only, until a Gitea fork has a way to name its parent.
gh_slug() {
  local u=$1
  case "$u" in
    https://github.com/*) u=${u#https://github.com/} ;;
    git@github.com:*) u=${u#git@github.com:} ;;
    ssh://git@github.com/*) u=${u#ssh://git@github.com/} ;;
    *) return 0 ;;
  esac
  u=${u%/}
  printf '%s' "${u%.git}"
}
# fork_tidy <push target> <fork slug> <ref prefix> <base ref> <fork default>
# deletes each fork branch under the ref prefix whose pull request to the
# parent merged at that very commit, with its workflow runs, and keeps every
# other. A kept branch with commits the base lacks goes in fork_unmerged. The
# caller defines pr <branch> <field> over the parent's pull requests.
fork_tidy() {
  local dest=$1 slug=$2 prefix=$3 base=$4 fdefault=$5 ref sha b id
  fork_gone=() fork_unmerged=()
  while read -r ref sha; do
    b=${ref#"$prefix"}
    { [ "$b" = HEAD ] || [ "$b" = "$fdefault" ]; } && continue
    if [ "$(pr "$b" 2)" = MERGED ] && [ "$(pr "$b" 3)" = "$sha" ]; then
      GIT_TERMINAL_PROMPT=0 timeout 15 git push -q "$dest" --delete "$b" >/dev/null 2>&1 || continue
      fork_gone+=("$b")
      for id in $(timeout 10 gh run list -R "$slug" --branch "$b" --limit 100 --json databaseId 2>/dev/null | jq -r '.[].databaseId' 2>/dev/null); do
        timeout 10 gh run delete "$id" -R "$slug" >/dev/null 2>&1
      done
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
