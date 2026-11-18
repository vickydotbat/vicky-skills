#!/usr/bin/env bash
# batch.sh <opponents>: how many opponents fight at once (three at most) and
# the memory cap each one's commands get, so that the caps of every opponent
# running fit in four fifths of the memory free now.
set -u
n=${1:?usage: batch.sh <opponents>}
[[ $n =~ ^[0-9]+$ ]] && [ $((10#$n)) -ge 1 ] || { echo "batch.sh: <opponents> is a count of one or more" >&2; exit 2; }
n=$((10#$n))
at=$(( n < 3 ? n : 3 ))
free=$(awk '/^MemAvailable:/ {print $2 * 1024}' /proc/meminfo)
echo "at once: $at"
echo "memory cap: $(numfmt --to=iec --round=down $(( free * 4 / 5 / at )))"
