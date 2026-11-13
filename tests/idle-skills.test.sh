#!/usr/bin/env bash
# idle-skills.py's edge cases, beside its approved examples.
set -u
script="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/captains-log/scripts/idle-skills.py"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/skills/sup" "$dir/skills/warp"; touch "$dir/skills/sup/SKILL.md" "$dir/skills/warp/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
line() { printf '%sT09:00:00Z\t%s\n' "$(date -u -d "2026-10-30 -$2 days" +%F)" "$1"; }
{ printf 'not-a-date\tvicky-skills:sup\n'; line vicky-skills:do 120; line vicky-skills:warp 59; } > "$dir/bad.tsv"
out=$(python3 "$script" "$dir/bad.tsv" "$dir/skills" --today 2026-10-30); code=$?
check "a ledger line with no date is skipped" '[ $code = 0 ] && grep -qx sup <<<"$out" && ! grep -qx warp <<<"$out"'
exit $fail
