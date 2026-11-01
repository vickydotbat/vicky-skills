#!/usr/bin/env bash
# approved-spec: the examples approved for S2 (F6). While a draft is open,
# draft-lock lets reads and scratch writes run and still refuses edits.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/draft-lock.sh"
dir=$(mktemp -d)
tail -f /dev/null & editor=$!
trap 'kill "$editor"; rm -rf "$dir"' EXIT
mkdir -p "$dir/repo/tests" "$dir/scratch"
git init -q "$dir/repo"
printf '%s\nthe page\n' "$editor" > "$(git -C "$dir/repo" rev-parse --absolute-git-dir)/red-pen-open"
fail=0
run() { jq -n --arg c "$1" --arg d "$dir/repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | CLAUDE_PLUGIN_OPTION_GUARD_DRAFT_LOCK=true bash "$hook" 2>/dev/null; echo $?; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }

# Given a draft open on a page for this checkout
# When a command searches for a > sign inside quotes, as grep or awk do
# Then the command runs
check "grep for a quoted > runs" 0 "$(run "grep -c 'a>b' README.md")"
check "awk with a quoted > runs" 0 "$(run "awk '\$1 > 0' data.txt")"

# Given a draft open on a page for this checkout
# When a command reads a file in the checkout and writes its output to the scratch folder
# Then the command runs
check "a read into scratch runs" 0 "$(run "cat $dir/repo/README.md > $dir/scratch/out")"

# Given a draft open on a page for this checkout
# When a command runs a Python script in the checkout that only reads
# Then the command runs
check "a Python script run by path runs" 0 "$(run "python3 tests/check.py --check")"

# Given a draft open on a page for this checkout
# When a command edits a file in the checkout with sed -i, or writes one with >
# Then draft-lock refuses it
check "sed -i in the checkout is refused" 2 "$(run "sed -i s/a/b/ README.md")"
check "a redirect into the checkout is refused" 2 "$(run "echo hi > README.md")"
exit $fail
