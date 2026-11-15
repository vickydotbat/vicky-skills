#!/usr/bin/env bash
# review-brief-guard refuses a reviewer brief that names a missing file outside a checkout.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/review-brief-guard.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
printf 'law\n' >"$tmp/law.md"
fail=0
code() { jq -nc --arg t "$1" --arg p "$2" '{tool_input:{subagent_type:$t,prompt:$p}}' | bash "$guard" >/dev/null 2>&1; echo $?; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $3, want $2"; fail=1; fi; }
check "a reviewer brief naming a missing scratch file is refused" 2 "$(code vicky-skills:standards-reviewer "Read the law file $tmp/gone/law.md first.")"
check "a missing file in an existing scratch folder is refused" 2 "$(code spec-reviewer "Law: $tmp/other.md.")"
check "a reviewer brief naming a file that exists passes" 0 "$(code vicky-skills:simplicity-reviewer "Law file: $tmp/law.md")"
check "a missing file inside a checkout passes, since the diff may delete it" 0 "$(code standards-reviewer "Checkout $root, see $root/no-such-file.md")"
check "a missing file in a brief to another agent passes" 0 "$(code general-purpose "Write your notes to $tmp/gone/out.md")"
check "a brief with no path passes" 0 "$(code standards-reviewer "Review since origin/main.")"
check "a relative path passes" 0 "$(code standards-reviewer "Read docs/missing.md")"
check "a URL path passes" 0 "$(code standards-reviewer "See https://example.com/a/b.html")"
check "bad input passes" 0 "$(echo nope | bash "$guard" >/dev/null 2>&1; echo $?)"
if [ "$(code standards-reviewer "Read $tmp/x/a.md")" = 2 ]; then
  msg=$(jq -nc --arg p "Read $tmp/x/a.md" '{tool_input:{subagent_type:"standards-reviewer",prompt:$p}}' | bash "$guard" 2>&1 >/dev/null)
  case $msg in *"$tmp/x/a.md"*realpath*) echo "ok   the refusal names the path and the realpath steer";; *) echo "FAIL refusal text: $msg"; fail=1;; esac
fi
exit $fail
