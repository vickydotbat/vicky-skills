#!/usr/bin/env bash
# The springboard's decisions beyond its approved examples: which repos it
# touches, which commands rebuild it, the page and waiting-on-you actions,
# and the todo reminder leaving the block alone.
set -u
export VISUAL=true EDITOR=true BROWSER=true
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/springboard.sh"
reminder="$root/plugins/vicky-skills/scripts/todo-reminder.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/bin" "$fx/repo" "$fx/plain" "$fx/desktop"
# The hook never opens a page, but it names the page script, so a fake
# desktop stands in should a mutant reach one.
printf '#!/usr/bin/env bash\necho "BROWSER=true"\n' >"$fx/desktop/systemctl"; chmod +x "$fx/desktop/systemctl"
export PATH="$fx/desktop:$PATH"
printf '#!/usr/bin/env bash\ncat "$GH_PRS"\n' > "$fx/bin/gh"; chmod +x "$fx/bin/gh"
export PATH="$fx/bin:$PATH" GH_PRS="$fx/prs.json" CLAUDE_PROJECT_DIR="$fx/repo"
git -C "$fx/repo" init -q; printf '.todo\n' > "$fx/repo/.gitignore"
git -C "$fx/plain" init -q
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
start() { echo '{"hook_event_name":"SessionStart"}' | bash "$hook"; }
after() { jq -n --arg c "$1" '{hook_event_name:"PostToolUse",tool_input:{command:$c}}' | bash "$hook"; }
pr() { jq -n --argjson n "$1" --argjson d "$2" --arg s "$3" --arg b "$4" '{number:$n,title:"T\($n)",url:"u/\($n)",isDraft:$d,body:$b,statusCheckRollup:[{conclusion:$s}]}'; }
reset() { rm -f "$fx/repo/.todo"; }

pr 3 true "" "\`Waits on:\` you, the merge order" | jq -s . > "$GH_PRS"
start >/dev/null
check "a draft whose Waits on line names you is listed with what it waits on" 'grep -q "^N1 #3 waits on you: you, the merge order u/3" "$fx/repo/.todo"'
pr 4 false FAILURE "" | jq -s . > "$GH_PRS"; start >/dev/null
check "a ready pull request with a failed check is not a merge" 'grep -q "nothing waits on you" "$fx/repo/.todo"'
jq -n '[{number:5,title:"T5",url:"u/5",isDraft:false,body:"",statusCheckRollup:[]}]' > "$GH_PRS"; start >/dev/null
check "a pull request with no checks is not a merge" 'grep -q "nothing waits on you" "$fx/repo/.todo"'
pr 6 false SKIPPED "" | jq -s . > "$GH_PRS"; start >/dev/null
check "skipped checks count as green" 'grep -q "^N1 merge #6 T6 u/6" "$fx/repo/.todo"'
echo '[]' > "$GH_PRS"
printf '123\n/drafts/x.md\n' > "$fx/repo/.git/red-pen-open"; start >/dev/null
check "an open draft page comes first" 'grep -q "^N1 press Done on the draft page for /drafts/x.md" "$fx/repo/.todo"'
rm "$fx/repo/.git/red-pen-open"

reset; printf 'Rename the flag\n' > "$fx/repo/.todo"; start >/dev/null
check "a .todo of your lines alone gains the block below them" '[ "$(head -1 "$fx/repo/.todo")" = "Rename the flag" ] && grep -q "^# springboard start" "$fx/repo/.todo"'
reset; check "a session start exits 0" 'start >/dev/null; [ $? = 0 ]'
reset; check "a rebuild after a push exits 0" 'after "git push" >/dev/null; [ $? = 0 ]'
reset; check "a plain command exits 0" 'after "git status" >/dev/null; [ $? = 0 ]'
reset; check "a plain command rebuilds nothing" '[ -z "$(after "git status")" ] && [ ! -f "$fx/repo/.todo" ]'
for c in "git push" "gh pr merge 3 --squash" "tea pr merge 3" "bash x/open-page.sh f.md"; do
  reset; after "$c" >/dev/null
  check "$c rebuilds the block" 'grep -q "^# springboard start" "$fx/repo/.todo"'
done
reset; check "a rebuild after a command says nothing to the agent" '[ -z "$(after "git push")" ]'
reset; check "a word that holds push rebuilds nothing" 'after "echo git pushing" >/dev/null; [ ! -f "$fx/repo/.todo" ]'

check "a repo that doesn't ignore .todo gets no file" 'CLAUDE_PROJECT_DIR="$fx/plain" start >/dev/null; [ ! -f "$fx/plain/.todo" ]'
mkdir -p "$fx/repo/docs/agents"; printf 'Todo file: off\n' > "$fx/repo/docs/agents/domain.md"; reset
check "Todo file: off leaves the repo alone" '[ -z "$(start)" ] && [ ! -f "$fx/repo/.todo" ]'
check "Todo file: off exits 0" 'start >/dev/null; [ $? = 0 ]'
rm "$fx/repo/docs/agents/domain.md"
check "outside a repository it is silent and exits 0" 'out=$(CLAUDE_PROJECT_DIR="$fx" start); [ $? = 0 ] && [ -z "$out" ]'
reset; check "bad input exits 0 and rebuilds nothing" 'echo "not json" | bash "$hook"; [ $? = 0 ] && [ ! -f "$fx/repo/.todo" ]'

reset; pr 7 false SUCCESS "" | jq -s . > "$GH_PRS"; start >/dev/null; printf 'Rename the flag\n' >> "$fx/repo/.todo"
out=$(echo '{}' | bash "$reminder")
check "the todo reminder lists your lines and none of the block" 'grep -q "Rename the flag" <<<"$out" && ! grep -q "springboard\|N1" <<<"$out"'
le="$root/plugins/vicky-skills/skills/engineering/loose-ends/SKILL.md"
check "loose-ends puts small waiting work in .todo, and the agent alone keeps those lines" 'grep -q "Small waiting work starts as a line" "$le" && grep -q "Work with real impact always gets a ticket or a star" "$le" && grep -q "the user never has to edit \`.todo\`" "$le"'
check "the reminder has the agent do each item whose wait is over, unasked" 'grep -q "whose wait is over now, without asking" <<<"$out"'
L81=$(printf 'x%.0s' $(seq 81)); L80=$(printf 'y%.0s' $(seq 80))
reset; printf '%s\n%s\n' "$L81" "$L80" > "$fx/repo/.todo"
edit() { jq -n --arg f "$1" '{hook_event_name:"PostToolUse",tool_input:{file_path:$f}}' | bash "$hook"; }
warn=$(edit "$fx/repo/.todo")
check "a write that leaves a .todo line over 80 characters is told to shorten it" 'grep -q "at most 80 characters" <<<"$warn" && grep -q "$L81" <<<"$warn" && ! grep -q "$L80" <<<"$warn"'
check "a write elsewhere says nothing of .todo" '[ -z "$(edit "$fx/repo/x.md")" ]'
printf '%s\n' "$L80" > "$fx/repo/.todo"
check "a .todo of short lines draws no warning" '[ -z "$(edit "$fx/repo/.todo")" ]'
printf '%s\n' "$L81" > "$fx/repo/.todo"
rem=$(echo '{}' | bash "$reminder")
check "a long line you wrote draws no word at session start" '! grep -q "Shorten\|80 characters" <<<"$rem" && grep -q "$L81" <<<"$rem"'
check "loose-ends caps a .todo line at one sentence of 80 characters, pointing at its star" 'grep -q "one sentence of at most 80 characters that points at the star, chart or ticket it moves" "$le" && grep -q "A line goes when what it points at closes" "$le"'
check "a first session has no since line" 'reset; rm -f "$fx/repo/.git/springboard-last-session"; ! start | grep -q "Since then"'
exit $fail
