#!/usr/bin/env bash
# The mutation tool's test map names each script once. Python keeps the last
# of two equal keys without a word, so a second line for a script silently
# drops the tests the first one listed.
# Usage: mutate-hooks-map.test.sh [<mutate-hooks.py>]
set -u
map=${1:-"$(dirname "$0")/mutate-hooks.py"}
dupes=$(awk '/^TESTS = \{$/ {on=1; next} on && /^\}/ {exit} on' "$map" | grep -oE '^    "[^"]+":' | sort | uniq -d)
if [ -z "$dupes" ]; then echo "ok   each script appears once in the mutation test map"; exit 0; fi
echo "FAIL the mutation test map names a script twice: $dupes"; exit 1
