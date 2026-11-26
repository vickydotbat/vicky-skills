#!/usr/bin/env bash
# over-to-you's one way to make and remove kits. Each kit file or folder is
# recorded before it is written, so clean removes only what the session made.
# Usage:
#   kit.sh add <path>...   record each kit path, before you write it
#   kit.sh clean           remove every recorded path, unless git tracks it
#   kit.sh left            print each recorded path still in place
# The record is over-to-you-kits in the session folder,
# ${TMPDIR:-/tmp}/$CLAUDE_CODE_SESSION_ID: one "<epoch><tab><absolute path>" per
# line. add refuses a path that already exists, unless a recorded folder holds
# it, so a file the session did not make is never on the record. clean removes
# a recorded folder file by file, then folder by folder: nothing under it
# predates the record. kit-guard holds the end of a turn while a closed
# sitting's kits are still in place.
set -u
usage() { echo "usage: kit.sh add <path>... | clean | left" >&2; exit 2; }
[ $# -ge 1 ] || usage
[ -n "${CLAUDE_CODE_SESSION_ID:-}" ] || { echo "kit.sh: CLAUDE_CODE_SESSION_ID is unset, so there is no session folder for the record" >&2; exit 2; }
dir="${TMPDIR:-/tmp}/$CLAUDE_CODE_SESSION_ID"
rec="$dir/over-to-you-kits"
there() { [ -e "$1" ] || [ -L "$1" ]; }
recorded() { # <path>: 0 when the record holds it, or a recorded folder holds it
  local r
  [ -f "$rec" ] || return 1
  while IFS=$'\t' read -r _ r; do
    case "$1" in "$r" | "$r"/*) return 0 ;; esac
  done <"$rec"
  return 1
}
tracked() { # <path>: 0 when git tracks it, or a file under it
  local d
  d=$(dirname -- "$1"); [ -d "$1" ] && d=$1
  [ -n "$(git -C "$d" ls-files -- "$1" 2>/dev/null)" ]
}
case $1 in
  add)
    shift; [ $# -ge 1 ] || usage
    mkdir -p "$dir" || exit 2
    for p in "$@"; do
      a=$(realpath -m -- "$p")
      if there "$a" && ! recorded "$a"; then
        echo "kit.sh: $a already exists: record a kit path before you write it, so clean never removes a file the session did not make" >&2
        exit 1
      fi
    done
    now=$(date +%s)
    for p in "$@"; do printf '%s\t%s\n' "$now" "$(realpath -m -- "$p")" >>"$rec"; done
    ;;
  clean)
    [ -f "$rec" ] || { echo "kit.sh: no kits recorded"; exit 0; }
    keep=$(mktemp "$dir/.kits.XXXXXX") || exit 2
    removed=0
    # Deepest paths first, so a folder's recorded files go before the folder.
    while IFS=$'\t' read -r t p; do
      there "$p" || continue
      if tracked "$p"; then
        printf '%s\t%s\n' "$t" "$p" >>"$keep"
        echo "kit.sh: git tracks $p, so it stays: commit no kit file. Take it out of the commit, then run clean again" >&2
        continue
      fi
      if [ -d "$p" ] && [ ! -L "$p" ]; then
        find "$p" -depth ! -type d -exec rm -f -- {} +
        find "$p" -depth -type d -exec rmdir -- {} +
      else
        rm -f -- "$p"
      fi
      if there "$p"; then
        printf '%s\t%s\n' "$t" "$p" >>"$keep"
        echo "kit.sh: could not remove $p" >&2
      else
        removed=$((removed + 1))
      fi
    done < <(sort -t$'\t' -k2,2r "$rec")
    mv "$keep" "$rec"
    echo "kit.sh: removed $removed kit paths"
    [ -s "$rec" ] && exit 1
    rm -f "$rec"
    ;;
  left)
    [ -f "$rec" ] || exit 0
    while IFS=$'\t' read -r t p; do
      if there "$p"; then printf '%s\t%s\n' "$t" "$p"; fi
    done <"$rec"
    ;;
  *) usage ;;
esac
exit 0
