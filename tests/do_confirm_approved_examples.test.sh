#!/usr/bin/env bash
# approved-spec: the do confirmation examples, approved 2026-11-02. The hint
# hook runs on a typed prompt the way Claude Code sends one, and take-pick
# runs on a fixture transcript.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
hint="$root/scripts/do-confirm-hint.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# A typed slash command, as the prompt Claude Code hands the hook.
typed() { jq -nc --arg p "<command-message>vicky-skills:$1</command-message>
<command-name>/vicky-skills:$1</command-name>
<command-args>$2</command-args>" '{hook_event_name:"UserPromptSubmit",prompt:$p}' | bash "$hint" 2>/dev/null; }
said() { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }

# Given you type /do with an objective your own words already state in full
# When the agent starts
# Then it says "Going with: <the objective>" and builds, with no gate
check "a stated objective is taken, not asked" '[ -f "$hint" ] && out=$(typed do "zip every download on the CDN" | said) && grep -q "Going with: " <<<"$out" && ! grep -q "🚪 Waiting on you" <<<"$out"'

# Given you type /do with an objective it has to read into, such as a question or a maybe
# When the agent starts
# Then its first message is a gate that says the objective back to you, and it builds nothing until you answer
check "an objective read into is confirmed first" '[ -f "$hint" ] && typed do "can every download be zipped, maybe by the CDN" | said | grep -q "🚪 Waiting on you" && grep -q "Confirm the objective" "$root/skills/engineering/do/SKILL.md"'

# Given you type /do with a ticket, or start a warp through a star chart
# When the agent starts
# Then it goes straight to the examples, with no confirmation gate
ok=1
for a in "GAME-12" "#87" "vicky-skills/20261102150016 do opens with one confirmation question.md" "the Star Chart - export"; do
  [ -z "$(typed do "$a")" ] || ok=0
done
[ -z "$(typed warp "export the depot")" ] || ok=0
check "a ticket or a chart skips the confirmation" '[ -f "$hint" ] && [ $ok = 1 ]'

# Given you confirmed a /do objective
# When the agent meets a later choice that is cheap to undo
# Then it takes its pick and says "Going with", as usual
{ jq -nc '{type:"user",message:{content:"yes, zip them"}}'
  jq -nc '{type:"assistant",message:{content:[{type:"text",text:"Gzip or deflate? My pick is gzip."}]}}'; } > "$fx/t.jsonl"
check "only the first question waits for you" 'typed do "zip every download" | said | grep -q "Going with" && jq -nc --arg t "$fx/t.jsonl" "{stop_hook_active:false,transcript_path:\$t}" | CLAUDE_PLUGIN_OPTION_GUARD_TAKE_PICK=true bash "$root/scripts/take-pick.sh" | grep -q block'
exit $fail
