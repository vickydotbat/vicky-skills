#!/usr/bin/env bash
# The shape counter's edge cases and the same-refusal rule: regression tests
# beside the counter's approved examples.
set -u
counter="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-shapes.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/c"
at() { printf '2026-11-%sT10:00:00Z' "$1"; }
use() { printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","id":"%s","name":"%s","input":{"command":"%s"}}]}}\n' "$(at "$1")" "$2" "$3" "$4"; }
refused() { printf '{"type":"user","timestamp":"%s","message":{"content":[{"type":"tool_result","tool_use_id":"%s","is_error":true,"content":"PreToolUse hook error: no"}]}}\n' "$(at "$1")" "$2"; }
{
  printf '{"type":"user","timestamp":"%s","message":{"content":"a real turn"}}\n' "$(at 03)"
  printf '{"type":"user","isMeta":true,"timestamp":"%s","message":{"content":"meta"}}\n' "$(at 03)"
  printf '{"type":"user","timestamp":"%s","message":{"content":"<command-name>/x</command-name>"}}\n' "$(at 03)"
  use 03 a Bash "git push"; printf '{"type":"user","timestamp":"%s","message":{"content":[{"type":"tool_result","tool_use_id":"a","is_error":false,"content":"ok"}]}}\n' "$(at 03)"
  use 03 b Bash "git push"
  use 03 c Bash "rm x"; refused 03 c
  use 03 d Edit "rm x"
} > "$dir/c/late.jsonl"
{
  printf '{"type":"user","timestamp":"%s","message":{"content":[{"type":"tool_result","tool_use_id":"z","content":"ok"}]}}\n' "$(at 02)"
  printf '{"type":"user","timestamp":"%s","message":{"content":"earlier"}}\n' "$(at 02)"
} > "$dir/c/early.jsonl"
out=$(bash "$counter" "$dir/c" --law same-refusal=2026-11-01 --law same-refusal=2026-11-09)
check "only real user turns count: no meta line, command line or tool result" 'grep -qx "2026-11-03 same-refusal 0/1 turns = 0.0 per 100" <<<"$out"'
check "a repeat after a call that was not refused is no hit, nor is the same input to another tool" 'grep -q "^2026-11-03 same-refusal 0/" <<<"$out"'
check "a tool result before a turn still lets the turn count" 'grep -qx "2026-11-02 same-refusal 0/1 turns = 0.0 per 100" <<<"$out"'
check "days print in date order" '[ "$(grep -o "^2026-11-0[0-9]" <<<"$out" | head -2 | tr "\n" " ")" = "2026-11-02 2026-11-03 " ]'
check "a law before every day has no rate before it" 'grep -qx "same-refusal law 2026-11-01: before no rate, after 0.0 per 100" <<<"$out"'
check "a law after every day has no rate after it" 'grep -qx "same-refusal law 2026-11-09: before 0.0 per 100, after no rate" <<<"$out"'
exit $fail
