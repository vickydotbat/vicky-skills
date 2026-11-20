#!/usr/bin/env bash
# The plugin loads only the skill folders plugin.json lists, under the name in
# each SKILL.md. A folder missing from the list, or a name that differs from
# its folder, silently drops a skill.
set -u
fail=0
for plugin in "$(dirname "$0")"/../plugins/*/; do
(
cd "$plugin" || exit 1
fail=0
for f in .claude-plugin/plugin.json ../../.claude-plugin/marketplace.json hooks/hooks.json; do
  [ "$f" = hooks/hooks.json ] && [ ! -e "$f" ] && continue # a plugin with no hooks has no hooks file
  jq empty "$f" 2>/dev/null || { echo "FAIL $f is not valid JSON"; fail=1; }
done
listed=$(jq -r '.skills[]' .claude-plugin/plugin.json | sed 's|^\./||' | sort)
found=$(find skills -mindepth 2 -maxdepth 3 -name SKILL.md -printf '%h\n' | sort)
if [ "$listed" != "$found" ]; then
  echo "FAIL plugin.json skills and skill folders differ:"; diff <(echo "$listed") <(echo "$found"); fail=1
fi
for dir in $found; do
  name=$(sed -n 's/^name: //p' "$dir/SKILL.md" | head -1)
  [ "$name" = "$(basename "$dir")" ] || { echo "FAIL $dir/SKILL.md is named '$name'"; fail=1; }
done
[ $fail -eq 0 ] && echo "ok   $(basename "$plugin"): $(echo "$found" | wc -l) skills listed, found, named alike"
exit $fail
) || fail=1
done
exit $fail
