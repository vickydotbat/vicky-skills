#!/usr/bin/env bash
# approved-spec: the examples D1 to D8 approved for the goal-driven do, and the hint where a rule applies. Each check is named
# after its example. Hooks run.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
p="$root/plugins/vicky-skills"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

copy="$dir/copy"; mkdir "$copy"; cp -r "$root/plugins" "$root/tests" "$copy/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$copy/plugins/vicky-skills/scripts/brand-new.sh"
out=$(env -u MUTATE_HOOKS_INNER python3 "$copy/tests/mutate-hooks.py" --budget 1 2>&1); code=$?
check "given a hook script added with no test mapped to it, CI fails and names the script" \
  '[ $code != 0 ] && grep -q "brand-new.sh" <<<"$out"'

hint=$(jq -nc '{tool_input:{skill:"vicky-skills:examples"}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$p/scripts/step-hint.sh")
check "given the step guard setting on, when the examples skill starts, the agent is reminded in one line that the drafts open in the editor through red-pen, never in the chat" \
  'jq -e ".hookSpecificOutput.additionalContext | test(\"red-pen\") and test(\"never in the chat\")" <<<"$hint" >/dev/null'
exit $fail
