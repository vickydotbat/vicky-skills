#!/usr/bin/env bash
# auto-tidy's switches and triggers: which settings turn it off, which tool
# calls start it, and that it stays silent where it has nothing to do.
set -u
. "$(dirname "$0")/lib/auto-tidy-fixture.sh"
merged_repo() { setup; branch feat; merge feat; on_main; }
after() { jq -nc --arg c "$1" --arg d "$dir/repo" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}, cwd: $d}'; }

for v in false 0; do
  merged_repo; out=$(OPT=$v run)
  check "auto_tidy=$v leaves the branch and says nothing" 'has_local feat && [ -z "$out" ]'
done
for v in true 1 ""; do
  merged_repo; OPT=$v run >/dev/null
  check "auto_tidy='$v' tidies" '! has_local feat'
done

for c in 'gh pr merge 1 --squash' 'cd sub && tea pr merge 2' 'tea pulls merge 3'; do
  merged_repo; run "$dir/repo" "$(after "$c")" >/dev/null
  check "after '$c' it tidies" '! has_local feat'
done
for c in 'git status' 'gh pr view 1' 'echo gh pr merged' 'ghx pr merge 1'; do
  merged_repo; out=$(run "$dir/repo" "$(after "$c")")
  check "after '$c' it does nothing" 'has_local feat && [ -z "$out" ]'
done

mkdir -p "$dir/plain"
out=$(run "$dir/plain"); check "outside a repo it says nothing" '[ -z "$out" ]'
out=$(run "$dir/gone"); check "in a folder that is gone it says nothing" '[ -z "$out" ]'

# A report that holds a quote or a backslash still reaches you as JSON.
setup; branch 'q"b'; merge 'q"b'; on_main; echo x > "$dir/repo/back\\slash.txt"
git -C "$dir/repo" switch -q -c sticky origin/main; echo "sticky MERGED $(git -C "$dir/repo" rev-parse sticky)" >> "$dir/prs"
out=$(run); check "a quote and a backslash in the report stay valid JSON" 'jq -e . <<<"$out" >/dev/null && seen "$out" | grep -qF "q\"b" && seen "$out" | grep -qF "slash.txt"'

exit $fail
