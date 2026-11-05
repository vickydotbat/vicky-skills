#!/usr/bin/env bash
# The replay's minute window, its precision count and its bad input:
# regression tests beside the replay's approved examples.
set -u
replay="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-replay.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
printf '{"type":"user","timestamp":"2026-11-04T12:30:00Z","message":{"content":"go"}}\n' > "$dir/s.jsonl"
printf 'catch 12:41\ncatch 12:43\ncatch 12:45\nfp 12:42\nfp 12:50\nfp 12:55\n' > "$dir/labels"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho "- S1 12:42: a snag"\n' > "$dir/model"; chmod +x "$dir/model"
out=$(FAMILIAR_REPLAY_MODEL="$dir/model" bash "$replay" "$dir/s.jsonl" "$dir/labels")
check "a label one minute before a logged line is found" 'grep -qx "catch 12:41 3/3" <<<"$out"'
check "a label one minute after a logged line is found" 'grep -qx "catch 12:43 3/3" <<<"$out"'
check "a label three minutes away is not found" 'grep -qx "catch 12:45 0/3" <<<"$out"'
check "precision counts the false positives the replay left alone" 'grep -qx "precision on false positives: 2 of 3 left alone" <<<"$out"'
FAMILIAR_REPLAY_MODEL="$dir/model" bash "$replay" "$dir/none.jsonl" "$dir/labels" >/dev/null 2>"$dir/err"; code=$?
check "a missing transcript exits 2 and names it" '[ $code -eq 2 ] && grep -q "none.jsonl" "$dir/err"'
exit $fail
