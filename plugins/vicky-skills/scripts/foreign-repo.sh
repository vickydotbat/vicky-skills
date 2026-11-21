# shellcheck shell=bash
# Sourced by foreign-post-hint and pr-guard: whether a gh command posts to a
# repository the user does not administer. The target is the -R/--repo value,
# else the checkout's parent when the checkout is a fork, else the checkout's
# own repository. foreign_repo <command> prints the target and returns 0 when
# the user does not administer it, and returns 1 when they do or gh can't say.
foreign_view() { gh repo view ${1:+"$1"} --json viewerPermission,isFork,parent 2>/dev/null; }
foreign_repo() {
  command -v gh >/dev/null || return 1 # mutant-ok delete: without gh the view below fails and returns 1 the same way
  local repo info # mutant-ok delete: the hooks that source this set no repo or info of their own
  repo=$(grep -oE '(-R|--repo)[[:space:]=]+[^[:space:]]+' <<<"$1" | head -1 | sed -E 's/^(-R|--repo)[[:space:]=]+//')
  info=$(foreign_view "$repo") || return 1
  if [ -z "$repo" ] && [ "$(jq -r '.isFork' <<<"$info")" = true ]; then
    repo=$(jq -r '.parent.nameWithOwner // empty' <<<"$info")
    info=$(foreign_view "$repo") || return 1
  fi
  [ "$(jq -r '.viewerPermission // empty' <<<"$info")" = ADMIN ] && return 1
  printf '%s\n' "${repo:-this repository}"
}
