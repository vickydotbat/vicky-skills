#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Approved tests change
# only with my yes". Each check is named after its example. The guard checks
# run the hook; the rule checks read the skill text that drives the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/approved-spec-guard.sh"
skills="$root/plugins/vicky-skills/skills"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/tests"; printf 'echo ok\n' > "$dir/tests/charm_approved_examples.test.sh"
printf 'open("tests/charm_approved_examples.test.sh", "w").write("")\n' > "$dir/fix.py"
printf 'print("hello")\n' > "$dir/other.py"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# The guard's decision on a Bash command run in $dir: "ask", or "" for none.
decide() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
f=tests/charm_approved_examples.test.sh
asks=0
for c in "sed -i 's/ok/no/' $f" "echo x > $f" "echo x >> $f" "printf x | tee $f" "python3 fix.py" "python3 - <<'PY'
open('$f','w')
PY" "git checkout HEAD~1 -- $f" "git restore $f" "cp other.py $f" "rm $f"; do
  [ "$(decide "$c")" = ask ] && asks=$((asks + 1)) || echo "     not asked: $c"
done
check "an agent editing an approved-examples test with a shell command (sed -i, a redirect, a script, git checkout or restore) is asked first, as with the Edit tool" \
  '[ $asks = 10 ] && grep -q "Bash" <(jq -r ".hooks.PreToolUse[] | select(.hooks[].command | test(\"approved-spec-guard\")) | .matcher" "$root/plugins/vicky-skills/hooks/hooks.json")'

quiet=0
for c in "bash $f" "./$f" "cat $f" "grep -n Given $f" "bash $f | grep FAIL" "bash $f > out.txt" "python3 other.py" "git diff $f" "git add $f"; do
  [ -z "$(decide "$c")" ] && quiet=$((quiet + 1)) || echo "     asked: $c"
done
check "an agent only running an approved-examples test, or reading it with cat or grep, is not asked" '[ $quiet = 9 ]'

check "review and make-it-so bring a finding on an approved-examples test to me as a question through \"Changing an approved example\", never fixed in place" \
  'grep -q "finding on an approved-spec test goes to the user" "$skills/engineering/review/SKILL.md" && grep -q "Changing an approved example" "$skills/engineering/review/SKILL.md" && grep -q "finding on an approved-spec test goes to the user" "$skills/engineering/make-it-so/SKILL.md"'

check "examples refuses a new approved test whose check only searches the source of the code it tests, before it counts as red" \
  'grep -q "placebo" <(grep "Make each example red" "$skills/engineering/examples/SKILL.md") && grep -q "searches the source of the code it tests" "$skills/engineering/examples/SKILL.md"'

check "a warp waiting on my approval of a star's examples writes no code for that star until its tests exist and fail" \
  'grep -q "no code for a star until its approved tests exist and fail" "$skills/engineering/warp/SKILL.md"'
exit $fail
