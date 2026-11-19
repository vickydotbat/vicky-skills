#!/usr/bin/env bash
# batch.sh <opponents>: how many opponents fight at once and the memory cap
# each one's commands get. Each cap is 2G at most, and the caps of every
# opponent running fit in half the memory free now, since other sessions and
# the desktop share it. Three run at once at most, one at least: with less
# free, the opponents fight in more rounds. BATCH_MEMINFO names a meminfo file
# in place of /proc/meminfo, for tests. A cap under 1G gets a warning line.
set -u
n=${1:?usage: batch.sh <opponents>}
[[ $n =~ ^[0-9]+$ ]] && [ $((10#$n)) -ge 1 ] || { echo "batch.sh: <opponents> is a count of one or more" >&2; exit 2; }
n=$((10#$n))
budget=$(( $(awk '/^MemAvailable:/ {print $2 * 1024}' "${BATCH_MEMINFO:-/proc/meminfo}") / 2 ))
ceiling=$(( 2 * 1024 * 1024 * 1024 ))
at=$(( budget / ceiling ))
[ "$at" -gt 3 ] && at=3
[ "$at" -gt "$n" ] && at=$n
[ "$at" -lt 1 ] && at=1
cap=$(( budget / at ))
[ "$cap" -gt "$ceiling" ] && cap=$ceiling
echo "at once: $at"
echo "memory cap: $(numfmt --to=iec --round=down "$cap")"
if [ "$cap" -lt $(( 1024 * 1024 * 1024 )) ]; then
  echo "warning: the memory cap is under 1G, so a memory cap finding on this machine is unproven"
fi
