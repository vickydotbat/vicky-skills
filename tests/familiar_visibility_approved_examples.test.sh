#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Familiar visibility probe".
# Each check runs the probe on synthetic debt notes and transcripts.
set -u
probe="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-visibility.py"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/notes" "$dir/corpus/-proj"
ts() { printf '2026-11-04T%s:00.000Z' "$1"; }
user() { printf '{"type":"user","timestamp":"%s","message":{"content":"%s"}}\n' "$(ts "$1")" "$2"; }
use() { printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","id":"%s","name":"%s","input":{"command":"%s"}}]}}\n' "$(ts "$1")" "$2" "$3" "$4"; }
result() { printf '{"type":"user","timestamp":"%s","message":{"content":[{"type":"tool_result","tool_use_id":"%s","is_error":%s,"content":"%s"}]}}\n' "$(ts "$1")" "$2" "$3" "$4"; }
{
  user 12:30 "build the inventory"
  use 12:42 t1 Bash "git push"
  result 12:42 t1 true "PreToolUse:Bash hook error: push-behind-guard refused"
  use 12:48 t2 Bash "ls"
  result 12:48 t2 false "ok"
  use 12:50 t3 Edit "edit"
  result 12:50 t3 false "ok"
  use 12:52 t4 Bash "cp a b"
  result 12:52 t4 false "ok"
} > "$dir/corpus/-proj/aaaa1111-0000-0000-0000-000000000000.jsonl"
printf '# Familiar debt: proj session aaaa1111\n\n- S1 12:42: a push refused\n- S2 12:50: files copied between checkouts\n' > "$dir/notes/20261104120000 Familiar debt - proj session aaaa1111.md"
printf '# Familiar debt: proj session bbbb2222\n\n- S1 09:10: a gate left open\n- M1 09:20: a miss\n' > "$dir/notes/20261104090000 Familiar debt - proj session bbbb2222.md"
out=$(python3 "$probe" "$dir/notes" "$dir/corpus" 2>&1)

# Given a debt note line S1 12:42 for a session whose transcript holds a hook refusal at 12:42
# When the visibility probe runs over the note and the transcripts
# Then it tags S1 visible
check "E10 a snag line at the minute of a hook refusal is tagged visible" \
  'grep -qx "aaaa1111 S1 12:42 visible" <<<"$out"'

# Given a debt note line S2 12:50 whose session shows only shell commands and edits from 12:48 to 12:52
# When the visibility probe runs
# Then it tags S2 not visible
check "E11 a snag line where the session shows only shell commands and edits is tagged not visible" \
  'grep -qx "aaaa1111 S2 12:50 not visible" <<<"$out"'

# Given a debt note for a session whose transcript is gone from the corpus
# When the visibility probe runs
# Then it tags each of that note's lines no transcript, never not visible
check "E12 every line of a note whose transcript is gone is tagged no transcript" \
  'grep -qx "bbbb2222 S1 09:10 no transcript" <<<"$out" && grep -qx "bbbb2222 M1 09:20 no transcript" <<<"$out" && ! grep -q "bbbb2222 .* not visible" <<<"$out"'

# Given notes holding visible, not visible and no-transcript lines
# When the visibility probe ends
# Then it prints one count for each of the three tags
check "E13 the probe ends with one count per tag" \
  'grep -qx "visible: 1" <<<"$out" && grep -qx "not visible: 1" <<<"$out" && grep -qx "no transcript: 2" <<<"$out"'
[ $fail -eq 0 ] || echo "$out" | sed 's/^/     /'
exit $fail
