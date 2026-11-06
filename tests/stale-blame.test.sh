#!/usr/bin/env bash
# The stale-blame hook: a reply that blames the user's copy as stale, or tells
# them to update it, with no hash or logged version, is sent back once; a reply
# with proof, one that blames nothing of theirs, the setting off, and bad input
# go through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/stale-blame.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
unset CLAUDE_PLUGIN_OPTION_GUARD_STALE_BLAME
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sent() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
stop() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' | bash "$hook"; }
passes() { local out; out=$(stop "$@"); [ $? = 0 ] && [ -z "$out" ]; }
blocked() { stop | jq -e '.decision == "block"' >/dev/null 2>&1; }
# Given a reply that blames the user's copy with no proof
# When the agent stops
# Then the stop is blocked once with a steer to keep tracing
{ user "retest failed"; sent "The retest ran on your stale hak: it changed at 10:51 and the kit ran at 10:07."; } > "$fx/t.jsonl"
check "a stale-copy blame with only times is sent back" 'blocked'
check "a sent-back stop exits 0" 'stop >/dev/null; [ $? = 0 ]'
check "the steer quotes the sentence" 'stop | jq -r .reason | grep -q "your stale hak"'
check "the steer says to keep tracing the code" 'stop | jq -r .reason | grep -q "Keep tracing the bug in the code"'
check "a second stop in the same turn goes through" 'passes true'
for p in "Your new file passes every check." "Clear the cache in the script, not your build." "Your latest commit is on the branch."; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "an ordinary sentence about the user's things goes through: $p" 'passes'
done
for p in "Your client is out of date." "Please redownload your build and try again." "Restart your client to pick it up." "Your haks are outdated."; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "each blame form counts: $p" 'blocked'
done
{ user "go"; text "Your hak dated 20261103 is old."; } > "$fx/t.jsonl"
check "a date is no hash" 'blocked'
for p in "Try reloading your client." "The hak you have is older than the fix." "Grab the latest build, you were on a previous version."; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "each blame form counts: $p" 'blocked'
done
{ user "go"; text "The loop hit the instruction limit. Nothing here says your client is outdated."; } > "$fx/t.jsonl"
check "a denied blame goes through" 'passes'
{ user "go"; text "The run loaded 3fa9c1, the release is 91bd07, so your hak is stale."; } > "$fx/t.jsonl"
check "a six-character hash pair goes through" 'passes'
for p in "Your haks might be behind." "Make sure you've pulled the new hak before retesting." "Probably a caching issue on your end." "The client is likely still on the old files." "Did you update?"; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "each blame form counts: $p" 'blocked'
done
for p in "I suspect you are running an outdated build." "The haks on your machine haven't been refreshed."; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "each blame form counts: $p" 'blocked'
done
for p in "Your browser cache is probably stale." "Reinstall your dependencies, they look outdated." "Your container image is behind."; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "each copy outside games counts: $p" 'blocked'
done
# Given a reply with proof, or one that blames nothing of the user's
# When the agent stops
# Then it goes through
{ user "go"; sent "The failing run loaded hak 3fa9c21e, the release is 9b01d4ce, so your hak is stale."; } > "$fx/t.jsonl"
check "a quoted hash pair goes through" 'passes'
{ user "go"; sent "The server log shows version 1.4 loaded, the release is 1.6, so your client is old."; } > "$fx/t.jsonl"
check "a logged version goes through" 'passes'
for p in "Start the client fully, since a shader change needs a restart." "Close the client: an atlas change requires a full restart." "The client takes a fresh restart for new shaders, so start it before step 2."; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "a restart the engine needs, stated as a rule, goes through: $p" 'passes'
done
for p in "Your client is probably running the old shader, restart it." "The client needs a restart because your build is stale." "Your client needs a restart."; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "blame beside a rule still counts: $p" 'blocked'
done
{ user "go"; text "The cache in the build script was stale, so I fixed it."; } > "$fx/t.jsonl"
check "a stale word with no copy of theirs goes through" 'passes'
{ user "go"; text "Your build passed, and the fix is in."; } > "$fx/t.jsonl"
check "their copy with no stale word goes through" 'passes'
{ user "go"; text "Your hak is fine."; text "The old loop was the bug."; } > "$fx/t.jsonl"
check "the copy and the stale word in different sentences go through" 'passes'
{ user "go"; text 'The hook matches `your hak is stale`.'; } > "$fx/t.jsonl"
{ user "go"; text 'The fix makes "Your client needs a restart" trip again.'; } > "$fx/t.jsonl"
check "a blame quoted in double quotes is no blame" 'passes'
check "a blame quoted in backticks is no blame" 'passes'
{ user "go"; text "Your hak is stale."; user "no it is not"; text "Tracing the code."; } > "$fx/t.jsonl"
check "a blame before the user's last message is not read again" 'passes'
check "the setting off lets it through" '{ user "go"; text "Your hak is stale."; } > "$fx/t.jsonl"; CLAUDE_PLUGIN_OPTION_GUARD_STALE_BLAME=false passes'
check "the setting 0 lets it through" '{ user "go"; text "Your hak is stale."; } > "$fx/t.jsonl"; CLAUDE_PLUGIN_OPTION_GUARD_STALE_BLAME=0 passes'
check "the setting true still checks" '{ user "go"; text "Your hak is stale."; } > "$fx/t.jsonl"; CLAUDE_PLUGIN_OPTION_GUARD_STALE_BLAME=true blocked'
check "a missing transcript goes through" 'out=$(jq -nc "{transcript_path:\"$fx/none\"}" | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "bad input goes through" 'out=$(echo "not json" | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "the session's own older skills is no blame" '{ user "why"; text "This session is still running an older copy of the skills. A restart picks up the version you have installed."; } > "$fx/t.jsonl"; passes'
check "an older session blamed on the user's plugin still blocks" '{ user "why"; text "Your plugin is stale in this session."; } > "$fx/t.jsonl"; blocked'
# A comparison that says two builds match, and a retelling of an earlier claim, blame nothing.
for ok in "The old build looks the same as your current build." "The old and new caps are identical in your build." "That roof edge matches your current build, so the fault is in the code." "I told you your client was stale, and that was wrong." "I said your cache was old; correction, it was current." "We blamed your old build, which was wrong."; do
  { user "go"; text "$ok"; } > "$fx/t.jsonl"
  check "a comparison or a retelling goes through: $ok" 'passes'
done
{ user "go"; text "The old build is on your machine, so it looks stale."; } > "$fx/t.jsonl"
check "a real stale claim with no comparison word is still sent back" 'blocked'
{ user "go"; text "Correct me if wrong, but your build is stale."; } > "$fx/t.jsonl"
check "the word correct alone is no retelling" 'blocked'
exit $fail
