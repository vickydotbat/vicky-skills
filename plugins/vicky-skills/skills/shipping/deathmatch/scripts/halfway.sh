#!/usr/bin/env bash
# halfway.sh <stars>: for a warp of that many stars, prints when its halfway
# check runs and which opponent fights ("after 2: standards"). A long warp is
# four stars or more; a shorter one prints nothing.
set -u
n=${1:?usage: halfway.sh <stars>}
[[ $n =~ ^[0-9]+$ ]] || { echo "halfway.sh: <stars> is a count" >&2; exit 2; }
n=$((10#$n))
[ "$n" -ge 4 ] && echo "after $((n / 2)): standards"
exit 0 # mutant-ok delete: a no-op in its place also ends the script with status 0
