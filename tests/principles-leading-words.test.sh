#!/usr/bin/env bash
# Leading words: every rule and design move in the plugin's STANDARDS.md (a bullet
# opening `**Name.**`) is named by a term of at most four words, never a
# sentence that describes the rule (robot-voice step 5). It counts words, never
# reads them, and fails closed when it finds no rule at all.
set -u
cd "$(dirname "$0")/.."
names() { grep -E '^- \*\*[^*]+\.\*\*' "$1" | sed -E 's/^- \*\*([^*]+)\.\*\*.*/\1/'; }
long() { names "$1" | awk 'NF>4'; }
fx=$(mktemp); trap 'rm -f "$fx"' EXIT
printf -- '- **Single source of truth.** One entry.\n- **Treat a one-way door with care.** Some decisions outlive the code.\n- **A smell named at any length**: fine.\n' > "$fx"
[ "$(long "$fx")" = "Treat a one-way door with care" ] || { echo "FAIL a sentence-named rule is caught, and only it"; exit 1; }
f=plugins/vicky-skills/skills/STANDARDS.md
[ -n "$(names "$f")" ] || { echo "FAIL no rule found in $f: the check has nothing to count"; exit 1; }
bad=$(long "$f")
[ -z "$bad" ] || { echo "FAIL rule names over four words; rename each to its leading word (robot-voice step 5):"; echo "$bad"; exit 1; }
echo "ok   principles-leading-words: every rule is named by a leading word"
