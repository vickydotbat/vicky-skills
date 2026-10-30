#!/usr/bin/env bash
# approved-spec: the examples approved on the star "captains-log flags skills
# nobody starts". Each check is named after its example.
set -u
here="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/captains-log"
script="$here/scripts/idle-skills.py"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/skills/sup" "$dir/skills/warp" "$dir/skills/do"
touch "$dir/skills/sup/SKILL.md" "$dir/skills/warp/SKILL.md" "$dir/skills/do/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# Writes a ledger line for a skill started $2 days before 2026-10-30.
line() { python3 -c 'import datetime,sys; print(f"{datetime.date(2026,10,30)-datetime.timedelta(days=int(sys.argv[2])):%Y-%m-%d}T09:00:00Z\t{sys.argv[1]}")' "$1" "$2"; }
idle() { python3 "$script" "$1" "$dir/skills" --today 2026-10-30; }

{ line vicky-skills:do 120; line vicky-skills:warp 59; line do 3; } > "$dir/old.tsv"
out=$(idle "$dir/old.tsv")
check "with a ledger 120 days back and no line naming sup, sup is listed as unused, with a pick: keep, merge or delete" \
  'grep -qx sup <<<"$out" && grep -q "keep, merge into the skill it overlaps, or delete" "$here/SKILL.md"'
check "with a ledger 120 days back and warp started 59 days ago, warp is not listed" \
  '! grep -qx warp <<<"$out" && ! grep -qx do <<<"$out"'

line do 20 > "$dir/young.tsv"
out=$(idle "$dir/young.tsv"); code=$?
check "with a ledger only 20 days back, it lists no unused skills and says the ledger is too young to tell" \
  '[ $code = 4 ] && [ "$out" = "too young: 20 days" ] && grep -q "too young to tell" "$here/SKILL.md"'

out=$(idle "$dir/none.tsv"); code=$?
check "with the skill ledger setting off, it says turning on the ledger would show which skills nobody starts" \
  '[ $code = 3 ] && [ "$out" = "no ledger" ] && grep -q "turning on the .skill_ledger. setting would show which skills nobody starts" "$here/SKILL.md"'
exit $fail
