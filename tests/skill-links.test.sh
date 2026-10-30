#!/usr/bin/env bash
# A skill the agent can start must not tell the agent to start a typed-only
# skill (one with disable-model-invocation: true): the agent cannot, so the
# line has to ask the user to type it. A line passes when it says the user
# types, runs or is told the skill.
# Usage: skill-links.test.sh [skills dir]
set -u
root="${1:-$(dirname "$0")/../plugins/vicky-skills/skills}"
fm() { awk '/^---$/{n++; next} n==1' "$1"; }
typed=()
for f in "$root"/*/*/SKILL.md; do
  fm "$f" | grep -q '^disable-model-invocation: true' && typed+=("$(basename "$(dirname "$f")")")
done
fail=0
for f in "$root"/*/*/SKILL.md; do
  fm "$f" | grep -q '^disable-model-invocation: true' && continue
  for name in "${typed[@]}"; do
    # body lines only, past the closing frontmatter fence
    hits=$(awk '/^---$/{n++; next} n>=2' "$f" | grep -nE "\`/?$name\`" || true)
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      echo "$line" | grep -Eiq '\b(call|run|start|invoke|use|load|hand)\b' || continue
      echo "$line" | grep -Eiq '\b(type|types|typed)\b|user (to )?run|tell the user|ask the user' && continue
      echo "FAIL $(basename "$(dirname "$f")") starts typed-only $name: ${line:0:110}"; fail=1
    done <<<"$hits"
  done
done
[ $fail = 0 ] && echo "ok   no startable skill starts a typed-only one"
exit $fail
