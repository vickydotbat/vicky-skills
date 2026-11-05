#!/usr/bin/env bash
# Runs every test script in this folder and exits 1 when any fails, so a
# single command covers what CI runs step by step.
set -u
fail=0
for t in "$(dirname "$0")"/*.test.sh; do
  "$t" || { echo "FAIL $t"; fail=1; } # run as CI does, so a script without its execute bit fails here too
done
exit $fail
