#!/usr/bin/env bash
# approved-spec: the examples the user set for the approved-spec guard: it
# refuses with a steer instead of asking, and a red-pen close that changed an
# approved example grants its test file. Runs the hook and open-draft.sh.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/approved-spec-guard.sh"
open="$root/plugins/vicky-skills/skills/productivity/red-pen/scripts/open-draft.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"; mkdir -p "$dir/repo/tests"
printf 'echo ok\n' > "$dir/repo/tests/charm_approved_examples.test.sh"
printf 'echo ok\n' > "$dir/repo/tests/sleep_approved_examples.test.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
edit() { jq -n --arg f "$dir/repo/$1" '{tool_name: "Edit", tool_input: {file_path: $f}}' | bash "$guard"; }
shell() { jq -n --arg c "$1" --arg d "$dir/repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard"; }
decision() { jq -r '.hookSpecificOutput.permissionDecision // empty'; }
draft() { # $1 draft text before, $2 text the "editor" leaves
  printf '%s' "$1" > "$dir/draft.md"
  printf '#!/usr/bin/env bash\nprintf %%s %q > "$1"\n' "$2" > "$dir/editor"; chmod +x "$dir/editor"
  (cd "$dir/repo" && VISUAL="$dir/editor" bash "$open" "$dir/draft.md" >/dev/null 2>&1)
}
section='# Drafts: charm

## Charm example
tests/charm_approved_examples.test.sh:new

```text
Given a creature charmed by another
When its charmer hits it
Then the charm ends
```
'
f=tests/charm_approved_examples.test.sh
out=$(edit $f); sh=$(shell "sed -i s/ok/no/ $f")
check "an agent editing an approved test I haven't re-approved, by tool or by shell, is refused, and told to take the new wording through examples' Changing an approved example" \
  '[ "$(decision <<<"$out")" = deny ] && [ "$(decision <<<"$sh")" = deny ] && grep -q "Changing an approved example" <<<"$out"'
draft "$section" "$section"
check "after I close a red-pen draft without changing the example, editing its test is still refused" \
  '[ "$(edit $f | decision)" = deny ]'
draft "$section" "${section/the charm ends/the charm ends at once}"
check "after I change an approved example in red-pen and close the file, the agent edits its test with no prompt" \
  '[ -z "$(edit $f | decision)" ] && [ -z "$(shell "sed -i s/ok/no/ $f" | decision)" ]'
check "a grant for one test file leaves a different approved test refused" \
  '[ "$(edit tests/sleep_approved_examples.test.sh | decision)" = deny ]'
exit $fail
