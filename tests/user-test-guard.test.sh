#!/usr/bin/env bash
# user-test-guard sends back a reply, and refuses a SendUserMessage, that hands
# the user a test in chat, unless the turn opened an over-to-you checklist.
# shellcheck disable=SC2016,SC2181,SC2329 # each check is a string check() evals, so its functions and its \$ signs look unused
set -u
export VISUAL=false EDITOR=false
# The opener names below are fixture text in a transcript; no page opens.
page_opener=open-page
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/user-test-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
bash_call() { jq -nc --arg c "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}}'; }
export TMPDIR="$fx/tmp"; mkdir -p "$fx/tmp/s1"
marker="$fx/tmp/s1/over-to-you-opened"
stop() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{hook_event_name:"Stop",session_id:"s1",stop_hook_active:$a,transcript_path:$t}' \
  | CLAUDE_PLUGIN_DATA="$fx/data" CLAUDE_PLUGIN_OPTION_GUARD_USER_TEST="${opt-}" bash "$hook" 2>/dev/null; }
send() { jq -nc --arg t "$fx/t.jsonl" --arg m "$1" '{hook_event_name:"PreToolUse",session_id:"s1",tool_name:"SendUserMessage",tool_input:{message:$m},transcript_path:$t}' \
  | CLAUDE_PLUGIN_OPTION_GUARD_USER_TEST="${opt-}" bash "$hook" 2>&1; }
sent_back() { rm -rf "$fx/data"; [ "$(stop | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; rm -rf "$fx/data"; out=$(stop "${1:-false}"); [ $? = 0 ] && [ -z "$out" ]; }
refused() { local out; out=$(send "$1"); [ $? = 2 ] && [[ $out == *over-to-you* ]]; }
sent() { local out; out=$(send "$1"); [ $? = 0 ] && [ -z "$out" ]; }

# Hand-offs seen in real sessions, retold.
red=("The test server is up. Test it like this: 1. Connect to the local server and pick a character. 2. Walk around."
     "Yes, you can test now. 1. Start the game and join the dev server. 2. Click the swatch."
     "Both branches are in your checkout. It is merged, so you can test it from this local branch."
     "To try it yourself once it's live, open the Downloads page and press Download selected."
     "Steps to verify: open the panel and press Save."
     "Please check that the icon shows in the inventory."
     "Let me know if it works."
     "When you test it, open the map first."
     "Could you try the new door in the tavern?"
     "Before I push it, please re-check the helmet in game."
     "Test it by joining the server."
     "Give it a go and tell me what you see."
     "Take it for a spin."
     "Here is how to try it: start the server and connect."
     "Please play through the quest."
     "Could you load the module and report back?"
     "Run the kit and confirm the door opens."
     "Steps: 1. Open the client 2. Click the door."
     "Once you have pulled this branch, try logging in.")
for r in "${red[@]}"; do
  { user "go"; text "$r"; } > "$fx/t.jsonl"
  check "a chat hand-off is sent back: ${r:0:50}" 'sent_back'
  check "the same hand-off by SendUserMessage is refused: ${r:0:50}" 'refused "$r"'
done
# The agent's own plans and other gates.
green=("I'd test it with a shader that declares 80 parameters."
       "Now build the job image and test it locally under a memory cap."
       "🚪 Waiting on you: the drafts page at http://127.0.0.1:4000/. Pressing Done sends your edits back."
       "🚪 Waiting on you: merge !240. It shows as mergeable."
       "The frame is fixed in all three mockups. Reload the page to see it."
       "Moving one subpage first to test."
       "Next I'll check that the icon loads, then verify it in the client."
       "The CI diff only adds four test steps."
       "Upstream ships one file per release, and you can check that on its releases page."
       "Merged. Every check passed."
       "Could you confirm the ticket name?"
       "Three reviewers run now, and I'll fix what they find when they report back."
       "The run log has three steps: 1. build, 2. test, 3. deploy.")
for g in "${green[@]}"; do
  { user "go"; text "$g"; } > "$fx/t.jsonl"
  check "no hand-off goes through: ${g:0:50}" 'passes'
  check "no hand-off is sent: ${g:0:50}" 'sent "$g"'
done
{ user "go"; text 'The guard reads lines like `test it like this`.'; } > "$fx/t.jsonl"
check "a hand-off inside backticks is quoted code" 'passes'
check "a hand-off inside backticks is sent" 'sent "The guard reads \`let me know if it works\`."'

{ jq -nc --arg ts "$(date -u +%FT%TZ)" '{type:"user",timestamp:$ts,message:{content:"go"}}'; text "Let me know if it works."; } > "$fx/t.jsonl"
good="$fx/tmp/s1/over-to-you-door.md"
printf '# Door\nproven by: kit.sh, green\n## Door\n1. [ ] Open the door → it opens\n   person: look\n   ran: `kit.sh` exit 0 at 2026-01-01T00:00:00Z\n' > "$good"
python3 -I "$root/plugins/vicky-skills/skills/building/over-to-you/scripts/lint-checklist.py" "$good" >/dev/null 2>&1 || echo "FAIL fixture checklist does not lint"
sleep 30 & live=$!
echo "$live 1 $good" > "$marker"
check "a checklist page still open lets the reply through" 'passes'
check "a checklist page still open lets the message through" 'sent "Please check that the door opens."'
echo "$live 1" > "$marker"
check "a marker with no checklist named is sent back" 'sent_back'
grep -v 'ran:' "$good" > "$fx/tmp/s1/over-to-you-bad.md"
echo "$live 1 $fx/tmp/s1/over-to-you-bad.md" > "$marker"
check "a marker naming a checklist that fails its lint is sent back" 'sent_back'
echo "$live 1 $fx/t.jsonl" > "$marker"
check "a marker naming a file that is no checklist is refused" 'refused "Let me know if it works."'
echo "$live 1 $good" > "$marker"
kill "$live"; wait "$live" 2>/dev/null
echo "999999999 $(date +%s) $good" > "$marker"
check "a checklist opened this turn and closed lets it through" 'passes'
{ jq -nc --arg ts "$(date -u -d "+1 hour" +%FT%TZ)" '{type:"user",timestamp:$ts,message:{content:"and the window?"}}'; text "Let me know if it works."; } > "$fx/t.jsonl"
check "a closed checklist opened before the user's last message is old" 'sent_back'
check "a SendUserMessage after an old closed checklist is refused" 'refused "Let me know if it works."'
rm -f "$marker"
{ user "go"; bash_call "bash skills/writing/interactive-page/scripts/$page_opener.sh /tmp/s1/over-to-you-door.md"; text "Let me know if it works."; } > "$fx/t.jsonl"
check "a command that only names the opener, with no marker, is sent back" 'sent_back'

# The door line is the reply's one ask. Door lines seen in real sessions, retold.
door_red=("🚪 Waiting on you: open Appearance in character creation and look at Chest. Tile 5 should show the preview."
          "🚪 Waiting on you: connect to \`localhost:5121\`, open Appearance, and look at Chest tile 5."
          "🚪 Waiting on you: close the dressing window and open it again with \`/dressing\`. Then look at Torso."
          "🚪 Waiting on you: reopen \`/dressing\`. Paging back to page 1 should work now."
          "🚪 Waiting on you: load \`the_field\` from the modules list and walk the field."
          "🚪 **Waiting on you:** the test module is ready to look at. It holds all 79 animals."
          "🚪 **Waiting on you:** reopen \`the_field\`. It now holds 103 animals."
          "🚪 Waiting on you: say go, then open the window and look at tile 5."
          "🚪 Waiting on you: I reopened it. Please look at tile 5."
          "🚪 Waiting on you: open it in your browser and look at it.")
for d in "${door_red[@]}"; do
  { user "go"; text "$d"; } > "$fx/t.jsonl"
  check "a door line that sends the user to look is sent back: $d" 'sent_back'
done
check "a door line sent with SendUserMessage is refused" 'refused "🚪 Waiting on you: reopen the window and look at the tile."'
{ user "go"; text "🚪 Waiting on you: reopen the window. It should page back now."; } > "$fx/t.jsonl"
check "the reason quotes the door line's order" '[[ "$(rm -rf "$fx/data"; stop)" == *"reopen the window"* ]]'
door_green=("🚪 Waiting on you: Go renderer or Blender? Answer one word in chat."
            "🚪 Waiting on you: type \`! make up\` from the repo root."
            "🚪 Waiting on you: say \"open it\" and I open the pull request."
            "🚪 Waiting on you: say \"go\" when your check is done."
            "🚪 Waiting on you: is the grey mannequin the right look? Answer in chat."
            "🚪 Waiting on you: if it is ready for review, run \`! tea pr edit 7 -t x\`."
            "🚪 Waiting on you: the draft is open in your browser. Close it when it reads right."
            "🚪 Waiting on you: nothing. Open items: none.")
for d in "${door_green[@]}"; do
  { user "go"; text "$d"; } > "$fx/t.jsonl"
  check "a door line that asks for an answer goes through: $d" 'passes'
done
for d in "🚪 Waiting on you: say \"go\" to draft the examples and open the page." \
         "🚪 Waiting on you: paste this to mark it ready. I'll close and reopen it to start the run." \
         "🚪 Waiting on you: reopen the ticket as a prototype, yes or no? My pick is yes." \
         "🚪 Waiting on you: open the drafts page at http://127.0.0.1:1/ and press Done when you're finished." \
         "🚪 Waiting on you: sitting 2 is open in your editor. Close it and I'll record your verdicts."; do
  { user "go"; text "$d"; } > "$fx/t.jsonl"
  check "a door line for an answer, the agent's own step or a page gate goes through: $d" 'passes'
done
{ user "go"; text "🚪 Waiting on you: reopen the window and look."; text "🚪 Waiting on you: nothing. I ran each check myself."; } > "$fx/t.jsonl"
check "a corrected door line later in the turn goes through" 'passes'
{ user "go"; text "🚪 Waiting on you: say go."; text "🚪 Waiting on you: reopen the window and look."; } > "$fx/t.jsonl"
check "the last door line is the one read" 'sent_back'
{ user "go"; text "I had to reopen the file and look at line 5. Fixed and pushed."; } > "$fx/t.jsonl"
check "the same words outside the door line go through" 'passes'

{ user "go"; text "Let me know if it works."; } > "$fx/t.jsonl"
check "the reason names over-to-you and ran.sh" '[[ "$(rm -rf "$fx/data"; stop)" == *over-to-you*ran.sh* ]]'
check "the reason quotes the hand-off" '[[ "$(rm -rf "$fx/data"; stop)" == *"Let me know if it works"* ]]'
rm -rf "$fx/data"
check "the second stop of a turn is sent back again" '[ "$(stop true | jq -r .decision)" = block ]'
stop true >/dev/null; stop true >/dev/null
check "after three send-backs in one turn the stop goes through" 'out=$(stop true); [ $? = 0 ] && [ -z "$out" ]'
jq -nc '{type:"user",timestamp:"2026-01-01T00:05:00Z",message:{content:[{type:"tool_result",tool_use_id:"x",content:"ok"}]}}' >> "$fx/t.jsonl"; text "Let me know if it works." >> "$fx/t.jsonl"
check "a tool result between stops keeps the count" '[ -z "$(stop true)" ]'
jq -nc '{type:"user",timestamp:"2026-01-01T00:00:00Z",message:{content:"next"}}' >> "$fx/t.jsonl"; text "Let me know if it works." >> "$fx/t.jsonl"
check "a new user message starts a new count" '[ "$(stop true | jq -r .decision)" = block ]'
check "a missing transcript goes through" 'rm -f "$fx/t.jsonl"; passes'
check "a SendUserMessage with no transcript is still read" 'refused "Let me know if it works."'
check "another tool goes through" '[ -z "$(jq -nc "{hook_event_name:\"PreToolUse\",tool_name:\"Bash\",tool_input:{command:\"echo hi\",message:\"Let me know if it works.\"}}" | bash "$hook" 2>&1)" ]'
check "bad input goes through" '[ -z "$(echo "not json" | bash "$hook" 2>&1)" ]'
{ user "go"; text "Let me know if it works."; } > "$fx/t.jsonl"
opt=false; check "the setting off lets it through" 'passes'
opt=0; check "the setting 0 lets it through" 'sent "Let me know if it works."'
opt=true; check "the setting on sends it back" 'sent_back'
unset opt
mkdir -p "$fx/nobin"; for t in bash cat sed grep tail head; do ln -s "$(command -v "$t")" "$fx/nobin/$t"; done
check "without jq it goes through and says the guard is off" 'out=$(jq -nc --arg t "$fx/t.jsonl" "{hook_event_name:\"Stop\",transcript_path:\$t}" | PATH="$fx/nobin" bash "$hook" 2>&1); [ $? = 0 ] && [[ $out == *"jq is missing"* ]] && [[ $out != *block* ]]'
exit $fail
