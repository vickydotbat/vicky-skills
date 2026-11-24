#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its test later, so the quotes keep it unexpanded
# shellcheck disable=SC2034 # list is read inside the eval'd test
# transcripts.py lists sessions in a few lines and writes a digest that keeps
# what came before a compaction, without skill bodies or the compact summary.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
t="$root/plugins/vicky-skills/skills/writing/case-file/scripts/transcripts.py"
s=$(mktemp -d); trap 'rm -rf "$s"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
cat > "$s/a1.jsonl" <<'J'
{"type":"user","timestamp":"2026-11-18T19:00:00Z","message":{"content":"Why does the lantern not glow?"}}
{"type":"user","timestamp":"2026-11-18T19:01:00Z","message":{"content":"Base directory for this skill: x"}}
{"type":"assistant","timestamp":"2026-11-18T19:20:00Z","message":{"content":[{"type":"text","text":"Wrong texture name."},{"type":"tool_use","name":"Bash"}]}}
{"type":"system","subtype":"compact_boundary","timestamp":"2026-11-18T20:00:00Z"}
{"type":"user","isCompactSummary":true,"timestamp":"2026-11-18T20:00:01Z","message":{"content":"Summary text"}}
not json
J
list=$(python3 "$t" list --dir "$s")
check "list names the session by its first ask" '[[ $list == *"a1"*"turns=1 compactions=1"*"Why does the lantern"* ]]'
python3 "$t" digest a1 "$s/out/d.txt" --dir "$s" >/dev/null
check "the digest keeps the finding from before the compaction" 'grep -q "Wrong texture name" "$s/out/d.txt"'
check "the digest leaves out skill bodies and the compact summary" '! grep -qE "Base directory|Summary text" "$s/out/d.txt"'
touch -d '2026-11-17' "$s/a1.jsonl"; : > "$s/e1.jsonl"; : > "$s/e2.jsonl"
check "a limit counts only sessions with a turn" '[[ $(python3 "$t" list --dir "$s" --limit 1) == *"a1"* ]]'
printf '%s\n' '{"type":"user","timestamp":"2026-11-19T10:00:00Z","message":{"content":"<command-message>vicky-skills:case-file</command-message>\n<command-name>/vicky-skills:case-file</command-name>\n<command-args>glow the lantern</command-args>"}}' > "$s/b1.jsonl"
list=$(python3 "$t" list --dir "$s")
check "a session begun by a typed command is listed by its command" '[[ $list == *"b1"*"/vicky-skills:case-file glow the lantern"* ]]'
check "the newest session is listed first" '[[ $list == b1* ]]'
check "a missing session is refused" '! python3 "$t" digest zz "$s/x" --dir "$s" 2>/dev/null'
exit $fail
