#!/usr/bin/env bash
# approved-spec: H1 to H5, skill hand-offs declared in frontmatter.
# The skill files hold backticks on purpose, so single quotes keep them literal.
# shellcheck disable=SC2016
# ok and no only print, so "cond && ok || no" never runs both.
# shellcheck disable=SC2015
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
check="$root/tests/skill-hand-offs.test.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
# sk <name> <hands-off line or empty> <body>
sk() { mkdir -p "$dir/s/g/$1"; { printf -- '---\nname: %s\ndescription: x. Use when asked.\n' "$1"; [ -n "$2" ] && printf '%s\n' "$2"; printf -- '---\n%s\n' "$3"; } >"$dir/s/g/$1/SKILL.md"; }
fresh() { rm -rf "$dir/s"; sk b '' '1. Work.'; }
run() { out=$(bash "$check" "$dir/s" 2>&1); rc=$?; }
ok() { echo "ok   $1"; }
no() { echo "FAIL $1: rc=$rc out=$out"; fail=1; }

# Given a skill whose step says run `b`, and whose frontmatter lists `hands-off: [b]`
# When the plugin's tests run
# Then they pass
fresh; sk a 'hands-off: [b]' '1. Run `b` on it.'; run
[ -x "$check" ] && [ $rc -eq 0 ] && ok H1 || no H1

# Given a skill whose step says run `b`, and whose frontmatter has no `b` in hands-off
# When the plugin's tests run
# Then they fail, naming the skill and `b`
fresh; sk a 'hands-off: []' '1. Run `b` on it.'; run
[ -x "$check" ] && [ $rc -ne 0 ] && echo "$out" | grep -qw a && echo "$out" | grep -qw b && ok H2 || no H2

# Given a skill whose frontmatter lists `hands-off: [zz]`, and the plugin has no skill `zz`
# When the plugin's tests run
# Then they fail, naming `zz`
fresh; sk a 'hands-off: [zz]' '1. Work.'; run
[ -x "$check" ] && [ $rc -ne 0 ] && echo "$out" | grep -qw zz && ok H3 || no H3

# Given a skill whose frontmatter lists `hands-off: [b]`, and no step of it names `b`
# When the plugin's tests run
# Then they fail, naming the skill and `b`
fresh; sk a 'hands-off: [b]' '1. Work.'; run
[ -x "$check" ] && [ $rc -ne 0 ] && echo "$out" | grep -qw a && echo "$out" | grep -qw b && ok H4 || no H4

# Given a skill author adds a hand-off to a step and to that skill's hands-off field
# When the plugin's tests run
# Then they pass, with no other file changed
fresh; sk a 'hands-off: [b]' '1. Work.'; sk c '' '1. Work.'
sk a 'hands-off: [b, c]' "$(printf '1. Run `b`.\n2. Then run `c`.')"
before=$(find "$dir/s" -type f | sort | xargs sha256sum | grep -v '/a/SKILL.md'); run
after=$(find "$dir/s" -type f | sort | xargs sha256sum | grep -v '/a/SKILL.md')
[ -x "$check" ] && [ $rc -eq 0 ] && [ "$before" = "$after" ] && ok H5 || no H5
exit $fail
