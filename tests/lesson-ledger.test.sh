#!/usr/bin/env bash
# lesson-ledger.sh's edges: usage errors, a missing data folder, a snag with a
# tab or newline, and its exit codes.
set -u
ledger="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/lesson-ledger.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
expect() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'"; fail=1; fi; }
code() { CLAUDE_PLUGIN_DATA="$dir/data" bash "$ledger" "$@" >/dev/null 2>&1; echo $?; }
expect "no data folder set is an error" 2 "$(CLAUDE_PLUGIN_DATA= bash "$ledger" since 2026 >/dev/null 2>&1; echo $?)"
expect "add without a snag is a usage error" 2 "$(code add plugin)"
expect "since without a time is a usage error" 2 "$(code since)"
expect "an unknown verb is a usage error" 2 "$(code list)"
expect "add makes the data folder and exits 0" 0 "$(code add repo "$(printf 'a tab\there\nand a newline')")"
expect "a tab or newline in the snag keeps one line of three columns" "3 1" "$(awk -F '\t' '{print NF, NR}' "$dir/data/lessons.tsv")"
expect "since exits 0" 0 "$(code since 2000-01-01T00:00:00Z)"
expect "since with no ledger prints nothing and exits 0" "0 " "$(CLAUDE_PLUGIN_DATA="$dir/none" bash "$ledger" since 2000 2>&1; echo "$? ")"
exit $fail
