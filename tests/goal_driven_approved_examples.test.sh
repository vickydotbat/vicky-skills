#!/usr/bin/env bash
# approved-spec: the examples D1 to D8 approved for the goal-driven do, the
# mutation proof guard and the hint where a rule applies. Each check is named
# after its example. Agent behaviours read the skill text; hooks run.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
p="$root/plugins/vicky-skills"; do="$p/skills/engineering/do/SKILL.md"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$2" '$0 ~ "^"n"\\. " {p=1; print; next} p && /^[0-9]+\. |^## / {exit} p' "$1"; }

check "given a do build with three approved examples, when the second example's test goes green, its mutation counts are in the report before work on the third starts" \
  'step "$do" 3 | grep -q "Mutate each example as its test goes green" && step "$do" 3 | grep -q "before you start the next example"'

# A repo whose testing doc names a proof check, with stubs that pass or fail.
guard="$p/scripts/mutation-proof-guard.sh"
repo="$dir/repo"; git init -q "$repo"; mkdir -p "$repo/docs/agents"
printf 'Mutation proof check: bash check.sh\nMutation proof refresh: python3 tests/mutate-hooks.py --record\n' > "$repo/docs/agents/testing.md"
commit() { jq -n --arg d "$repo" '{tool_name: "Bash", tool_input: {command: "git commit -m x"}, cwd: $d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_MUTATION_PROOF=true bash "$guard" 2>"$dir/err" >/dev/null; }
printf 'echo "stale: pr-guard.sh"; exit 1\n' > "$repo/check.sh"; commit; stale=$?
check "given a repo whose testing doc names a mutation proof check, committing a hook change with the proof out of date is refused and names the refresh command" \
  '[ $stale = 2 ] && grep -qF "python3 tests/mutate-hooks.py --record" "$dir/err"'
printf 'exit 0\n' > "$repo/check.sh"; commit; current=$?
rm "$repo/docs/agents/testing.md"; commit; none=$?
check "given a mutation proof that is current, or a repo that names no proof check, the commit runs" '[ $current = 0 ] && [ $none = 0 ]'

copy="$dir/copy"; mkdir "$copy"; cp -r "$root/plugins" "$root/tests" "$copy/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$copy/plugins/vicky-skills/scripts/brand-new.sh"
out=$(env -u MUTATE_HOOKS_INNER python3 "$copy/tests/mutate-hooks.py" --budget 1 2>&1); code=$?
check "given a hook script added with no test mapped to it, CI fails and names the script" \
  '[ $code != 0 ] && grep -q "brand-new.sh" <<<"$out" && grep -q "tests/mutate-hooks.sh" "$root/tests/red_first_approved_examples.test.sh"'

check "given a finished do build, the report lists each approved example with its red run and its green run, and one only a person can check is marked unchecked and handed to over-to-you" \
  'grep -q "each approved example with its red run and its green run" "$do" && grep -q "unchecked" "$do" && grep -q "over-to-you" "$do"'
check "given an approved coupon example, an edge case the build finds is tested, fixed and listed as found in the report, without asking" \
  'step "$do" 3 | grep -q "An edge case the work turns up: add a test, fix the code, and list it as found in the report. Never ask about one."'
check "given a do build under way, a choice no example settles and that changes no behaviour is taken, built on, and named in the report" \
  'grep -q "A choice that no example settles and that changes no behaviour: take your pick, build on, and name it in the report." "$do"'

hint=$(jq -nc '{tool_input:{skill:"vicky-skills:examples"}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$p/scripts/step-hint.sh")
check "given the step guard setting on, when the examples skill starts, the agent is reminded in one line that the drafts open in the editor through red-pen, never in the chat" \
  'jq -e ".hookSpecificOutput.additionalContext | test(\"red-pen\") and test(\"never in the chat\")" <<<"$hint" >/dev/null'
exit $fail
