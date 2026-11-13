#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Red-first is proven by
# hooks and CI". Each check is named after its example.
set -u
# No test may reach the user's own editor.
export VISUAL=true EDITOR=true
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
opener="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts/open-draft.sh"
dir=$(mktemp -d); trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
commit() { git -C "$1" -c user.name=t -c user.email=t@example.invalid commit -q -m "$2"; }
repo="$dir/repo"; git init -q -b main "$repo"; mkdir -p "$repo/tests" "$repo/scripts"
printf '#!/bin/sh\necho hi\n' > "$repo/scripts/charm.sh"; git -C "$repo" add .; commit "$repo" base
# The commit guard's exit code on a commit command run in $repo.
guard() { jq -n --arg c "$1" --arg d "$repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_RED_FIRST=true bash "$scripts/red-first-guard.sh" 2>"$dir/err" >/dev/null; }

printf 'exit 1\n' > "$repo/tests/charm_approved_examples.test.sh"; printf 'echo changed\n' >> "$repo/scripts/charm.sh"
git -C "$repo" add .; guard 'git commit -m both'; both=$?
check "a commit that adds a new approved-examples test and also changes a script is refused, and told to commit the approved tests on their own first" \
  '[ $both = 2 ] && grep -q "approved tests on their own first" "$dir/err"'

git -C "$repo" reset -q scripts/charm.sh; guard 'git commit -m tests'; alone=$?
check "a commit that adds only new approved-examples tests runs" '[ $alone = 0 ]'

commit "$repo" "red tests"; git -C "$repo" add .; guard 'git commit -m code'; code_only=$?
check "a commit that changes only code, with the approved tests already committed, runs" '[ $code_only = 0 ]'
commit "$repo" code

# A branch off main: one approved test added red, then its code; another added green.
git -C "$repo" switch -q -c work
printf '[ -f scripts/ward.sh ]\n' > "$repo/tests/ward_approved_examples.test.sh"; git -C "$repo" add .; commit "$repo" "ward tests"
printf 'echo ward\n' > "$repo/scripts/ward.sh"; git -C "$repo" add .; commit "$repo" "ward code"
printf 'exit 0\n' > "$repo/tests/glow_approved_examples.test.sh"; git -C "$repo" add .; commit "$repo" "glow, code first"
glow=$(git -C "$repo" rev-parse --short HEAD)
green=$(cd "$repo" && bash "$scripts/red-first-check.sh" main HEAD 2>&1); green_code=$?
red=$(cd "$repo" && bash "$scripts/red-first-check.sh" main HEAD~1 2>&1); red_code=$?
check "on a branch whose new approved test passed at the commit that added it, the red-first check fails and names that test and commit" \
  '[ $green_code != 0 ] && grep -q "glow_approved_examples.test.sh" <<<"$green" && grep -q "$glow" <<<"$green"'
check "on a branch whose new approved tests each failed at the commit that added them, the red-first check passes" '[ $red_code = 0 ]'

out=$(bash "$root/tests/mutate-hooks.sh" 2>&1); mcode=$?
covered=$(grep '^script ' <<<"$out" | grep -vc '^script skills/'); hooks=$(ls "$scripts" | wc -l)
check "a mutation pass over every hook script in the plugin leaves no mutant alive" \
  '[ $mcode = 0 ] && grep -q "^survivors: 0$" <<<"$out" && [ "$covered" = "$hooks" ]'
exit $fail
