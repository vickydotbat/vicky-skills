#!/usr/bin/env bash
# Plain regression tests, no approved example behind them: the guard lets git
# add, git commit and chmod +x name an approved test file, refuses a command
# that rewrites it, and lets a command that only runs or reads it through.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
printf '#!/usr/bin/env bash\n# approved-spec: the charm examples.\n# Given a thing\n# When it runs\n# Then it passes\nexit 0\n' > "$dir/charm_approved_examples.test.sh"; chmod +x "$dir/charm_approved_examples.test.sh"
git -C "$dir" add -A && git -C "$dir" -c user.name=t -c user.email=t@example.invalid commit -qm fixtures
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
sh_run() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
f=charm_approved_examples.test.sh
check "git add naming an approved test file runs" '[ -z "$(sh_run "git add $f")" ]'
check "git commit with a pathspec naming it runs" '[ -z "$(sh_run "git commit -m fixtures -- $f")" ]'
check "git add and git commit in one command run" '[ -z "$(sh_run "git add $f && git commit -m fixtures")" ]'
check "chmod +x naming it runs" '[ -z "$(sh_run "chmod +x $f")" ]'
check "sed -i on it is refused" '[ "$(sh_run "sed -i s/a/b/ $f")" = deny ]'
check "a redirect into it is refused" '[ "$(sh_run "printf x > $f")" = deny ]'
check "tee into it is refused" '[ "$(sh_run "echo x | tee $f")" = deny ]'
check "running it runs" '[ -z "$(sh_run "bash $f")" ]'
check "cat on it runs" '[ -z "$(sh_run "cat $f")" ]'
check "grep on it runs" '[ -z "$(sh_run "grep Given $f")" ]'
exit $fail
