#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Red-first is proven by
# hooks and CI". Each check is named after its example.
set -u
# No test may reach the user's own editor.
export VISUAL=true EDITOR=true
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
opener="$root/plugins/vicky-skills/skills/productivity/red-pen/scripts/open-draft.sh"
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

# The draft lock: a stub editor that waits stands in for the user's.
mkdir -p "$dir/scratch" "$dir/vault"
printf '#!/bin/sh\nexec sleep 30\n' > "$dir/editor"; chmod +x "$dir/editor"
(cd "$repo" && VISUAL="$dir/editor" bash "$opener" "$dir/scratch/draft.md") & opener_pid=$!
lockfile="$(git -C "$repo" rev-parse --absolute-git-dir)/red-pen-open"
for _ in $(seq 50); do [ -s "$lockfile" ] && break; sleep 0.1; done
lock() { CLAUDE_PLUGIN_OPTION_GUARD_DRAFT_LOCK=true bash "$scripts/draft-lock.sh" 2>/dev/null >/dev/null; }
edit() { jq -n --arg f "$1" --arg d "$repo" '{tool_name: "Edit", tool_input: {file_path: $f}, cwd: $d}' | lock; }
shell() { jq -n --arg c "$1" --arg d "$repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | lock; }
edit "$repo/scripts/charm.sh"; e1=$?; shell "sed -i s/hi/ho/ scripts/charm.sh"; e2=$?; shell "echo x > scripts/charm.sh"; e3=$?
check "while a draft is open in my editor through red-pen, an edit to a code file in the repo, by any tool, is refused" \
  '[ $e1 = 2 ] && [ $e2 = 2 ] && [ $e3 = 2 ]'
edit "$dir/scratch/notes.md"; s1=$?; edit "$dir/vault/note.md"; s2=$?; shell "echo x > $dir/scratch/notes.md"; s3=$?
check "while a draft is open in my editor through red-pen, a write in the scratch folder or the vault runs" \
  '[ $s1 = 0 ] && [ $s2 = 0 ] && [ $s3 = 0 ]'
kill "$(head -1 "$lockfile" 2>/dev/null)" 2>/dev/null; wait $opener_pid 2>/dev/null

out=$(bash "$root/tests/mutate-hooks.sh" 2>&1); mcode=$?
covered=$(grep -c '^script ' <<<"$out"); hooks=$(ls "$scripts" | wc -l)
check "a mutation pass over every hook script in the plugin leaves no mutant alive" \
  '[ $mcode = 0 ] && grep -q "^survivors: 0$" <<<"$out" && [ "$covered" = "$hooks" ]'
exit $fail
