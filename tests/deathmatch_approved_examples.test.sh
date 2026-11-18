#!/usr/bin/env bash
# approved-spec: the Deathmatch examples ticked on 2026-11-18 whose behaviour a
# script decides: which opponents a diff fields, the pre-fight Leak check, the
# Runaway cap, the outside-text wall, the guards that look for a deathmatch,
# the warp's halfway check and once-per-effort. What the opponents conclude is
# proven by the eval cases under evals/deathmatch.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
dm="$root/skills/shipping/deathmatch/scripts"
hooks="$root/scripts"
fail=0
# Mutant runs repeat the memory-hog checks many times. Each kill in a systemd scope
# raises a desktop notice, so inside a mutant run they take the fallback.
hog=(python3 -c 'b = bytearray(256 * 1024 * 1024)'); quiet=()
# A mutant that flips the scope choice would still kill a real hog, so in a
# mutant run the hog only prints the memory error the fallback reads.
[ -n "${MUTATE_HOOKS_INNER:-}" ] && { quiet=(CAP_NO_SCOPE=1); hog=(bash -c 'echo "Cannot allocate memory" >&2; exit 1'); }
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
export HOME="$t/home" CLAUDE_PLUGIN_DATA="$t/data"; mkdir -p "$HOME" "$CLAUDE_PLUGIN_DATA"
repo() { rm -rf "$t/r"; mkdir -p "$t/r" && cd "$t/r" && git init -q -b main && git config user.email t@t && git config user.name t
  echo base > README.md; git add -A; git commit -qm base; git switch -qc b; }

# Given a branch that changes only Markdown
# When deathmatch runs
# Then neither Runaway nor Security fights, and the report says no trigger was in the diff
repo; echo more >> README.md; git commit -qam docs
out=$(bash "$dm/triggers.sh" main 2>&1)
check "E5 a docs-only branch fields no triggered opponent" \
  '! grep -qiE "^(runaway|security)" <<<"$out" && grep -qi "no trigger" <<<"$out"'

# Given a branch that starts a server
# When deathmatch runs
# Then Runaway fights, a run that passes the time or memory cap is stopped and reported as a finding, and nothing else on the machine is stopped
repo; printf '#!/usr/bin/env bash\npython3 -m http.server 8000\n' > serve.sh; git add -A; git commit -qm serve
out=$(bash "$dm/triggers.sh" main 2>&1)
sleep 300 & bystander=$!
# The time case waits out a one-second cap: the shortest the cap takes.
cap=$(bash "$dm/cap.sh" 1 64M -- bash -c 'echo $$ > "'"$t"'/child"; exec sleep 30' 2>&1); rc=$?
child=$(cat "$t/child" 2>/dev/null)
mem=$(env ${quiet[@]+"${quiet[@]}"} bash "$dm/cap.sh" 10 32M -- "${hog[@]}" 2>&1); mrc=$?
check "E6 Runaway fights a server, the cap stops only its own run" \
  'grep -qi "^runaway" <<<"$out" && [ $rc -ne 0 ] && grep -qi "finding: .*time" <<<"$cap" && [ -n "$child" ] && ! kill -0 "$child" 2>/dev/null && [ $mrc -ne 0 ] && grep -qi "finding: .*memory" <<<"$mem" && kill -0 $bystander 2>/dev/null'
kill $bystander 2>/dev/null

# Given a branch that adds a route that reads a request body
# When deathmatch runs
# Then Security fights, and its finding names the crafted or unauthorised request it sent and what came back
repo; printf 'app.post("/notes", (req, res) => res.send(req.body.text));\n' > routes.js; git add -A; git commit -qm route
out=$(bash "$dm/triggers.sh" main 2>&1)
check "E7 Security fights a route (the trigger; the request is the eval case's)" 'grep -qi "^security" <<<"$out"'

# Given a branch that commits a home-folder path
# When deathmatch runs
# Then it stops before any opponent fights and names the file and line
repo; leak="/ho""me/someone/run.log"; printf 'one\nlog=%s\n' "$leak" > conf.txt; git add -A; git commit -qm path
out=$(bash "$dm/prefight.sh" main 2>&1); rc=$?
check "E8 Leak stops the fight, naming the file and line" '[ $rc -ne 0 ] && grep -q "conf.txt:2" <<<"$out"'
repo; printf 'one\nlog=logs/run.log\n' > conf.txt; git add -A; git commit -qm rel
out=$(bash "$dm/prefight.sh" main 2>&1); rc=$?
check "E8 partner: a repo-relative path passes the Leak check" '[ $rc = 0 ]'

# Given a run that read an outside pull request
# When the agent tries to push, file a ticket or post
# Then it is refused, with a steer to return its findings instead
wall() { jq -nc --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"s1",cwd:"'"$t"'",tool_input:{command:$c}}' | bash "$hooks/outside-text-guard.sh" 2>&1; echo "exit=$?"; }
bash "$dm/mark-outside.sh" s1 "pull request 12 by an outside author"
p=$(wall "git push origin b"); i=$(wall "gh issue create --title x --body y"); c=$(wall "gh pr comment 12 --body y")
check "E16 a run that read outside text writes nothing" \
  'grep -q "exit=2" <<<"$p" && grep -q "exit=2" <<<"$i" && grep -q "exit=2" <<<"$c" && grep -qiE "return (the|your) findings" <<<"$p"'

# Given a run that read only the effort's own branch
# When the agent pushes
# Then the push goes through
p=$(jq -nc '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"s3",cwd:"'"$t"'",tool_input:{command:"git push origin b"}}' | bash "$hooks/outside-text-guard.sh" 2>&1; echo "exit=$?")
check "E17 the team's own work still writes" 'grep -q "exit=0" <<<"$p"'

# Given a ready pull request body that names only a review
# When it is opened
# Then pr-guard refuses it, and the same body naming deathmatch passes
repo; mkdir -p docs/agents; echo '# Tickets' > docs/agents/issue-tracker.md
body() { printf '## Status\nReady.\n## Summary\nx\n## Proof\n%s\n## Risk\nLow.\n' "$1" > "$t/body.md"; }
guard() { jq -nc --arg c "gh pr create --title T --body-file $t/body.md" --arg d "$t/r" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"s2",cwd:$d,tool_input:{command:$c}}' | bash "$hooks/pr-guard.sh" >/dev/null 2>&1; echo $?; }
body "The review skill found nothing."; r1=$(guard)
body "Deathmatch: 0 proven findings."; r2=$(guard)
check "E22 pr-guard looks for deathmatch" '[ "$r1" = 2 ] && [ "$r2" = 0 ]'

# Given a deathmatch opponent's brief that names no law file
# When it is sent
# Then review-brief-guard refuses it, as it does a review brief today
brief() { jq -nc --arg p "$1" '{tool_name:"Agent",tool_input:{subagent_type:"vicky-skills:standards-opponent",prompt:$p}}' | bash "$hooks/review-brief-guard.sh" >/dev/null 2>&1; echo $?; }
r1=$(brief "Read the laws at $t/missing/laws.md and break the branch.")
echo law > "$t/laws.md"; r2=$(brief "Read the laws at $t/laws.md and break the branch.")
check "E23 the opponent brief names its law file" '[ "$r1" = 2 ] && [ "$r2" = 0 ]'

# Given a warp of four stars, past its second
# When the third star starts
# Then the Standards opponent alone has reported on the diff so far, and no other opponent ran
h4=$(bash "$dm/halfway.sh" 4)
check "E24 a long warp checks Standards at halfway" '[ "$h4" = "after 2: standards" ]'

# Given a warp of three stars or fewer
# When it runs
# Then no halfway check runs
h3=$(bash "$dm/halfway.sh" 3); r3=$?; h1=$(bash "$dm/halfway.sh" 1); r1=$?
check "E25 a short warp has no halfway check" '[ $r3 = 0 ] && [ $r1 = 0 ] && [ -z "$h3" ] && [ -z "$h1" ]'

# Given a pull request that already holds deathmatch's verdict for its head commit
# When make-it-so runs again
# Then deathmatch does not start a second time
repo; head=$(git rev-parse HEAD)
printf '## Proof\nDeathmatch verdict for %s: 0 proven findings.\n' "$head" > "$t/pr.md"
bash "$dm/verdict.sh" due "$t/pr.md" "$head"; r1=$?
echo x > new.txt; git add -A; git commit -qm next
bash "$dm/verdict.sh" due "$t/pr.md" "$(git rev-parse HEAD)"; r2=$?
check "E27 once per effort, per head commit" '[ $r1 = 1 ] && [ $r2 = 0 ]'

# Given any branch
# When deathmatch runs
# Then Intent and Standards fight, whatever the diff holds
repo; echo more >> README.md; git commit -qam docs
out=$(bash "$dm/triggers.sh" main 2>&1)
check "E29 Intent and Standards always fight" 'grep -qx "fight: intent" <<<"$out" && grep -qx "fight: standards" <<<"$out"'

# Given a branch that changes only Markdown
# When deathmatch runs
# Then Holds and Simplicity don't fight, and the report names each as out of reach
check "E30 a docs-only branch leaves Holds and Simplicity out of reach" \
  'grep -qx "out of reach: holds" <<<"$out" && grep -qx "out of reach: simplicity" <<<"$out" && ! grep -qE "^fight: (holds|simplicity)" <<<"$out"'

# Given a branch that changes a script
# When deathmatch runs
# Then Holds and Simplicity fight
repo; printf '#!/usr/bin/env bash\necho hi\n' > run.sh; git add -A; git commit -qm script
out=$(bash "$dm/triggers.sh" main 2>&1)
check "E31 a script brings Holds and Simplicity" 'grep -qx "fight: holds" <<<"$out" && grep -qx "fight: simplicity" <<<"$out"'

# Given a branch whose commits and pull request body claim no fix
# When deathmatch runs
# Then Cause doesn't fight, and the report names it as out of reach
printf '## Summary\nAdds a greeting.\n## Proof\nTests pass.\n' > "$t/body.md"
out=$(bash "$dm/triggers.sh" main "$t/body.md" 2>&1)
check "E32 no claimed fix leaves Cause out of reach" 'grep -qx "out of reach: cause" <<<"$out" && ! grep -qx "fight: cause" <<<"$out"'

# Given a branch with a commit that says it fixes a bug
# When deathmatch runs
# Then Cause fights
echo 'echo bye' >> run.sh; git commit -qam "Fix the greeting crash on an empty name"
out=$(bash "$dm/triggers.sh" main "$t/body.md" 2>&1)
check "E33 a fix brings Cause" 'grep -qx "fight: cause" <<<"$out"'

# Given a pull request body with no Proof section, or no pull request yet
# When deathmatch runs
# Then Claims doesn't fight, and the report names it as out of reach
printf '## Summary\nAdds a greeting.\n' > "$t/noproof.md"
a=$(bash "$dm/triggers.sh" main "$t/noproof.md" 2>&1); b=$(bash "$dm/triggers.sh" main 2>&1); c=$(bash "$dm/triggers.sh" main "$t/body.md" 2>&1)
check "E34 Claims fights only a body with proof" \
  'grep -qx "out of reach: claims" <<<"$a" && grep -qx "out of reach: claims" <<<"$b" && grep -qx "fight: claims" <<<"$c"'

# Given a deathmatch with more than three opponents to send
# When it fights
# Then no more than three run at once, the next starts when one reports, and each command's memory cap times the opponents running fits in the memory free
free=$(awk '/^MemAvailable:/ {print $2 * 1024}' /proc/meminfo)
b7=$(bash "$dm/batch.sh" 7 2>&1); b2=$(bash "$dm/batch.sh" 2 2>&1)
at=$(sed -n 's/^at once: //p' <<<"$b7"); capb=$(numfmt --from=iec "$(sed -n 's/^memory cap: //p' <<<"$b7")" 2>/dev/null)
check "E35 opponents fight three at a time, their caps within the memory free" \
  '[ "$at" = 3 ] && [ -n "$capb" ] && [ $((capb * at)) -le "$free" ] && grep -qx "at once: 2" <<<"$b2"'

exit $fail
