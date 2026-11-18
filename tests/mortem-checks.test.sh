#!/usr/bin/env bash
# The post-mortem and Foreseen checkers' edges beyond their approved examples:
# no argument, an unreadable file, a missing section, an undated Foreseen line.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
pm="$here/../plugins/vicky-skills/skills/planning/post-mortem/scripts/check-post-mortem.sh"
fs="$here/../plugins/vicky-skills/skills/commands/lay-course/scripts/check-foreseen.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git -C "$dir" init -q
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

bash "$pm" >/dev/null 2>&1; rc=$?
check "post-mortem check with no file is a usage error" '[ $rc -eq 2 ]'
bash "$fs" >/dev/null 2>&1; rc=$?
check "Foreseen check with no file is a usage error" '[ $rc -eq 2 ]'

out=$(bash "$pm" "$dir/missing.md"); rc=$?
check "post-mortem check fails a file it cannot read" '[ $rc -eq 1 ] && grep -q "cannot read" <<<"$out"'
out=$(bash "$fs" "$dir/missing.md"); rc=$?
check "Foreseen check fails a file it cannot read" '[ $rc -eq 1 ] && grep -q "cannot read" <<<"$out"'

printf '%s\n' '# Post-mortem: x' '' '## Impact' '' 'x' '' '## Timeline' '' '- 2026-11-18: x' '' '## Detection' '' 'x' '' \
  '## Causes' '' '- x' '' '## Earlier incidents' '' 'None found: searched the folder for x.' '' '## Follow-ups' '' '- x: GAME-1' > "$dir/pm.md"
out=$(bash "$pm" "$dir/pm.md"); rc=$?
check "post-mortem check names a missing section" '[ $rc -eq 1 ] && grep -q "no ## Lessons section" <<<"$out" && ! grep -q "no ## Impact" <<<"$out"'

printf '%s\n' '- Foreseen: a renumber breaks favourites, accepted: rare' > "$dir/chart.md"
out=$(bash "$fs" "$dir/chart.md"); rc=$?
check "Foreseen check fails an undated line" '[ $rc -eq 1 ] && grep -q "has no date" <<<"$out"'

printf '%s\n' '- Foreseen 2026-11-18: a renumber breaks favourites, accepted' > "$dir/chart.md"
out=$(bash "$fs" "$dir/chart.md"); rc=$?
check "Foreseen check fails an accepted failure with no reason" '[ $rc -eq 1 ] && grep -q "no disposition" <<<"$out"'
printf '%s\n' '- Foreseen 2026-11-18: a renumber breaks favourites, ticketed' > "$dir/chart.md"
out=$(bash "$fs" "$dir/chart.md"); rc=$?
check "Foreseen check fails a ticketed failure with no link" '[ $rc -eq 1 ] && grep -q "no disposition" <<<"$out"'
printf '%s\n' '- Foreseen 2026-11-18: a renumber breaks favourites, accepted: rare' '- Foreseen 2026-11-18: a cache goes stale, ticketed: GAME-9' > "$dir/chart.md"
bash "$fs" "$dir/chart.md" >/dev/null; rc=$?
check "Foreseen check passes an accepted reason and a ticketed link" '[ $rc -eq 0 ]'

whole() { printf '%s\n' '# Post-mortem: x' '' '## Impact' '' 'x' '' '## Timeline' '' "$1" '' '## Detection' '' 'x' '' '## Causes' '' '- x' '' \
  '## Earlier incidents' '' 'None found: searched the folder for x.' '' '## Lessons' '' '- x' '' '## Follow-ups' '' "$2"; }
whole 'Pager fired' '- x: GAME-1' > "$dir/pm2.md"
out=$(bash "$pm" "$dir/pm2.md"); rc=$?
check "post-mortem check fails a Timeline line written without its bullet" '[ $rc -eq 1 ] && grep -q "Timeline line has no date: Pager fired" <<<"$out"'
whole '- 2026-11-18: x' 'Pin the keys' > "$dir/pm2.md"
out=$(bash "$pm" "$dir/pm2.md"); rc=$?
check "post-mortem check fails a follow-up written without its bullet" '[ $rc -eq 1 ] && grep -q "follow-up links nothing: Pin the keys" <<<"$out"'
whole '- 2026-11-18: x' '- x: GAME-1' > "$dir/pm2.md"
bash "$pm" "$dir/pm2.md" >/dev/null; rc=$?
check "post-mortem check passes the whole shape" '[ $rc -eq 0 ]'

# A chart in a tracker folder outside any repo takes the off line from the repo the command runs in.
vault=$(mktemp -d); trap 'rm -rf "$dir" "$vault"' EXIT
mkdir -p "$dir/docs/agents"; printf 'Pre-mortems: off\n' > "$dir/docs/agents/domain.md"
printf '%s\n' '- Foreseen 2026-11-18: a renumber breaks favourites' > "$vault/chart.md"
out=$(cd "$dir" && bash "$fs" "$vault/chart.md"); rc=$?
check "Foreseen check reads the off line from the repo it runs in" '[ $rc -eq 0 ]'
rm "$dir/docs/agents/domain.md"
out=$(cd "$dir" && bash "$fs" "$vault/chart.md"); rc=$?
check "Foreseen check still checks a vault chart when the repo is on" '[ $rc -eq 1 ]'

exit $fail
