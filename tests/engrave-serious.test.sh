#!/usr/bin/env bash
# engrave starts unasked on the agent's own serious mistake, in the turn it
# happens, instead of waiting for the user or the settling batch.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
f="$root/plugins/vicky-skills/skills/shipping/engrave/SKILL.md"
fail=0
has() { if grep -qE -- "$2" <<<"$3"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
desc=$(sed -n 's/^description: //p' "$f")
has "the description fires on a serious mistake of the agent's own" 'serious mistake of your own' "$desc"
has "the description says unasked" 'unasked' "$desc"
intro=$(sed -n '/^A \*\*snag\*\*/,/^$/p' "$f")
has "the intro says a serious snag is engraved on the spot" 'Engrave a serious snag on the spot, unasked' "$intro"
for k in 'money or credits' 'data' 'leak' 'shared state' 'unread'; do
  has "a serious snag covers: $k" "$k" "$intro"
done
exit $fail
