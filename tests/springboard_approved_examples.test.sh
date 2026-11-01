#!/usr/bin/env bash
# approved-spec: the S5 examples of the .todo springboard, approved
# 2026-11-01. The hook runs in a fixture repo against a stand-in gh that
# answers from a JSON file, so each check sees what the session sees.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/springboard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/bin" "$fx/repo"
cat > "$fx/bin/gh" <<'EOF'
#!/usr/bin/env bash
cat "$GH_PRS"
EOF
chmod +x "$fx/bin/gh"
export PATH="$fx/bin:$PATH" GH_PRS="$fx/prs.json" CLAUDE_PROJECT_DIR="$fx/repo"
git -C "$fx/repo" init -q; git -C "$fx/repo" remote add origin https://github.com/someone/repo.git
printf '.todo\n' > "$fx/repo/.gitignore"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
pr() { # number draft check-state body
  jq -n --argjson n "$1" --argjson d "$2" --arg s "$3" --arg b "$4" \
    '{number:$n, title:"Change \($n)", url:"https://github.com/someone/repo/pull/\($n)", isDraft:$d, body:$b, statusCheckRollup:[{conclusion:$s, status:"COMPLETED"}]}'
}
prs() { jq -s . > "$GH_PRS"; }
start() { echo '{"hook_event_name":"SessionStart","source":"startup"}' | bash "$hook" 2>/dev/null; }
after() { jq -n --arg c "$1" '{hook_event_name:"PostToolUse",tool_input:{command:$c}}' | bash "$hook" 2>/dev/null; }
block() { sed -n '/^# springboard start/,/^# springboard end/p' "$fx/repo/.todo"; }

# Given a repo with a ready pull request whose checks are green
# When a session starts
# Then the session's first line reads next: N1 merge, with the pull request's link, and nothing else from the list
pr 7 false SUCCESS "" | prs
out=$(start)
check "a session opens on the next action" \
  'grep -q "next: N1 merge #7 .*https://github.com/someone/repo/pull/7" <<<"$out" && ! grep -q "N2" <<<"$out"'

# Given seven things that wait on you
# When the springboard rebuilds
# Then the .todo block lists N1 to N5 and no more
for n in 1 2 3 4 5 6 7; do pr "$n" false SUCCESS ""; done | prs
start >/dev/null
check "the block holds five actions at most" \
  'block | grep -q "^N5 " && ! block | grep -q "^N6 "'

# Given a .todo with lines you wrote above and below the marked block
# When the springboard rebuilds
# Then those lines read exactly as before
pr 7 false SUCCESS "" | prs
{ echo "Rename the cache flag"; block; echo "Drop the old fixture"; } > "$fx/todo"; cp "$fx/todo" "$fx/repo/.todo"
start >/dev/null
check "your own lines stay yours" \
  'block | grep -q "^N1 merge #7 " && [ "$(head -1 "$fx/repo/.todo")" = "Rename the cache flag" ] && [ "$(tail -1 "$fx/repo/.todo")" = "Drop the old fixture" ] && [ "$(grep -vc "^N[0-9] \|^# springboard" "$fx/repo/.todo")" = 2 ]'

# Given a draft pull request with CI still running and a ticket waiting on another person
# When the springboard rebuilds
# Then neither appears in the block
{ pr 8 true "" ""; pr 9 true SUCCESS "\`Waits on:\` Sam reviews the API"; } | jq 'if .number == 8 then .statusCheckRollup = [{conclusion:"", status:"IN_PROGRESS"}] else . end' | prs
start >/dev/null
check "only your actions make the list" \
  'block | grep -q "nothing waits on you" && ! block | grep -q "#8\|#9"'

# Given a repo where nothing waits on you
# When a session starts
# Then the session shows no next line, and the block says nothing waits on you
echo '[]' > "$GH_PRS"
out=$(start)
check "nothing waiting, nothing shown" \
  '! grep -q "next:" <<<"$out" && block | grep -q "nothing waits on you"'

# Given a block that lists a pull request to merge
# When that pull request merges and the next push or closed page comes
# Then the block no longer lists it
pr 7 false SUCCESS "" | prs; start >/dev/null
echo '[]' > "$GH_PRS"
after "git push origin topic" >/dev/null
check "the block follows a push, a merge or a closed page" \
  'block | grep -q "^# springboard start" && ! block | grep -q "#7"'

# Given four tickets opened and nine closed since your last session in this repo, which started on Saturday 31 October, and Claude Code with function hooks turned off
# When a session starts
# Then one line reads Since Sat: 4 opened, 9 closed. Say since for the list.
date -d yesterday -Iseconds > "$fx/repo/.git/springboard-last-session"
out=$(start)
check "since you last worked" \
  'grep -q "List items created or changed since <time>" <<<"$out" && grep -q "List items closed since <time>" <<<"$out" && grep -qF "Since $(date -d yesterday +%a): <n> opened, <m> closed. Say \`since\` for the list." <<<"$out" && grep -qE "since [0-9]{4}-[0-9]{2}-[0-9]{2}T" <<<"$out"'
exit $fail
