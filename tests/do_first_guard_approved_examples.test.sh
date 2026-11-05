#!/usr/bin/env bash
# approved-spec: the examples the user ticked on 2026-11-05 for "Examples
# approval is verified, not claimed": a do build edits production code only
# once the user ticked its examples on a page, or a found-work line carries
# its drafted example. The agent's own claim of approval counts for nothing.
set -u
export VISUAL=true EDITOR=true
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/do-first-guard.sh"
opener="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts/open-draft.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"
git init -q -b main "$repo"; mkdir -p "$repo/src"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m start
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
sk() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
say() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
# The guard's decision on an edit to production code, "allow" when it lets it through.
edit() {
  local out code
  out=$(jq -n --arg f "$repo/src/app.py" --arg t "$1" '{tool_name:"Edit",tool_input:{file_path:$f},transcript_path:$t}' |
    CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$hook"); code=$?
  [ "$code" = 0 ] || { echo "exit $code"; return; }
  jq -r '.hookSpecificOutput.permissionDecision // "allow"' <<<"${out:-{\}}"
}
# The user opens the examples page in the repo and ticks each approve box before Done.
tick_on_page() {
  printf '# Drafts: build\n\nPress Done to send the text back.\n\n## E1 an example\nticket: new\n- [ ] approve\n\n```text\nGiven a thing\n```\n' > "$dir/drafts.md"
  printf '#!/bin/sh\nsed -i "s/- \\[ \\] approve/- [x] approve/" "$1"\n' > "$dir/tick.sh"
  (cd "$repo" && EDITOR="sh $dir/tick.sh" VISUAL="" bash "$opener" "$dir/drafts.md") >/dev/null 2>&1
}

# Given a build whose examples the user never ticked
# When the agent edits production code, after writing "Examples: approved on <ticket>"
# Then the edit is refused
{ sk vicky-skills:do; say "Examples: approved on GAME-12"; } > "$dir/claimed.jsonl"
check "E1 a claimed approval is refused" deny "$(edit "$dir/claimed.jsonl")"

# Given found work (a review finding, a bug a test caught) whose example the agent has drafted as Given, When and Then text
# When the agent edits production code, with no tick on any page
# Then the edit goes through, since found work needs no approval, and the report lists it under Tested unasked
{ sk vicky-skills:do; say "Examples: none, because found work: the parser drops a trailing tab
Given a line that ends in a tab
When the parser reads it
Then the tab is kept"; } > "$dir/found.jsonl"
check "E3 found work with a drafted example goes through" allow "$(edit "$dir/found.jsonl")"

# Given found work with no drafted example
# When the agent edits production code
# Then the edit is refused, because found work is drafted before it is built, only never ticked
{ sk vicky-skills:do; say "Examples: none, because found work: the parser drops a trailing tab"; } > "$dir/found-bare.jsonl"
check "E3b found work with no drafted example is refused" deny "$(edit "$dir/found-bare.jsonl")"

# Given examples ticked for another branch only
# When a new session edits production code on this branch
# Then the edit is refused
git -C "$repo" switch -q -c other
tick_on_page
git -C "$repo" switch -q main
sk vicky-skills:do > "$dir/resumed.jsonl"
check "E4b a tick on another branch does not count" deny "$(edit "$dir/resumed.jsonl")"

# Given the user ticked the build's examples on the page and pressed Done
# When the agent edits production code
# Then the edit goes through, with no reply line needed
{ sk vicky-skills:do; sk vicky-skills:examples; } > "$dir/ticked.jsonl"
tick_on_page
check "E2 a ticked page lets the build through" allow "$(edit "$dir/ticked.jsonl")"

# Given a resumed build whose examples an earlier session had ticked, on the same branch
# When the agent edits production code
# Then the edit goes through
check "E4 a resumed build sees an earlier tick" allow "$(edit "$dir/resumed.jsonl")"

exit $fail
