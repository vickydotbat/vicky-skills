#!/usr/bin/env bash
# The visibility probe's window and edge cases, and the watch's read-once
# mode: regression tests beside the probe's approved examples.
set -u
here="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/familiar/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/notes" "$dir/corpus/-p"
printf '{"type":"assistant","timestamp":"2026-11-04T12:42:10Z","message":{"content":[{"type":"tool_use","id":"t","name":"Skill","input":{"skill":"vicky-skills:do"}}]}}\n' > "$dir/corpus/-p/cccc3333-x.jsonl"
printf -- '- S1 12:43: one minute after\n- S2 12:44: two minutes after\n- S3 12:41: one minute before\n' > "$dir/notes/2026 Familiar debt cccc3333.md"
out=$(python3 "$here/familiar-visibility.py" "$dir/notes" "$dir/corpus")
check "a line one minute after an event is visible" 'grep -qx "cccc3333 S1 12:43 visible" <<<"$out"'
check "a line one minute before an event is visible" 'grep -qx "cccc3333 S3 12:41 visible" <<<"$out"'
check "a line two minutes after an event is not visible" 'grep -qx "cccc3333 S2 12:44 not visible" <<<"$out"'
printf '{"type":"assistant","timestamp":"2026-11-04T09:00:00Z","message":{"content":[{"type":"tool_use","id":"b","name":"Bash","input":{"command":"ls"}}]}}\n' > "$dir/corpus/-p/dddd4444-y.jsonl"
mkdir "$dir/quiet"; printf -- '- S1 09:00: a quiet session\n' > "$dir/quiet/2026 Familiar debt - repo deadbeef session dddd4444.md"
quiet=$(python3 "$here/familiar-visibility.py" "$dir/quiet" "$dir/corpus")
check "a session whose watch prints nothing is not visible, never no transcript" 'grep -qx "dddd4444 S1 09:00 not visible" <<<"$quiet"'
check "a note name with two ids takes the last one as its session" '! grep -q deadbeef <<<"$quiet"'
once=$(FAMILIAR_WATCH_ONCE=1 timeout 10 bash "$here/familiar-watch.sh" "$dir/corpus/-p/cccc3333-x.jsonl"); code=$?
check "the watch's read-once mode prints the saved events and ends" '[ $code -eq 0 ] && grep -q "SKILL: do" <<<"$once"'
exit $fail
