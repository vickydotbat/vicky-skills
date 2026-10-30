#!/usr/bin/env bash
# The agent picks a skill by its description, so every skill it can start names
# its trigger with "Use when", "Use whenever" or "Use before". A skill only a
# person starts (disable-model-invocation: true) is marked "(typed only)" in the
# README, so a reader knows to type it.
# Usage: skill-descriptions.test.sh [skills dir] [README]
set -u
here="$(dirname "$0")/.."
root="${1:-$here/plugins/vicky-skills/skills}"
readme="${2:-$here/README.md}"
fail=0
for f in "$root"/*/*/SKILL.md; do
  name=$(basename "$(dirname "$f")")
  fm=$(awk '/^---$/{n++; next} n==1' "$f")
  if grep -q '^disable-model-invocation: true' <<<"$fm"; then
    grep -E "^- \*\*\`$name\`\*\*.*\(typed only\)" "$readme" >/dev/null \
      || { echo "FAIL $name is typed-only but the README does not mark it (typed only)"; fail=1; }
  else
    grep '^description:' <<<"$fm" | grep -Eq 'Use (only )?(when|whenever|before)' \
      || { echo "FAIL $name has no \"Use when\", \"Use whenever\" or \"Use before\" in its description"; fail=1; }
  fi
done
[ $fail = 0 ] && echo "ok   descriptions and README marks"
exit $fail
