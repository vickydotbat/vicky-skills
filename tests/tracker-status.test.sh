#!/usr/bin/env bash
# tracker-status.sh lists the notes in an Obsidian tracker folder that every
# tracker operation misses: no valid status in the frontmatter, or no
# timestamp in the name. Covers each listing, the pass, and bad input.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
ts="$root/plugins/vicky-skills/skills/productivity/summit/scripts/tracker-status.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
note() { printf '%b' "$2" > "$fx/t/$1"; }
run() { bash "$ts" "$fx/t" > "$fx/out" 2>"$fx/err"; }
mkdir -p "$fx/t/sub"
for s in open claimed waiting done; do note "20261101120000 A $s.md" "---\nkind: task\nstatus: $s\n---\n# A\n"; done
note "sub/no status.md" "# not a top-level note\n"
check "a folder of valid notes passes and says how many it read" 'run; [ $? = 0 ] && grep -qx "tracker-status: 4 notes, all on the tracker" "$fx/out"'
note "20261101130000 B.md" "# B\n\nStatus: built in #17.\n"
check "a note with no frontmatter is listed as having no status" 'run; [ $? = 1 ] && grep -qF "no status: 20261101130000 B.md" "$fx/out"'
rm "$fx/t/20261101130000 B.md"; note "20261101140000 C.md" "---\ntags: [familiar-debt]\n---\n# C\nstatus: done\n"
check "a status line outside the frontmatter does not count" 'run; [ $? = 1 ] && grep -qF "no status: 20261101140000 C.md" "$fx/out"'
rm "$fx/t/20261101140000 C.md"; note "20261101150000 D.md" "---\nstatus: closed\n---\n"
check "a status outside open, claimed, waiting and done is listed with its value" 'run; [ $? = 1 ] && grep -qF "bad status \"closed\": 20261101150000 D.md" "$fx/out"'
rm "$fx/t/20261101150000 D.md"; note "Ready gate.md" "---\nstatus: open\n---\n"
check "a note whose name has no timestamp is listed" 'run; [ $? = 1 ] && grep -qF "no timestamp: Ready gate.md" "$fx/out"'
rm "$fx/t/Ready gate.md"
check "a fixed folder passes again" 'run; [ $? = 0 ]'
mkdir -p "$fx/empty"
check "an empty folder passes with no notes" 'bash "$ts" "$fx/empty" > "$fx/out" 2>&1; [ $? = 0 ] && grep -qx "tracker-status: 0 notes, all on the tracker" "$fx/out"'
check "with no folder it prints the usage and exits 2" 'bash "$ts" >/dev/null 2>"$fx/err"; [ $? = 2 ] && grep -q "usage: tracker-status.sh" "$fx/err"'
check "a folder that does not exist is refused with exit 2" 'bash "$ts" "$fx/nope" >/dev/null 2>"$fx/err"; [ $? = 2 ] && grep -q "no folder" "$fx/err"'
exit $fail
