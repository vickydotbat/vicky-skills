#!/usr/bin/env bash
# sealed-check.sh: Holds and Simplicity write in the sealed copy by design, so it is checked against git after each report.
#
#   snapshot <worktree>     prints the effort worktree's state before the fight
#   check <sealed copy> <pinned sha> [<worktree> <snapshot file>]
#   reset <sealed copy> <pinned sha>
#   baseline <sealed copy>  prints the copy's git state after the warm build, for SEALED_GIT_BASELINE
#   copy <sealed copy> <angle>   makes <sealed copy>-<angle> once and prints its path;
#                                a second call reuses it, so a rerun never nests a clone, and refuses one that is half-made, dirty or tampered with
#
# check exits 0 with "sealed: as pinned", or 1 with one line per change and the
# step to take. Files git ignores (build output) never count, nor git state the
# file SEALED_GIT_BASELINE names: a dev shell that sets a hook path or installs
# hooks in every clone did that before any opponent fought. A usage error
# exits 2 and says nothing about the copy.
set -u
usage() {
  echo "usage: sealed-check.sh snapshot <worktree> | baseline <sealed copy> | check <sealed copy> <pinned sha> [<worktree> <snapshot file>] | reset <sealed copy> <pinned sha> | copy <sealed copy> <angle>" >&2
  exit 2
}
# The path is the top of a git checkout, not a folder somewhere inside one.
checkout() {
  # An empty path makes git -C read the current folder, so it never counts.
  [ -n "${1:-}" ] || return 1 # mutant-ok delete: bash refuses cd "" here too, and this keeps a shell that allows it from reading the current folder
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) && [ "$top" = "$(cd "$1" && pwd -P)" ]
}
# Index marks that hide a file's edit from git diff, and git state that makes step 5's git
# commands run a program: a hook, or a local setting that names a command.
hidden() { git -C "$1" ls-files -v | grep -E '^([a-z]|S) '; }
# git_keys prints each item as "<line to report><tab><key>": the key holds the
# setting's value or the hook's hash, so a baseline item changed later counts again.
git_keys() {
  local name hook # mutant-ok delete: the names only stay local, and no caller reads them
  git -C "$1" config --local --name-only --list |
    grep -E '^(core\.(hookspath|fsmonitor|sshcommand|pager|editor|askpass|gitproxy|attributesfile)|sequence\.editor|(alias|include|includeif|filter|pager|credential)\..*|diff\.(external|.*\.(textconv|command))|merge\..*\.driver|gpg\..*program|uploadpack\.packobjectshook)$' |
    while IFS= read -r name; do printf 'git: %s\t%s=%s\n' "$name" "$name" "$(git -C "$1" config --local --get-all "$name" | sha256sum | cut -c1-16)"; done
  find "$(git -C "$1" rev-parse --absolute-git-dir)/hooks" -type f ! -name '*.sample' 2>/dev/null |
    while IFS= read -r hook; do printf 'git: hook %s\thook %s=%s\n' "${hook##*/}" "${hook##*/}" "$(sha256sum < "$hook" | cut -c1-16)"; done
}
git_state() {
  local base=${SEALED_GIT_BASELINE:-/dev/null}
  git_keys "$1" | awk -F '\t' -v base="$base" 'BEGIN { while ((getline line < base) > 0) seen[line] = 1 } !($2 in seen) { print $1 }' # mutant-ok: reading seen[line] in awk creates it, so a compare stores the key too
}
commit() { git -C "$1" rev-parse --verify -q "${2}^{commit}"; }
# Untracked files git doesn't ignore, by name.
new_files() { git -C "$1" ls-files -o --exclude-standard; }
state() {
  git -C "$1" rev-parse HEAD
  git -C "$1" status --porcelain=v1 -uall
  { git -C "$1" diff HEAD; new_files "$1" | (cd "$1" && git hash-object --stdin-paths); } | sha256sum
}

mode=${1:-}
case "$mode" in
snapshot)
  checkout "${2:-}" || usage
  state "$2"
  ;;
check)
  copy=${2:-} pin=${3:-}
  checkout "$copy" || usage
  pin=$(commit "$copy" "$pin") || usage
  worktree=${4:-} snap=${5:-}
  if [ -n "$worktree" ]; then checkout "$worktree" && [ -f "$snap" ] || usage; fi
  dirty=0
  head=$(git -C "$copy" rev-parse HEAD)
  if [ "$head" != "$pin" ]; then
    echo "moved: the sealed copy is at ${head:0:12}, no longer at the pinned commit ${pin:0:12}"
    dirty=1
  fi
  while IFS= read -r line; do echo "changed: $line"; dirty=1; done < <(git -C "$copy" diff --name-status "$pin")
  while IFS= read -r line; do echo "new: $line"; dirty=1; done < <(new_files "$copy")
  while IFS= read -r line; do echo "hidden: $line"; dirty=1; done < <(hidden "$copy")
  while IFS= read -r line; do echo "$line"; dirty=1; done < <(git_state "$copy")
  if [ -n "$worktree" ] && [ "$(state "$worktree")" != "$(cat "$snap")" ]; then
    was=$(head -n1 "$snap")
    now=$(git -C "$worktree" rev-parse HEAD)
    [ "$was" = "$now" ] || echo "worktree: its branch moved from ${was:0:12} to ${now:0:12}"
    git -C "$worktree" status --porcelain=v1 -uall | sed 's/^/worktree: /'
    dirty=1
  fi
  if [ "$dirty" = 1 ]; then
    echo "discard this opponent's findings, run sealed-check.sh reset on the copy, and send the opponent once more"
    exit 1
  fi
  echo "sealed: as pinned"
  ;;
reset)
  copy=${2:-} pin=${3:-}
  checkout "$copy" || usage
  pin=$(commit "$copy" "$pin") || usage
  # A reset throws work away, so it touches only a copy in the temp folder, or
  # under the sealed_copy_root setting, where deathmatch step 3 makes it, never
  # a checkout the user works in.
  tmp=$(cd "${TMPDIR:-/tmp}" && pwd -P)
  own=$(cd "${CLAUDE_PLUGIN_OPTION_SEALED_COPY_ROOT:-$tmp}" 2>/dev/null && pwd -P) || own=$tmp
  where=$(cd "$copy" && pwd -P)
  case "$where" in
  "$tmp"/* | "$own"/*) ;;
  *) echo "refused: reset only touches a sealed copy under $tmp or the sealed_copy_root setting" >&2; exit 2 ;;
  esac
  git -C "$copy" ls-files -z | git -C "$copy" update-index -z --no-assume-unchanged --no-skip-worktree --stdin
  git -C "$copy" reset -q --hard "$pin" && git -C "$copy" clean -fdq
  ;;
copy)
  copy=${2:-} angle=${3:-}
  checkout "$copy" && [ -n "$angle" ] && [ "${angle#*/}" = "$angle" ] && [ "$angle" != .. ] || usage
  to="${copy%/}-$angle"
  # cp -a into a folder that exists copies inside it: a rerun nested clones once.
  # The copy lands under a part name and moves in whole, so a folder at $to
  # that is not a checkout of the same commit is a broken copy, never reused.
  [ -e "$to" ] || { rm -rf "$to.part" && cp -a --reflink=auto "$copy" "$to.part" && mv "$to.part" "$to"; }
  # A reused copy may hold a cut-off opponent's edits, hooks or hidden marks: it is
  # handed on clean or not at all. The git state is read before any git command that
  # would run a program it names, and a link would hand on the sealed copy itself.
  [ ! -L "$to" ] && checkout "$to" && [ -z "$(git_state "$to")" ] && [ -z "$(hidden "$to")" ] &&
    [ "$(git -C "$to" rev-parse HEAD)" = "$(git -C "$copy" rev-parse HEAD)" ] &&
    [ -z "$(git -C "$to" status --porcelain)" ] || {
    echo "unclean: $to is not a clean copy at the sealed copy's commit; run sealed-check.sh reset on it, or delete it, and run copy again" >&2; exit 1; }
  echo "$to"
  ;;
baseline)
  checkout "${2:-}" || usage
  git_keys "$2" | cut -f2
  ;;
*) usage ;;
esac
