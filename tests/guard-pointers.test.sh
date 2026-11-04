#!/usr/bin/env bash
# Every hook a default-on option drives is named in a skill file, so the skill
# flow points at what backs its rules. A guard turned on with no skill naming
# it fails here.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
fail=0
for opt in $(jq -r '.userConfig | to_entries[] | select(.value.type == "boolean" and .value.default == true) | .key' "$root/.claude-plugin/plugin.json"); do
  var="CLAUDE_PLUGIN_OPTION_$(tr '[:lower:]' '[:upper:]' <<<"$opt")"
  scripts=$(grep -lE "${var}([^A-Z_]|$)" "$root"/scripts/*.sh | xargs -n1 basename | sed 's/\.sh$//')
  [ -n "$scripts" ] || { echo "FAIL $opt drives no script"; fail=1; continue; }
  for s in $scripts; do
    if grep -rqF --include="*.md" -- "$s" "$root/skills"; then echo "ok   $opt: a skill names $s"
    else echo "FAIL $opt: no skill names $s"; fail=1; fi
  done
done
exit $fail
