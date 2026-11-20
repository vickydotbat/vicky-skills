#!/usr/bin/env bash
# checklist.py writes the over-to-you checklist from a spec in the one form the
# page reads, and refuses a spec it can't write without breaking that form.
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
spec() { # items json -> spec file; an item with no ran names the receipt r
  jq -n --argjson items "$(jq 'map(.ran //= "r")' <<<"$1")" '{name: "Bob", brief: ["One sitting for the pack."], open: "Open the client on the branch.",
    signed_off: "nothing yet", proven_by: "`health.sh` answers ok", sections: [{title: "Pack", items: $items}]}' > "$dir/spec.json"
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
jq -n --argjson i '[{"do": "Open the pack", "see": "the slots show", "person": "look", "ran": "r"}]' '{name: "Bob", open: "x", signed_off: "n", proven_by: "p", sitting: [2, 3], sections: [{title: "P", items: $i}]}' > "$dir/spec.json"
check "a numbered sitting says which one it is" 'write >/dev/null && grep -qx "Sitting 2 of 3." "$dir/out.md"'
check "a wrong call prints its usage and exits 2" 'python3 -I "$skill/checklist.py" 2>/dev/null; [ $? = 2 ]'
mkdir -p "$dir/tmp/s1"
receipt "$dir/tmp/s1" r 0 "harness.sh"
receipt "$dir/tmp" r 0 "harness.sh" # so only the loose-folder rule stops the next write
spec "[$item]"
out=$(env TMPDIR="$dir/tmp" CLAUDE_CODE_SESSION_ID=s1 python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/tmp/over-to-you-x.md" 2>&1); rc=$?
check "a checklist loose in the shared temp folder is refused, naming the session folder" '[ $rc = 1 ] && grep -q "tmp/s1" <<<"$out" && [ ! -e "$dir/tmp/over-to-you-x.md" ]'
env TMPDIR="$dir/tmp" CLAUDE_CODE_SESSION_ID=s1 python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/tmp/s1/over-to-you-x.md" >/dev/null
check "a checklist in the session folder is written" '[ -s "$dir/tmp/s1/over-to-you-x.md" ]'
# The whole file for a full spec: a one-line brief, two sections, a kit and its source, and extra tests.
jq -n '{name: "Bob", brief: "One sitting.", open: "Open the client.", signed_off: "nothing yet", proven_by: "`health.sh` answers ok", extra: "Try the bank too.", sections: [{title: "Pack", items: [{do: "Open the pack", see: "the slots show", person: "look", ran: "r"}]}, {title: "Paper", items: [{do: "Spawn the paper", see: "the sheet shows", person: "real client", kit: "`/runscript paper` in the game chat", source: "the module scripts", ran: "r"}]}]}' > "$dir/spec.json"
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
check "a receipt that does not hold the kit is refused" 'out=$(write); [ $? = 1 ] && grep -q "does not hold the kit" <<<"$out"'
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
mkdir -p "$dir/nojq"; for t in bash timeout tee git date mktemp tail mkdir rm true; do ln -s "$(command -v "$t")" "$dir/nojq/$t"; done
check "ran.sh without jq stops before it runs the command" 'out=$(env PATH="$dir/nojq" TMPDIR="$dir/rt" CLAUDE_CODE_SESSION_ID=s2 bash "$skill/ran.sh" nj bash -c "echo ran-it" 2>&1); [ $? = 2 ] && grep -q "jq is missing" <<<"$out" && ! grep -q ran-it <<<"$out"'
check "ran.sh refuses with no session id" 'env -u CLAUDE_CODE_SESSION_ID bash "$skill/ran.sh" x true 2>/dev/null; [ $? = 2 ]'
check "ran.sh with too few arguments prints its usage and exits 2" 'out=$(bash "$skill/ran.sh" x 2>&1); [ $? = 2 ] && grep -q "^usage: ran.sh" <<<"$out"'
mkdir -p "$dir/rt/s2"; jq -n '{name: "Bob", open: "x", signed_off: "n", proven_by: "p", sections: [{title: "P", items: [{do: "Open the pack", see: "the slots show", person: "look", ran: "ok"}]}]}' > "$dir/spec.json"
check "a receipt ran.sh wrote opens the way to the checklist" 'env TMPDIR="$dir/rt" CLAUDE_CODE_SESSION_ID=s2 python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/rt/s2/over-to-you-ok.md" && grep -q "^   ran: .bash -c echo hello; exit 0. exit 0" "$dir/rt/s2/over-to-you-ok.md"'
# The page opener refuses a checklist typed by hand.
printf '# Over to you, Bob!\nproven by: p\n1. [ ] Open the pack → the slots show\n   person: look\n' > "$dir/rt/s2/over-to-you-hand.md"
check "open-page refuses a hand-typed checklist with no ran lines" 'out=$(VISUAL=true bash "$page/open-draft.sh" "$dir/rt/s2/over-to-you-hand.md" 2>&1); [ $? = 2 ] && grep -q "page stays shut" <<<"$out"'
check "open-page opens a checklist checklist.py wrote" '(cd "$dir" && VISUAL=true bash "$page/open-draft.sh" "$dir/rt/s2/over-to-you-ok.md" >/dev/null 2>&1)'
exit $fail
"'"'\n'"'"'* ]]'
check "ran.sh refuses with no session id" 'env -u CLAUDE_CODE_SESSION_ID bash "$skill/ran.sh" x true 2>/dev/null; [ $? = 2 ]'
check "ran.sh with too few arguments prints its usage" 'bash "$skill/ran.sh" x 2>&1 | grep -q "^usage: ran.sh"'
mkdir -p "$dir/rt/s2"; jq -n '{name: "Bob", open: "x", signed_off: "n", proven_by: "p", sections: [{title: "P", items: [{do: "Open the pack", see: "the slots show", person: "look", ran: "ok"}]}]}' > "$dir/spec.json"
check "a receipt ran.sh wrote opens the way to the checklist" 'env TMPDIR="$dir/rt" CLAUDE_CODE_SESSION_ID=s2 python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/rt/s2/over-to-you-ok.md" && grep -q "^   ran: .bash -c echo hello; exit 0. exit 0" "$dir/rt/s2/over-to-you-ok.md"'
# The page opener refuses a checklist typed by hand.
printf '# Over to you, Bob!\nproven by: p\n1. [ ] Open the pack → the slots show\n   person: look\n' > "$dir/rt/s2/over-to-you-hand.md"
check "open-page refuses a hand-typed checklist with no ran lines" 'out=$(VISUAL=true bash "$page/open-draft.sh" "$dir/rt/s2/over-to-you-hand.md" 2>&1); [ $? = 2 ] && grep -q "page stays shut" <<<"$out"'
check "open-page opens a checklist checklist.py wrote" '(cd "$dir" && VISUAL=true bash "$page/open-draft.sh" "$dir/rt/s2/over-to-you-ok.md" >/dev/null 2>&1)'
exit $fail
