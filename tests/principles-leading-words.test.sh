#!/usr/bin/env bash
# Leading words: every rule and design move in review's PRINCIPLES.md is named
# by a term of at most four words, never a sentence that describes the rule
# (robot-voice step 5). It counts words, never reads them.
set -u
cd "$(dirname "$0")/.."
long() { awk '/^## (Rules|Design moves)/{f=1;next} /^## /{f=0} f && /^- \*\*/' "$1" \
  | sed -E 's/^- \*\*([^*]+)\*\*.*/\1/; s/\.$//' | awk 'NF>4'; }
fx=$(mktemp); trap 'rm -f "$fx"' EXIT
printf '## Rules\n\n- **Single source of truth.** One entry.\n\n## Design moves\n\n- **Treat a one-way door with care.** Some decisions outlive the code.\n\n## Smells\n\n- **A smell named at any length**: fine.\n' > "$fx"
[ "$(long "$fx")" = "Treat a one-way door with care" ] || { echo "FAIL a sentence-named rule is caught, and only it"; exit 1; }
bad=$(long plugins/vicky-skills/skills/shipping/review/PRINCIPLES.md)
[ -z "$bad" ] || { echo "FAIL rule names over four words; rename each to its leading word (robot-voice step 5):"; echo "$bad"; exit 1; }
echo "ok   principles-leading-words: every rule is named by a leading word"
