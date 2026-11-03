#!/usr/bin/env bash
# While a draft is open, interpreter code that writes in any common way is
# refused, and code that only reads runs.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/draft-lock.sh"
dir=$(mktemp -d)
tail -f /dev/null & editor=$!
trap 'kill "$editor"; rm -rf "$dir"' EXIT
git init -q "$dir/repo"
printf '%s\ndrafts.md\npage\n' "$editor" > "$(git -C "$dir/repo" rev-parse --absolute-git-dir)/red-pen-open"
fail=0
run() { jq -n --arg c "$1" --arg d "$dir/repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | CLAUDE_PLUGIN_OPTION_GUARD_DRAFT_LOCK=true bash "$hook" >/dev/null 2>&1; echo $?; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
for code in 'import pathlib; pathlib.Path("a").write_text("x")' 'import os; os.replace("a", "b")' 'import os; os.chmod("a", 0o600)' 'import shutil; shutil.copy("a", "b")'; do
  check "refused: $code" 2 "$(run "python3 -c '$code'")"
done
check "a read runs" 0 "$(run "python3 -c 'print(open(\"a\").read())'")"
exit $fail
