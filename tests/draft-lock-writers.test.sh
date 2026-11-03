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
# A variable the command sets to an absolute path names where its redirect writes.
check "a redirect into a folder the command names in a variable runs" 0 "$(run 'S=/tmp/scratch-x; ls > $S/out.txt')"
check "a braced variable names its folder too" 0 "$(run 'S=/tmp/scratch-x; ls > ${S}/out.txt')"
check "a loop's redirect into the variable's folder runs" 0 "$(run 'S=/tmp/scratch-x; for k in a b; do bin/show $k > $S/$k.txt 2>&1; done')"
check "a variable set inside quotes names its folder" 0 "$(run "S='/tmp/scratch-x'; ls > \$S/out.txt")"
check "a variable set to a relative path is refused" 2 "$(run 'S=sub; ls > $S/out.txt')"
check "a variable the command never sets is refused" 2 "$(run 'ls > $S/out.txt')"
check "a longer name that starts with the variable's is refused" 2 "$(run 'S=/tmp/scratch-x; ls > $SX/out.txt')"
check "a variable set to the checkout itself is refused" 2 "$(run "S=$dir/repo; ls > \$S/out.txt")"
exit $fail
