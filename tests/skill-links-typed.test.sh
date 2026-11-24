#!/usr/bin/env bash
# L3, a plain regression test since it already held: a line that asks the
# user to type a typed-only skill passes the skill links check.
# shellcheck disable=SC2016
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/s/g/t" "$dir/s/g/caller"
printf -- '---\nname: t\ndescription: x. Use when asked.\ndisable-model-invocation: true\n---\n1. Work.\n' >"$dir/s/g/t/SKILL.md"
printf -- '---\nname: caller\ndescription: y. Use when z.\n---\n1. Ask the user to type `t`.\n' >"$dir/s/g/caller/SKILL.md"
if bash "$root/tests/skill-links.test.sh" "$dir/s" >/dev/null 2>&1; then echo "ok   L3"; else echo "FAIL L3"; exit 1; fi
