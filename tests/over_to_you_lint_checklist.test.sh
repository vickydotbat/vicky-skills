#!/usr/bin/env bash
# over-to-you's checklist lint: an item a command could prove never reaches a person.
set -u
lint="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/over-to-you/scripts/lint-checklist.py"
dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

cat > "$dir/good.md" <<'MD'
# Over to you, Bob!
proven by: integration.sh --branch, 15 fixtures green
## Pack
1. [ ] Open the hub → the grid draws
   person: look
   notes:
MD
sed 's/^   person: look$//' "$dir/good.md" > "$dir/no-person.md"
sed 's/person: look/person: the merge happens/' "$dir/good.md" > "$dir/bad-reason.md"
grep -v '^proven by:' "$dir/good.md" > "$dir/no-proof.md"

check "a checklist whose items each name a person-only reason passes" 'python3 "$lint" "$dir/good.md" >/dev/null'
check "an item with no person line is refused" '! python3 "$lint" "$dir/no-person.md" >/dev/null && python3 "$lint" "$dir/no-person.md" | grep -q "no \`person:\` line"'
check "a reason a command could prove is refused" '! python3 "$lint" "$dir/bad-reason.md" >/dev/null'
check "a checklist that names nothing the agent ran is refused" '! python3 "$lint" "$dir/no-proof.md" >/dev/null'
exit $fail
