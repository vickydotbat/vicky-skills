#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Summit: an
# opened-versus-closed record", 2026-11-01. The session-start checks run
# springboard.sh in a fixture repo with a stand-in gh, and summit.sh records
# the counts the agent took, so each check sees what the session sees. The
# skill checks read the instruction that drives the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
hook="$plugin/scripts/springboard.sh"
summit="$plugin/scripts/summit.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/bin" "$fx/repo" "$fx/data"
printf '#!/usr/bin/env bash\necho "[]"\n' > "$fx/bin/gh"; chmod +x "$fx/bin/gh"
export PATH="$fx/bin:$PATH" CLAUDE_PROJECT_DIR="$fx/repo" CLAUDE_PLUGIN_DATA="$fx/data"
git -C "$fx/repo" init -q
printf '.todo\n' > "$fx/repo/.gitignore"
stamp="$fx/repo/.git/springboard-last-session"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
start() { echo '{"hook_event_name":"SessionStart","source":"startup"}' | bash "$hook" 2>/dev/null; }
record() { (cd "$fx/repo" && bash "$summit" record "$1" "$2" 2>/dev/null); }
fresh() { rm -rf "$fx/data"; mkdir -p "$fx/data"; }
verdict() { fresh; record "$1" "$2" >/dev/null; start | grep -o '30 days: [^.]*'; }

# Given your last session in this repo started on Friday 23 October
# When a session starts
# Then the line reads Since 23 Oct: 4 opened, 9 closed
date -d '9 days ago' -Iseconds > "$stamp"
want="Since $(date -d '9 days ago' '+%-d %b'): <n> opened, <m> closed"
check "since a week or more ago" 'grep -qF "$want" <<<"$(start)"'

# Given no earlier session in this repo
# When a session starts
# Then the line holds only the 30-day part: 30 days: +611 / −451, C
rm -f "$stamp"; fresh; record 611 451 >/dev/null
out=$(start)
check "first session in a repo" 'grep -qF "30 days: +611 / −451, C" <<<"$out" && ! grep -q "Since " <<<"$out"'

# Given 611 tickets opened and 451 closed in the last 30 days
# When a session starts
# Then the line ends 30 days: +611 / −451, C
check "the 30-day verdict, C" '[ "$(verdict 611 451)" = "30 days: +611 / −451, C" ]'

# Given 100 tickets opened and 111 closed in the last 30 days
# When a session starts
# Then the verdict is A
check "the 30-day verdict, A" 'verdict 100 111 | grep -q ", A$"'

# Given 100 tickets opened and 110 closed in the last 30 days
# When a session starts
# Then the verdict is B
check "B at the top edge" 'verdict 100 110 | grep -q ", B$"'

# Given 100 tickets opened and 90 closed in the last 30 days
# When a session starts
# Then the verdict is B
check "B at the bottom edge" 'verdict 100 90 | grep -q ", B$"'

# Given 100 tickets opened and 89 closed in the last 30 days
# When a session starts
# Then the verdict is C
check "just below B" 'verdict 100 89 | grep -q ", C$"'

# Given no tickets opened and none closed in the last 30 days
# When a session starts
# Then the verdict is B
check "nothing happened" 'verdict 0 0 | grep -q ", B$"'

# Given no tickets opened and 3 closed in the last 30 days
# When a session starts
# Then the verdict is A
check "only closing" 'verdict 0 3 | grep -q ", A$"'

# Given the 30-day count was taken earlier today
# When a second session starts today
# Then the line shows that count, and the agent is not asked to count again
fresh; record 611 451 >/dev/null; start >/dev/null; out=$(start)
check "counted once a day" 'grep -qF "30 days: +611 / −451, C" <<<"$out" && ! grep -q "summit.sh record" <<<"$out"'

# Given the 30-day count was taken yesterday
# When a session starts
# Then the agent is asked to count the last 30 days again
fresh; record 611 451 >/dev/null
for f in "$fx/data"/summit/*; do sed -i "1s/^[0-9-]*/$(date -d yesterday +%F)/" "$f"; done
out=$(start)
check "a new day, a new count" 'grep -q "List items closed since <time>" <<<"$out" && grep -q "$(date -d "30 days ago" +%F)" <<<"$out" && grep -q "summit.sh record" <<<"$out"'

# Given a repo set up by first-contact with any of its trackers
# When an agent asks what was closed since a time
# Then the issue-tracker doc names a List items closed since time operation, beside List items created or changed since time
templates=("$plugin"/skills/engineering/first-contact/issue-tracker-*.md "$root/docs/agents/issue-tracker.md")
check "every tracker can list what closed" \
  '[ ${#templates[@]} -eq 7 ] && (for t in "${templates[@]}"; do l=$(grep -F -A1 -- "**List items created or changed since <time>**" "$t" | tail -1); grep -qF -- "**List items closed since <time>**" <<<"$l" && grep -q "\`" <<<"$l" || exit 1; done)'

# Given a 30-day verdict of C
# When captains-log runs
# Then it names the verdict and proposes ways to close more, never ways to find less
log="$plugin/skills/engineering/captains-log/SKILL.md"
check "captains-log reads the trend" \
  'grep -q "summit" "$log" && grep -q "30-day verdict" "$log" && grep -q "close more, never ways to find less" "$log"'

# Given a 30-day verdict of C
# When cerebro forecasts your next asks
# Then its proposals aim at closing more, never at finding less
cer="$plugin/skills/productivity/cerebro/SKILL.md"
check "cerebro reads the trend" \
  'grep -q "30-day verdict" "$cer" && grep -q "closing more, never at finding less" "$cer"'

# The band's examples run in Claude Code's mod test kit, from
# plugins/vicky-skills/tests/summit_approved_examples.test.tsx.
check "the band's summit examples pass in the mod test kit" \
  'out=$(timeout 120 claude plugin test "$plugin" 2>&1) && [ "$(grep -c "^(pass) summit > " <<<"$out")" = 2 ]'
exit $fail
