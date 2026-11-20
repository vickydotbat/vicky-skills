#!/usr/bin/env bash
# Each plugin loads only the skill folders its plugin.json lists, under the name
# in each SKILL.md, and the marketplace serves only the plugins it lists. A
# folder missing from a list, or a name that differs from its folder, silently
# drops a skill or a plugin.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
market="$root/.claude-plugin/marketplace.json"
fail=0
jq empty "$market" 2>/dev/null || { echo "FAIL .claude-plugin/marketplace.json is not valid JSON"; fail=1; }
for plugin in "$root"/plugins/*/; do
  name=$(basename "$plugin")
  (
    cd "$plugin" || exit 1
    bad=0
    for f in .claude-plugin/plugin.json hooks/hooks.json; do
      [ "$f" = hooks/hooks.json ] && [ ! -e "$f" ] && continue # a plugin with no hooks has no hooks file
      jq empty "$f" 2>/dev/null || { echo "FAIL $name: $f is not valid JSON"; bad=1; }
    done
    jq -e --arg n "$name" '.plugins[] | select(.name == $n and .source == "./plugins/" + $n)' "$market" >/dev/null 2>&1 ||
      { echo "FAIL $name is not listed in the marketplace"; bad=1; }
    listed=$(jq -r '.skills[]' .claude-plugin/plugin.json | sed 's|^\./||' | sort)
    # vicky-skills groups its skills by README section, one level deeper
    depth=2; [ -d skills ] && [ -n "$(find skills -mindepth 3 -maxdepth 3 -name SKILL.md -print -quit)" ] && depth=3
    found=$(find skills -mindepth "$depth" -maxdepth "$depth" -name SKILL.md -printf '%h\n' 2>/dev/null | sort)
    if [ "$listed" != "$found" ]; then
      echo "FAIL $name: plugin.json skills and skill folders differ:"; diff <(echo "$listed") <(echo "$found"); bad=1
    fi
    for dir in $found; do
      skill=$(sed -n 's/^name: //p' "$dir/SKILL.md" | head -1)
      [ "$skill" = "$(basename "$dir")" ] || { echo "FAIL $name: $dir/SKILL.md is named '$skill'"; bad=1; }
    done
    [ $bad -eq 0 ] && echo "ok   $name: $(echo "$found" | wc -l) skills listed, found, named alike"
    exit $bad
  ) || fail=1
done
exit $fail
