#!/usr/bin/env bash
# The hook nudges after a git push, steers a draft opened in a warp run to
# make-it-so, hints at it for any other draft, and stays silent otherwise.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/after-push.sh"
fail=0
# A forge that lists an open pull request for the branch.
bin=$(mktemp -d); printf "#!/bin/sh\necho 1\n" > "$bin/gh"; cp "$bin/gh" "$bin/tea"; chmod +x "$bin/gh" "$bin/tea"; export PATH="$bin:$PATH"
run() { jq -n --arg c "$1" '{tool_input:{command:$c}}' | "$hook"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
nudge() { run "$1" | jq -r '.hookSpecificOutput.hookEventName // empty'; }
check "nudges after git push" PostToolUse "$(nudge 'git push origin topic')"
check "nudges after a chained push" PostToolUse "$(nudge 'git fetch && git push --force-with-lease')"
check "silent on git status" "" "$(run 'git status')"
check "silent on git pull" "" "$(run 'git pull --rebase')"
check "silent on a word that holds push" "" "$(run 'echo git pushing')"
fx=$(mktemp -d); trap 'rm -rf "$fx" "$bin"' EXIT
printf '%s\n' '{"type":"user","message":{"content":"<command-name>/vicky-skills:warp</command-name>"}}' > "$fx/warp.jsonl"
printf '%s\n' '{"type":"user","message":{"content":"<command-name>/vicky-skills:do</command-name>"}}' > "$fx/do.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill": "vicky-skills:warp"}}]}}' > "$fx/warp-call.jsonl"
printf '%s\n' '{"type":"attachment","content":"- vicky-skills:warp: Warp through a star chart"}' > "$fx/listing.jsonl"
text() { jq -n --arg c "$1" --arg t "${2:-}" '{tool_input:{command:$c}, transcript_path:$t}' | "$hook" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
check "a draft in a warp run is sent to make-it-so" yes "$(text 'git push -u origin x && gh pr create --draft --title T' "$fx/warp.jsonl" | grep -q "then finish it with the make-it-so skill at warp step 6" && echo yes)"
check "the warp steer names the gate it may stop at" yes "$(text 'gh pr create --draft' "$fx/warp.jsonl" | grep -q "Waits on:" && echo yes)"
check "a draft after a Skill call to warp is sent to make-it-so" yes "$(text 'gh pr create --draft' "$fx/warp-call.jsonl" | grep -q "at warp step 6" && echo yes)"
check "a skill listing that names warp gets the soft hint" yes "$(text 'gh pr create --draft' "$fx/listing.jsonl" | grep -q "only if the ask needs a finished pull request" && echo yes)"
check "a draft in a do run by hand gets the soft hint" yes "$(text 'gh pr create --draft' "$fx/do.jsonl" | grep -q "only if the ask needs a finished pull request" && echo yes)"
check "the soft hint never says finish it now" "" "$(text 'gh pr create --draft' "$fx/do.jsonl" | grep -o "at warp step 6")"
check "a draft with no transcript gets the soft hint" yes "$(text 'gh pr create --draft' | grep -q "Otherwise stop at the draft" && echo yes)"
check "a missing transcript file gets the soft hint" yes "$(text 'gh pr create --draft' "$fx/gone.jsonl" | grep -q "Otherwise stop at the draft" && echo yes)"
check "a Gitea WIP pull request gets the hint" yes "$(text 'tea pr create --title "WIP: summit" </dev/null' | grep -q "make-it-so" && echo yes)"
check "tea pulls create counts as tea pr create" yes "$(text 'tea pulls create --title "WIP: x"' | grep -q "make-it-so" && echo yes)"
check "a ready pull request gets no make-it-so note" "" "$(text 'gh pr create --title T' | grep -o make-it-so)"
check "a Gitea pull request without WIP gets no note" "" "$(run 'tea pr create --title summit')"
check "the draft flag in a word gets no note" "" "$(run 'echo gh pr created --draft')"
check "a push that opens a draft gets the draft steer alone" 1 "$(nudge 'git push -u origin x && gh pr create --draft' | wc -l)"
check "the draft steer exits 0, so Claude Code reads it as a note" 0 "$(run 'gh pr create --draft' >/dev/null; echo $?)"
check "a push still gets the body reminder" yes "$(text 'git push' | grep -q "You pushed" && echo yes)"
# Whether the branch has an open pull request is asked in the repo the command ran in.
r=$(mktemp -d); git init -q -b feat "$r/gh"; git -C "$r/gh" remote add origin https://github.com/o/r.git
git init -q -b feat "$r/tea"; git -C "$r/tea" remote add origin https://gitea.example.invalid/o/r.git; git -C "$r/tea" -c user.name=t -c user.email=t@t commit -q --allow-empty -m x
mkdir "$r/bin"; printf '#!/bin/sh\nexit 1\n' > "$r/bin/gh"; printf '#!/bin/sh\necho "5 feat open"\n' > "$r/bin/tea"; chmod +x "$r/bin/"*
h=$(cd "$(dirname "$hook")" && pwd)/after-push.sh
at() { jq -nc --arg d "$1" '{tool_input:{command:"git push"},cwd:$d}' | (cd / && PATH="$r/bin:$PATH" bash "$h"); }
check "a GitHub push with no open pull request is quiet and exits 0" "0:" "$(o=$(at "$r/gh"); echo "$?:$o")"
check "a Gitea push whose branch has an open pull request gets the reminder" yes "$(at "$r/tea" | grep -q "You pushed" && echo yes)"
printf '#!/bin/sh\necho "5 other open"\n' > "$r/bin/tea"
check "a Gitea push whose branch has none is quiet and exits 0" "0:" "$(o=$(at "$r/tea"); echo "$?:$o")"
rm -rf "$r"
exit $fail
