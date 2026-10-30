#!/usr/bin/env bash
# The plugin loads only the skill folders plugin.json lists, under the name in
# each SKILL.md. A folder missing from the list, or a name that differs from
# its folder, silently drops a skill. A skill the README doesn't list is one
# nobody knows to use.
set -u
cd "$(dirname "$0")/../plugins/vicky-skills"
fail=0
for f in .claude-plugin/plugin.json ../../.claude-plugin/marketplace.json hooks/hooks.json; do
  jq empty "$f" 2>/dev/null || { echo "FAIL $f is not valid JSON"; fail=1; }
done
listed=$(jq -r '.skills[]' .claude-plugin/plugin.json | sed 's|^\./||' | sort)
found=$(find skills -mindepth 3 -maxdepth 3 -name SKILL.md -printf '%h\n' | sort)
if [ "$listed" != "$found" ]; then
  echo "FAIL plugin.json skills and skill folders differ:"; diff <(echo "$listed") <(echo "$found"); fail=1
fi
for dir in $found; do
  name=$(sed -n 's/^name: //p' "$dir/SKILL.md" | head -1)
  [ "$name" = "$(basename "$dir")" ] || { echo "FAIL $dir/SKILL.md is named '$name'"; fail=1; }
done
for dir in $found; do
  grep -qF "**\`$(basename "$dir")\`**" ../../README.md || { echo "FAIL README.md has no line for $(basename "$dir")"; fail=1; }
done
[ $fail -eq 0 ] && echo "ok   $(echo "$found" | wc -l) skills listed, found, named alike and in the README"
exit $fail
