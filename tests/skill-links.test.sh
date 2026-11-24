#!/usr/bin/env bash
# A skill the agent can start must not tell the agent to start a typed-only
# skill (one with disable-model-invocation: true): the agent cannot, so the
# line has to ask the user to type it. A line passes when it says the user
# types, runs or is told the skill.
# Usage: skill-links.test.sh [skills dir]
# The fixtures hold backticks on purpose, so single quotes keep them literal.
# shellcheck disable=SC2016
set -u
# Self-check on a fixture, when run with no skills dir: a step that runs a
# typed-only skill fails, and a line that only mentions one passes.
if [ $# -eq 0 ]; then
  fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
  mkdir -p "$fx/g/finisher" "$fx/g/caller"
  printf -- '---\nname: finisher\ndescription: x. Use when asked.\ndisable-model-invocation: true\n---\nbody\n' > "$fx/g/finisher/SKILL.md"
  printf -- '---\nname: caller\ndescription: y. Use when z.\n---\n1. **Finish.** Run `finisher` on the branch.\n' > "$fx/g/caller/SKILL.md"
  bash "$0" "$fx" >/dev/null && { echo "FAIL a step that runs a typed-only skill passes"; exit 1; }
  printf -- '---\nname: caller\ndescription: y. Use when z.\n---\n1. Run the checks, then leave the rest to `finisher`.\n' > "$fx/g/caller/SKILL.md"
  bash "$0" "$fx" >/dev/null || { echo "FAIL a line that only mentions a typed-only skill fails"; exit 1; }
  printf -- '---\nname: caller\ndescription: y. Use when z.\n---\n1. Settle it with `finisher`'"'"'s SETTLE.md, then write it with `finisher`.\n' > "$fx/g/caller/SKILL.md"
  bash "$0" "$fx" >/dev/null && { echo "FAIL a pointer hides a hand-off on the same line"; exit 1; }
  mkdir -p "$fx/g/other"; printf -- '---\nname: other\ndescription: x. Use when asked.\ndisable-model-invocation: true\n---\nbody\n' > "$fx/g/other/SKILL.md"
  printf -- '---\nname: caller\ndescription: y. Use when z.\n---\n1. Ask the user to type `other`. Then run `finisher`.\n' > "$fx/g/caller/SKILL.md"
  bash "$0" "$fx" >/dev/null && { echo "FAIL one sentence's ask clears a hand-off in the next"; exit 1; }
fi
root="${1:-$(dirname "$0")/../plugins/vicky-skills/skills}"
fm() { awk '/^---$/{n++; next} n==1' "$1"; }
typed=()
for f in "$root"/*/*/SKILL.md; do
  fm "$f" | grep -q '^disable-model-invocation: true' && typed+=("$(basename "$(dirname "$f")")")
done
fail=0
# The skill graph decides which skill hands off to which, as GRAPH.tsv records it.
edges=$(python3 "$(dirname "$0")/../plugins/vicky-skills/scripts/skill-graph.py" list "$root")
for f in "$root"/*/*/SKILL.md; do
  fm "$f" | grep -q '^disable-model-invocation: true' && continue
  skill=$(basename "$(dirname "$f")")
  for name in "${typed[@]}"; do
    printf '%s\n' "$edges" | grep -qxF "$skill	$name" || continue
    # body lines of every file of the skill, past any frontmatter
    # one sentence per line, so an ask in one sentence clears only that sentence
    hits=$(for g in "$(dirname "$f")"/*.md; do awk 'NR==1&&/^---$/{fm=1;next} fm&&/^---$/{fm=0;next} !fm' "$g"; done | sed -E 's/([.;:!?]) +/\1\n/g' | grep -nE "\`/?$name\`" | sed -E "s/\`\/?$name\`('|’)s//g" | grep -E "\`/?$name\`" || true)
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      echo "$line" | grep -Eiq '\b(type|types|typed)\b|user (to )?run|tell the user|ask the user' && continue
      echo "FAIL $(basename "$(dirname "$f")") starts typed-only $name: ${line:0:110}"; fail=1
    done <<<"$hits"
  done
done
# A hook's steer reaches the agent too: it never says to start a typed-only skill.
scripts="$root/../scripts"
for name in "${typed[@]}"; do
  hits=$(grep -nEi "(start|run|invoke|load) the \`?/?$name\`? skill" "$scripts"/*.sh 2>/dev/null || true)
  [ -n "$hits" ] && { echo "FAIL a hook script steers the agent to start typed-only $name: ${hits:0:140}"; fail=1; }
done
[ $fail = 0 ] && echo "ok   no startable skill starts a typed-only one"
exit $fail
