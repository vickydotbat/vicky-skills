#!/usr/bin/env bash
# checklist.py writes the over-to-you checklist from a spec in the one form the
# page reads, and refuses a spec it can't write without breaking that form.
# shellcheck disable=SC2016,SC2034,SC2329
# check runs each condition with eval, so the single quotes, the variables and the
# helpers they name are used there, out of shellcheck's sight.
set -u
export VISUAL=false EDITOR=false
root="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root/plugins/vicky-skills/skills/building/over-to-you/scripts"
page="$root/plugins/vicky-skills/skills/writing/interactive-page/scripts"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
item='{"do": "Open the pack", "see": "the slots show", "person": "look"}'
# receipt <dir> <id> <exit> <command>: a receipt as ran.sh writes it, on HEAD of no repo.
receipt() { mkdir -p "$1/over-to-you-receipts"; jq -n --arg id "$2" --argjson e "$3" --arg c "$4" '{id:$id, command:$c, exit:$e, at:"2026-01-01T00:00:00Z", head:"", cwd:"/", tail:""}' > "$1/over-to-you-receipts/$2.json"; }
receipt "$dir" r 0 "harness.sh --chat '/runscript paper'"
# fresh <dir> <id> <command>: a stage receipt as ran.sh writes it a moment ago.
fresh() { mkdir -p "$1/over-to-you-receipts"; jq -n --arg id "$2" --arg c "$3" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:$id, command:$c, exit:0, at:$at, head:"", cwd:"/", hold:60, tail:"app Up 2 minutes"}' > "$1/over-to-you-receipts/$2.json"; }
fresh "$dir" stage "podman ps --filter name=app"
spec() { # items json -> spec file; an item with no ran names the receipt r
  jq -n --argjson items "$(jq 'map(.ran //= "r")' <<<"$1")" '{name: "Bob", brief: ["One sitting for the pack."], open: "Open the client on the branch.",
    signed_off: "nothing yet", proven_by: "`health.sh` answers ok", stage_ran: "stage", sections: [{title: "Pack", items: $items}]}' > "$dir/spec.json"
}
write() { rm -f "$dir/out.md"; python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/out.md"; }

spec "[$item, {\"do\": \"Spawn the paper\", \"see\": \"the sheet shows\", \"person\": \"real client\", \"kit\": \"\`/runscript paper\`\"}]"
check "a good spec writes the checklist and exits 0" 'write >/dev/null && [ -s "$dir/out.md" ]'
check "the written checklist passes the lint" '[ -z "$(python3 -I "$skill/lint-checklist.py" "$dir/out.md")" ]'
check "the legend line is the page's own" 'grep -qxF "Mark each item: [x] completed as expected, [~] completed with changes, [-] failed to complete, [ ] not tested at all." "$dir/out.md"'
html=$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import page; print(page.page("x", page.parse(open(sys.argv[2]).read(), "/")))' "$page" "$dir/out.md")
check "the page draws both items as cards with every mark labelled" '[ "$(grep -o "<div class=card>" <<<"$html" | wc -l)" = 2 ] && [ "$(grep -o "failed to complete</label>" <<<"$html" | wc -l)" = 2 ]'
check "every section and Extra tests carry the quick-note tags" '[ "$(grep -c "^- QUESTION:" "$dir/out.md")" = 2 ]'

spec "[$item,$item,$item,$item,$item,$item,$item,$item]"
check "eight items are refused and nothing is written" 'out=$(write); [ $? = 1 ] && grep -q "7 at most" <<<"$out" && [ ! -e "$dir/out.md" ]'
spec '[{"do": "Open the pack", "see": "the slots show"}]'
check "an item with no person is refused" 'out=$(write); [ $? = 1 ] && grep -q "item 1 has no person" <<<"$out"'
spec '[{"do": "Spawn the paper", "see": "the sheet shows", "person": "look"}]'
check "an item that reaches a thing with no kit is refused by the lint" 'out=$(write); [ $? = 1 ] && grep -q "kit" <<<"$out" && [ ! -e "$dir/out.md" ]'
jq -n --argjson i '[{"do": "Open the pack", "see": "the slots show", "person": "look", "ran": "r"}]' '{name: "Bob", open: "x", signed_off: "nothing yet", sections: [{title: "P", items: $i}]}' > "$dir/spec.json"
check "a spec with no proven by is refused" 'out=$(write); [ $? = 1 ] && grep -q "missing proven_by" <<<"$out"'
jq -n --argjson i '[{"do": "Open the pack", "see": "the slots show", "person": "look", "ran": "r"}]' '{name: "Bob", open: "x", signed_off: "n", proven_by: "p", stage_ran: "stage", sitting: [2, 3], sections: [{title: "P", items: $i}]}' > "$dir/spec.json"
check "a numbered sitting says which one it is" 'write >/dev/null && grep -qx "Sitting 2 of 3." "$dir/out.md"'
check "a wrong call prints its usage and exits 2" 'python3 -I "$skill/checklist.py" 2>/dev/null; [ $? = 2 ]'
mkdir -p "$dir/tmp/s1"
receipt "$dir/tmp/s1" r 0 "harness.sh"; fresh "$dir/tmp/s1" stage "podman ps"
receipt "$dir/tmp" r 0 "harness.sh"; fresh "$dir/tmp" stage "podman ps" # so only the loose-folder rule stops the next write
spec "[$item]"
out=$(env TMPDIR="$dir/tmp" CLAUDE_CODE_SESSION_ID=s1 python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/tmp/over-to-you-x.md" 2>&1); rc=$?
check "a checklist loose in the shared temp folder is refused, naming the session folder" '[ $rc = 1 ] && grep -q "tmp/s1" <<<"$out" && [ ! -e "$dir/tmp/over-to-you-x.md" ]'
env TMPDIR="$dir/tmp" CLAUDE_CODE_SESSION_ID=s1 python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/tmp/s1/over-to-you-x.md" >/dev/null
check "a checklist in the session folder is written" '[ -s "$dir/tmp/s1/over-to-you-x.md" ]'
# The whole file for a full spec: a one-line brief, two sections, a kit and its source, and extra tests.
jq -n '{name: "Bob", brief: "One sitting.", open: "Open the client.", signed_off: "nothing yet", proven_by: "`health.sh` answers ok", stage_ran: "stage", extra: "Try the bank too.", sections: [{title: "Pack", items: [{do: "Open the pack", see: "the slots show", person: "look", ran: "r"}]}, {title: "Paper", items: [{do: "Spawn the paper", see: "the sheet shows", person: "real client", kit: "`/runscript paper` in the game chat", source: "the module scripts", ran: "r"}]}]}' > "$dir/spec.json"
cat > "$dir/want.md" <<'WANT'
# Over to you, Bob!

One sitting.
Open the client.
signed off: nothing yet
proven by: `health.sh` answers ok
Mark each item: [x] completed as expected, [~] completed with changes, [-] failed to complete, [ ] not tested at all.

## Pack

1. [ ] Open the pack → the slots show
   person: look
   ran: `harness.sh --chat '/runscript paper'` exit 0 at 2026-01-01T00:00:00Z
   notes:

quick notes:
- BUG:
- QUIRK:
- FRICTION:
- UGLY:
- IDEA:
- RULE:
- WIP:
- QUESTION:

## Paper

2. [ ] Spawn the paper → the sheet shows
   person: real client
   ran: `harness.sh --chat '/runscript paper'` exit 0 at 2026-01-01T00:00:00Z
   kit: `/runscript paper` in the game chat
   source: the module scripts
   notes:

quick notes:
- BUG:
- QUIRK:
- FRICTION:
- UGLY:
- IDEA:
- RULE:
- WIP:
- QUESTION:

## Extra tests

Try the bank too.

quick notes:
- BUG:
- QUIRK:
- FRICTION:
- UGLY:
- IDEA:
- RULE:
- WIP:
- QUESTION:

## Other

WANT
check "a full spec writes exactly the checklist the page reads" 'write >/dev/null && diff "$dir/want.md" "$dir/out.md" >/dev/null'
spec "[$item]"
check "with no extra tests named, Extra tests says nothing yet" 'write >/dev/null && grep -A2 "^## Extra tests" "$dir/out.md" | grep -qx "nothing yet"'
jq -n '{name: "Bob", open: "x", signed_off: "n", proven_by: "p", sections: [{title: "P", items: []}]}' > "$dir/spec.json"
check "a spec with no items is refused" 'out=$(write); [ $? = 1 ] && grep -qx "no items" <<<"$out"'
check "a wrong call names its usage" 'python3 -I "$skill/checklist.py" 2>&1 | grep -q "^usage: checklist.py"'
# Receipts: every item is the agent's own run first.
jq -n '{name: "Bob", open: "x", signed_off: "n", proven_by: "p", sections: [{title: "P", items: [{do: "Open the pack", see: "the slots show", person: "look"}]}]}' > "$dir/spec.json"
check "an item with no ran is refused" 'out=$(write); [ $? = 1 ] && grep -q "item 1 has no ran" <<<"$out" && [ ! -e "$dir/out.md" ]'
spec '[{"do": "Open the pack", "see": "the slots show", "person": "look", "ran": "gone"}]'
check "a missing receipt is refused" 'out=$(write); [ $? = 1 ] && grep -q "no receipt gone" <<<"$out"'
receipt "$dir" red 1 "harness.sh"
spec '[{"do": "Open the pack", "see": "the slots show", "person": "look", "ran": "red"}]'
check "a receipt that exited non-zero is refused" 'out=$(write); [ $? = 1 ] && grep -q "receipt red exited 1" <<<"$out"'
receipt "$dir" other 0 "harness.sh --chat '/runscript door'"
spec '[{"do": "Spawn the paper", "see": "the sheet shows", "person": "real client", "kit": "`/runscript paper` in the game chat", "source": "s", "ran": "other"}]'
check "a receipt that does not hold the kit is refused" 'out=$(write); [ $? = 1 ] && grep -q "neither it nor its output holds the kit" <<<"$out"'
mkdir -p "$dir/over-to-you-receipts"; jq -n '{id:"logged", command:"harness.sh scenarios/paper.lua", exit:0, at:"t", head:"", cwd:"/", tail:"chat: /runscript paper\nok"}' > "$dir/over-to-you-receipts/logged.json"
spec '[{"do": "Spawn the paper", "see": "the sheet shows", "person": "real client", "kit": "`/runscript paper` in the game chat", "source": "s", "ran": "logged"}]'
check "a harness that runs the kit from a scenario file passes when its output shows the kit" 'write >/dev/null'
git -C "$dir" init -q repo && git -C "$dir/repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
old=$(git -C "$dir/repo" rev-parse HEAD); git -C "$dir/repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m two
jq -n --arg h "$old" --arg c "$dir/repo" '{id:"stale", command:"harness.sh", exit:0, at:"t", head:$h, cwd:$c, tail:""}' > "$dir/over-to-you-receipts/stale.json"
spec '[{"do": "Open the pack", "see": "the slots show", "person": "look", "ran": "stale"}]'
check "a receipt run on an older commit is refused, read in the receipt's own folder" 'out=$(cd "$dir" && write); [ $? = 1 ] && grep -q "not HEAD" <<<"$out"'
# ran.sh writes the receipt checklist.py reads.
ran() { env TMPDIR="$dir/rt" CLAUDE_CODE_SESSION_ID=s2 bash "$skill/ran.sh" "$@"; }
check "ran.sh passes the command's output and status through" 'out=$(ran ok bash -c "echo hello; exit 0" 2>/dev/null); [ $? = 0 ] && [ "$out" = hello ]'
check "ran.sh writes a receipt with the command, exit and output tail" 'jq -e ".exit == 0 and .command == \"bash -c echo hello; exit 0\" and .tail == \"hello\"" "$dir/rt/s2/over-to-you-receipts/ok.json" >/dev/null'
check "ran.sh keeps a failing exit, in its status and its receipt" 'ran bad false 2>/dev/null; [ $? = 1 ] && jq -e ".exit == 1" "$dir/rt/s2/over-to-you-receipts/bad.json" >/dev/null'
check "ran.sh stops a hung command at RAN_TIMEOUT" 'RAN_TIMEOUT=1 ran slow sleep 5 2>/dev/null; [ $? = 124 ]'
check "ran.sh refuses an id with a space" 'ran "a b" true 2>/dev/null; [ $? = 2 ] && [ ! -e "$dir/rt/s2/over-to-you-receipts/a b.json" ]'
check "ran.sh leaves no scratch log behind" '[ -z "$(find "$dir/rt/s2/over-to-you-receipts" -name ".*" -type f)" ]'
mkdir -p "$dir/rt3"; : > "$dir/rt3/s3"
check "ran.sh stops when the receipt folder cannot be made" 'env TMPDIR="$dir/rt3" CLAUDE_CODE_SESSION_ID=s3 bash "$skill/ran.sh" x true 2>/dev/null; [ $? = 2 ]'
mkdir -p "$dir/nopy"; for t in bash timeout tee git date mktemp tail mkdir rm; do ln -s "$(command -v "$t")" "$dir/nopy/$t"; done
check "ran.sh without python3 stops before it runs the command" 'out=$(env PATH="$dir/nopy" TMPDIR="$dir/rt" CLAUDE_CODE_SESSION_ID=s2 bash "$skill/ran.sh" np bash -c "echo ran-it" 2>&1); [ $? = 2 ] && grep -q "python3 is missing" <<<"$out" && ! grep -q ran-it <<<"$out"'
mkdir -p "$dir/nojq"; for t in bash timeout tee git date mktemp tail mkdir rm python3; do ln -s "$(command -v "$t")" "$dir/nojq/$t"; done
check "ran.sh writes its receipt with no jq on the machine" 'env PATH="$dir/nojq" TMPDIR="$dir/rt" CLAUDE_CODE_SESSION_ID=s2 bash "$skill/ran.sh" nj bash -c "exit 0" 2>/dev/null && [ "$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[\"exit\"])" "$dir/rt/s2/over-to-you-receipts/nj.json")" = 0 ]'
check "ran.sh refuses with no session id" 'env -u CLAUDE_CODE_SESSION_ID bash "$skill/ran.sh" x true 2>/dev/null; [ $? = 2 ]'
check "ran.sh with too few arguments prints its usage and exits 2" 'out=$(bash "$skill/ran.sh" x 2>&1); [ $? = 2 ] && grep -q "^usage: ran.sh" <<<"$out"'
mkdir -p "$dir/rt/s2"; fresh "$dir/rt/s2" stage "podman ps"; jq -n '{name: "Bob", open: "x", signed_off: "n", proven_by: "p", stage_ran: "stage", sections: [{title: "P", items: [{do: "Open the pack", see: "the slots show", person: "look", ran: "ok"}]}]}' > "$dir/spec.json"
mkdir -p "$dir/wr/over-to-you-receipts"; fresh "$dir/wr" stage "podman ps"; jq -n --arg c "bash $dir/rt/s2/iloop.sh" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"w", command:$c, exit:0, at:$at, head:"", cwd:"/", hold:0, tail:"exit=1"}' > "$dir/wr/over-to-you-receipts/w.json"; jq -n '{name: "Bob", open: "x", signed_off: "n", proven_by: "p", stage_ran: "stage", sections: [{title: "P", items: [{do: "Open the pack", see: "the slots show", person: "look", ran: "w"}]}]}' > "$dir/wr/spec.json"
check "a receipt whose command is a script written in the session folder is refused" 'out=$(env TMPDIR="$dir/rt" CLAUDE_CODE_SESSION_ID=s2 python3 -I "$skill/checklist.py" "$dir/wr/spec.json" "$dir/wr/out.md" 2>&1); [ $? = 1 ] && grep -q "session folder" <<<"$out"'
for wc in 'bash "SESS/iloop.sh"' 'sh -c "SESS/iloop.sh"' 'bash ./iloop.sh'; do
  c=${wc//SESS/$dir/rt/s2}; wcwd=/; [[ $wc = *./* ]] && wcwd="$dir/rt/s2"
  jq -n --arg c "$c" --arg cwd "$wcwd" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"w", command:$c, exit:0, at:$at, head:"", cwd:$cwd, hold:0, tail:"exit=1"}' > "$dir/wr/over-to-you-receipts/w.json"
  check "a receipt that runs a session-folder script is refused: $wc" 'out=$(env TMPDIR="$dir/rt" CLAUDE_CODE_SESSION_ID=s2 python3 -I "$skill/checklist.py" "$dir/wr/spec.json" "$dir/wr/out.md" 2>&1); [ $? = 1 ] && grep -q "session folder" <<<"$out"'
done
for bad in abc 60s -5; do
  check "ran.sh refuses RAN_HOLD=$bad before it runs the command" 'rm -f "$dir/badhold"; RAN_HOLD=$bad ran badhold bash -c "touch \"\$1\"" _ "$dir/badhold" 2>/dev/null; [ $? = 2 ] && [ ! -e "$dir/badhold" ]'
done
check "ran.sh with RAN_HOLD runs the check twice and records the hold" 'rm -f "$dir/twice"; RAN_HOLD=1 ran held bash -c "echo x >> \"\$1\"" _ "$dir/twice" >/dev/null 2>&1 && [ "$(wc -l < "$dir/twice")" = 2 ] && jq -e ".hold == 1" "$dir/rt/s2/over-to-you-receipts/held.json" >/dev/null'
check "ran.sh with RAN_HOLD waits the hold between its two runs" 's=$(date +%s%N); RAN_HOLD=1 ran heldwait true >/dev/null 2>&1; [ $(( ($(date +%s%N) - s) / 1000000 )) -ge 1000 ]'
check "ran.sh with RAN_HOLD fails when the second check fails" 'rm -f "$dir/once"; RAN_HOLD=1 ran heldfail bash -c "[ ! -e \"\$1\" ] && touch \"\$1\"" _ "$dir/once" >/dev/null 2>&1; [ $? = 1 ] && jq -e ".exit == 1 and .hold == 0" "$dir/rt/s2/over-to-you-receipts/heldfail.json" >/dev/null'
check "ran.sh without RAN_HOLD records no hold" 'jq -e ".hold == 0" "$dir/rt/s2/over-to-you-receipts/ok.json" >/dev/null'
check "a receipt ran.sh wrote opens the way to the checklist" 'env TMPDIR="$dir/rt" CLAUDE_CODE_SESSION_ID=s2 python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/rt/s2/over-to-you-ok.md" && grep -q "^   ran: .bash -c echo hello; exit 0. exit 0" "$dir/rt/s2/over-to-you-ok.md"'
# The page opener refuses a checklist typed by hand.
printf '# Over to you, Bob!\nproven by: p\n1. [ ] Open the pack → the slots show\n   person: look\n' > "$dir/rt/s2/over-to-you-hand.md"
check "open-page refuses a hand-typed checklist with no ran lines" 'out=$(VISUAL=true bash "$page/open-draft.sh" "$dir/rt/s2/over-to-you-hand.md" 2>&1); [ $? = 2 ] && grep -q "page stays shut" <<<"$out"'
check "open-page opens a checklist checklist.py wrote" '(cd "$dir" && VISUAL=true bash "$page/open-draft.sh" "$dir/rt/s2/over-to-you-ok.md" >/dev/null 2>&1)'
check "an opened checklist leaves its marker, the editor pid, the time and its path" 'read -r p t f < "$dir/rt/s2/over-to-you-opened" && [ "$p" -gt 0 ] && [ "$t" -ge "$(( $(date +%s) - 60 ))" ] && [ "$f" -ef "$dir/rt/s2/over-to-you-ok.md" ]'
rm -f "$dir/rt/s2/over-to-you-opened"
VISUAL=true bash "$page/open-draft.sh" "$dir/rt/s2/over-to-you-hand.md" >/dev/null 2>&1
check "a refused checklist leaves no marker" '[ ! -e "$dir/rt/s2/over-to-you-opened" ]'
printf 'F1 | open | x\n' > "$dir/rt/s2/over-to-you-ledger.md"
(cd "$dir" && VISUAL=true bash "$page/open-draft.sh" "$dir/rt/s2/over-to-you-ledger.md" >/dev/null 2>&1)
check "the ledger opens with no lint and leaves no marker" '[ $? = 0 ] && [ ! -e "$dir/rt/s2/over-to-you-opened" ]'
# A receipt from a command that does nothing proves no check ran.
for noop in "true" "echo '/runscript paper'" ": /runscript paper" "printf '/runscript paper'"; do
  receipt "$dir" noop 0 "$noop"
  spec "[{\"do\": \"Spawn the paper\", \"see\": \"the sheet shows\", \"person\": \"real client\", \"kit\": \"\`/runscript paper\`\", \"ran\": \"noop\"}]"
  check "a receipt of a no-op command is refused: $noop" 'out=$(write 2>&1); [ $? != 0 ] && grep -q "does nothing" <<<"$out"'
done
spec "[$item]"
# ran.sh stays inside its time and size bounds.
check "a command that leaves a child holding its output still ends at RAN_TIMEOUT" 's=$SECONDS; RAN_TIMEOUT=1 ran bg bash -c "sleep 30 & echo hi" >/dev/null 2>&1; [ $(( SECONDS - s )) -lt 10 ]'
check "a child that outlives the command never holds open the output of a caller capturing ran.sh" 's=$SECONDS; x=$(ran capt bash -c "sleep 30 & echo hi" 2>&1); [ $(( SECONDS - s )) -lt 10 ] && grep -q "^hi$" <<<"$x"'
check "a command with no child left running ends ran.sh without the reader's one-second wait" 's=$(date +%s%N); ran quick true >/dev/null 2>&1; [ $(( ($(date +%s%N) - s) / 1000000 )) -lt 900 ]'
check "a child that outlives the command still writes to its output after ran.sh ends" 'rm -f "$dir/alive"; ran late bash -c "(sleep 2; echo late; echo survived > \"\$1\") & echo hi" _ "$dir/alive" >/dev/null 2>&1; sleep 3; [ "$(cat "$dir/alive" 2>/dev/null)" = survived ]'
check "a command that ignores TERM is killed after the grace" 's=$SECONDS; RAN_TIMEOUT=1 RAN_GRACE=1 ran term bash -c "trap \"\" TERM; sleep 30" >/dev/null 2>&1; r=$?; [ $(( SECONDS - s )) -lt 10 ] && [ $r = 137 ]'
check "a noisy command's log stops at RAN_MAX_BYTES" 'RAN_TIMEOUT=3 RAN_MAX_BYTES=4096 ran noisy yes >/dev/null 2>&1; [ -f "$dir/rt/s2/over-to-you-receipts/noisy.json" ] && [ -z "$(find "$dir/rt/s2/over-to-you-receipts" -name ".*" -type f)" ]'
check "a command ran.sh starts keeps its caller's file-size limit, so a server it starts can write its own files" '[ "$(ran fsize bash -c "ulimit -f" 2>/dev/null)" = "$(ulimit -f)" ]'
check "a command writes a file bigger than RAN_MAX_BYTES outside its log" 'RAN_MAX_BYTES=4096 ran bigfile bash -c "head -c 8192 /dev/zero > \"\$1\"" _ "$dir/bigfile" >/dev/null 2>&1; [ "$(wc -c < "$dir/bigfile")" = 8192 ]'
check "the output of a noisy command passes through only up to RAN_MAX_BYTES" '[ "$(RAN_TIMEOUT=3 RAN_MAX_BYTES=4096 ran noisy2 yes 2>/dev/null | wc -c)" -le 4096 ]'
# The stage: proven_by names a server, so a fresh liveness receipt must stand behind it.
# A log line can come from another server writing the same log.
stagespec() { jq -n --argjson extra "$1" '{name: "Bob", open: "x", signed_off: "n", proven_by: "dev stack up", sections: [{title: "P", items: [{"do": "Open the pack", "see": "the slots show", "person": "look", "ran": "r"}]}]} + $extra' > "$dir/spec.json"; }
stagespec '{}'
check "a server named with no stage receipt is refused, naming stage_ran" 'out=$(write); [ $? = 1 ] && grep -q "stage_ran" <<<"$out" && [ ! -e "$dir/out.md" ]'
fresh "$dir" logline "grep -q 'ALL SERVICES READY' logs/server.log"
stagespec '{"stage_ran": "logline"}'
check "a stage receipt that only reads a log is refused" 'out=$(write); [ $? = 1 ] && grep -q "reads a file" <<<"$out"'
receipt "$dir" old 0 "podman ps --filter name=app"; jq '.hold = 60' "$dir/over-to-you-receipts/old.json" > "$dir/o.json" && mv "$dir/o.json" "$dir/over-to-you-receipts/old.json"
stagespec '{"stage_ran": "old"}'
check "a stage receipt from long before the page is refused as stale" 'out=$(write); [ $? = 1 ] && grep -q "minutes" <<<"$out"'
receipt "$dir" down 1 "podman ps --filter name=app"
stagespec '{"stage_ran": "down"}'
check "a stage receipt that failed is refused" 'out=$(write); [ $? = 1 ] && grep -q "stage: receipt down exited 1" <<<"$out"'
for c in "tac logs/server.log" "pgrep app < logs/server.log" "timeout 5 wc -l logs/server.log" "/usr/bin/grep READY logs/server.log" "env grep READY logs/server.log" "sh -c 'tail logs/server.log'" "pgrep app; grep READY logs/server.log" "docker logs app"; do
  fresh "$dir" wrapped "$c"; stagespec '{"stage_ran": "wrapped"}'
  check "a stage receipt that reads a file inside \`$c\` is refused" 'out=$(write); [ $? = 1 ] && grep -q "reads a file" <<<"$out"'
done
for c in "pgrep -f tail" "curl -fs localhost:8080/cat"; do
  fresh "$dir" live "$c"; stagespec '{"stage_ran": "live"}'
  check "a liveness command whose argument names a reader, \`$c\`, passes" 'write >/dev/null && [ -s "$dir/out.md" ]'
done
jq -n '{id:"future", command:"podman ps --filter name=app", exit:0, at:"2099-01-01T00:00:00Z", head:"", cwd:"/", hold:60, tail:"Up"}' > "$dir/over-to-you-receipts/future.json"
stagespec '{"stage_ran": "future"}'
check "a stage receipt dated in the future is refused" 'out=$(write); [ $? = 1 ] && grep -q "future" <<<"$out"'
stagespec '{"stage_ran": "stage"}'
jq '.hold = 5' "$dir/over-to-you-receipts/stage.json" > "$dir/h.json"; mkdir -p "$dir/hq/over-to-you-receipts"; cp "$dir/over-to-you-receipts/"*.json "$dir/hq/over-to-you-receipts/"; cp "$dir/h.json" "$dir/hq/over-to-you-receipts/stage.json"; cp "$dir/spec.json" "$dir/hq/spec.json"
check "a stage receipt held under a minute is refused, naming RAN_HOLD" 'out=$(python3 -I "$skill/checklist.py" "$dir/hq/spec.json" "$dir/hq/out.md" 2>&1); [ $? = 1 ] && grep -q "RAN_HOLD=60" <<<"$out"'
check "a fresh liveness receipt lets the page write" 'write >/dev/null && [ -s "$dir/out.md" ]'
stagespec '{"proven_by": "no server"}'
check "no server needs no stage receipt" 'write >/dev/null && [ -s "$dir/out.md" ]'
# A repo's Stage check: line names the one liveness command.
repo="$dir/repo"; git init -q "$repo"; mkdir -p "$repo/docs/agents"
echo 'Stage check: `podman ps --filter name=app-dev`' > "$repo/docs/agents/testing.md"
mkdir -p "$dir/over-to-you-receipts"
jq -n --arg cwd "$repo" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"other", command:"curl -fs localhost:8080/health", exit:0, at:$at, head:"", cwd:$cwd, hold:60, tail:"ok"}' > "$dir/over-to-you-receipts/other.json"
jq -n --arg cwd "$repo" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"named", command:"podman ps --filter name=app-dev", exit:0, at:$at, head:"", cwd:$cwd, hold:60, tail:"Up"}' > "$dir/over-to-you-receipts/named.json"
stagespec '{"stage_ran": "other"}'
check "a stage receipt that skips the repo's Stage check command is refused, naming it" 'out=$(write); [ $? = 1 ] && grep -qF "podman ps --filter name=app-dev" <<<"$out"'
jq -n --arg cwd "$repo" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"around", command:"pgrep x # podman ps --filter name=app-dev", exit:0, at:$at, head:"", cwd:$cwd, hold:60, tail:"1"}' > "$dir/over-to-you-receipts/around.json"
stagespec '{"stage_ran": "around"}'
check "a stage receipt that only holds the Stage check command inside another is refused" 'out=$(write); [ $? = 1 ] && grep -qF "not the repo" <<<"$out"'
fresh "$dir" outside "pgrep app"
stagespec '{"stage_ran": "outside"}'
check "a receipt run outside any repo reads no Stage check line, even from a repo's folder" '(cd "$repo" && python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/out.md" >/dev/null 2>&1) && [ -s "$dir/out.md" ]'
stagespec '{"stage_ran": "named"}'
check "the repo's Stage check command passes" 'write >/dev/null && [ -s "$dir/out.md" ]'
jq -n --arg at "not a time" '{id:"badtime", command:"podman ps", exit:0, at:$at, head:"", cwd:"/", tail:"Up"}' > "$dir/over-to-you-receipts/badtime.json"
stagespec '{"stage_ran": "badtime"}'
check "a stage receipt whose time cannot be read is refused as stale" 'out=$(write); [ $? = 1 ] && grep -q "minutes ago" <<<"$out"'
bare="$dir/bare"; git init -q "$bare"
jq -n --arg cwd "$bare" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"bare", command:"podman ps", exit:0, at:$at, head:"", cwd:$cwd, hold:60, tail:"Up"}' > "$dir/over-to-you-receipts/bare.json"
stagespec '{"stage_ran": "bare"}'
check "a repo with no testing.md takes any liveness command" 'write >/dev/null && [ -s "$dir/out.md" ]'
plain="$dir/plain"; git init -q "$plain"; mkdir -p "$plain/docs/agents"; echo 'Testing standards: TESTING.md' > "$plain/docs/agents/testing.md"
jq -n --arg cwd "$plain" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"plain", command:"pgrep app", exit:0, at:$at, head:"", cwd:$cwd, hold:60, tail:"1"}' > "$dir/over-to-you-receipts/plain.json"
stagespec '{"stage_ran": "plain"}'
check "a testing.md with no Stage check line takes any liveness command" 'write >/dev/null && [ -s "$dir/out.md" ]'
off="$dir/off"; git init -q "$off"; mkdir -p "$off/docs/agents"; echo 'Stage check: None.' > "$off/docs/agents/testing.md"
stagespec '{}'
cp -r "$dir/over-to-you-receipts" "$off/"
check "a Stage check line of none, run from the repo with the page in scratch, needs no stage receipt" 'rm -f "$dir/out.md"; (cd "$off" && python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/out.md" >/dev/null 2>&1) && [ -s "$dir/out.md" ]'
quoted="$dir/quoted"; git init -q "$quoted"; mkdir -p "$quoted/docs/agents"; printf 'Stage check: `pgrep -f "dev server"` (the dev server)\n' > "$quoted/docs/agents/testing.md"
jq -n --arg cwd "$quoted" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"q", command:"pgrep -f dev server", exit:0, at:$at, head:"", cwd:$cwd, hold:60, tail:"1"}' > "$dir/over-to-you-receipts/q.json"
stagespec '{"stage_ran": "q"}'
check "a Stage check in backticks with quoted words and a note after it matches ran.sh's record of it" 'write >/dev/null && [ -s "$dir/out.md" ]'
odd="$dir/odd"; git init -q "$odd"; mkdir -p "$odd/docs/agents"; printf 'Stage check: pgrep -f "dev\n' > "$odd/docs/agents/testing.md"
jq -n --arg cwd "$odd" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"odd", command:"pgrep -f \"dev", exit:0, at:$at, head:"", cwd:$cwd, hold:60, tail:"1"}' > "$dir/over-to-you-receipts/odd.json"
stagespec '{"stage_ran": "odd"}'
check "a Stage check with an unclosed quote still matches the same command" 'write >/dev/null && [ -s "$dir/out.md" ]'
check "a repo whose Stage check line says none needs no stage receipt" 'rm -f "$off/out.md"; python3 -I "$skill/checklist.py" "$dir/spec.json" "$off/out.md" >/dev/null 2>&1; [ -s "$off/out.md" ]'
exit $fail
