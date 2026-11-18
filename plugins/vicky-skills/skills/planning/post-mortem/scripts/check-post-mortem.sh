#!/usr/bin/env bash
# Checks post-mortems against the shape in SKILL.md beside this folder. Prints
# one line per problem, exits 1 on any. A repo whose agent docs read
# "Post-mortems: off" is skipped.
set -u
[ $# -gt 0 ] || { echo "usage: check-post-mortem.sh <post-mortem>..." >&2; exit 2; }
date='[0-9]{4}-[0-9]{2}-[0-9]{2}'
# shortcut: any KEY-123 counts as a ticket key, so UTF-8 passes too; tighten when a repo names its ticket prefixes.
link='[A-Z][A-Z0-9]*-[0-9]+|#[0-9]+|\[\[[^]]+\]\]|\[[^]]+\]\([^)]+\)|https?://'
fail=0
for f in "$@"; do
  [ -r "$f" ] || { echo "$f: cannot read"; fail=1; continue; }
  root=$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null)
  [ -n "$root" ] && grep -qsx 'Post-mortems: off' "$root"/docs/agents/*.md && continue
  section() { awk -v h="## $1" '$0 == h {s=1; next} /^## /{s=0} s' "$f"; }
  for h in Impact Timeline Detection Causes 'Earlier incidents' Lessons Follow-ups; do
    grep -qx "## $h" "$f" || { echo "$f: no ## $h section"; fail=1; }
  done
  while IFS= read -r line; do
    [[ "$line" =~ ^-\ $date ]] || { echo "$f: a Timeline line has no date: $line"; fail=1; }
  done < <(section Timeline | grep .)
  if section 'Earlier incidents' | grep -q 'None found' && ! section 'Earlier incidents' | grep -qE 'None found: .*search'; then
    echo "$f: Earlier incidents says None found but names no search: write None found: searched <where> for <words>."; fail=1
  fi
  while IFS= read -r line; do
    [[ "$line" =~ $link ]] || { echo "$f: a follow-up links nothing: $line"; fail=1; }
  done < <(section Follow-ups | grep .)
done
exit $fail
