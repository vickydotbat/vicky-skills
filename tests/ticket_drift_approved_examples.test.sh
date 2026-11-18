#!/usr/bin/env bash
# approved-spec: the examples approved on the star "A hook flags ticket
# drift". Each check is named after its example. The hook's checks run it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/ticket-drift.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"; git -C "$dir/repo" remote add origin https://example.invalid/r.git; mkdir -p "$dir/repo/docs/agents"; touch "$dir/repo/docs/agents/issue-tracker.md"
stamp="$dir/repo/.git/ticket-drift-last"
day=86400
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT="${GS:-engage}" CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS="$1" CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null; }
ago() { echo $(( $(date +%s) - $1 * day )) > "$stamp"; }

# Given gamma_shift at engage and drift_every_days at 7
# When a session starts eight days after the last drift check
# Then the drift check joins the gamma shift's queue, and my first request is served alongside it
ago 8; out=$(run 7)
check "at engage and drift_every_days 7, eight days after the last check, the drift check joins the gamma shift's queue while my first request is served" \
  'grep -q "gamma-shift.s engage queue" <<<"$out" && grep -q "first request is served alongside it" <<<"$out" && [ "$(cat "$stamp")" -gt $(( $(date +%s) - 60 )) ]'

# Given gamma_shift at engage and drift_every_days at 7
# When a session starts two days after the last drift check
# Then no drift check runs
ago 2; out=$(run 7)
check "at engage and drift_every_days 7, two days after the last check, no drift check runs" '[ -z "$out" ]'

# Given gamma_shift at off or remind and drift_every_days at 7
# When a session starts eight days after the last drift check
# Then no drift check runs
ago 8; out=$(GS=off run 7); ago 8; out2=$(GS=remind run 7); ago 8; out3=$(env -u CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS=7 CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null)
check "at gamma_shift off or remind, eight days after the last check, no drift check runs" '[ -z "$out$out2$out3" ]'

# Given a repo whose docs/agents/issue-tracker.md says Ticket drift: off
# When a drift check is due
# Then nothing runs
mkdir -p "$dir/repo/docs/agents"; printf 'Ticket drift: off\n' > "$dir/repo/docs/agents/issue-tracker.md"; rm -f "$stamp"; out=$(run 7)
check "in a repo whose docs/agents/issue-tracker.md says \"Ticket drift: off\", nothing runs when a check is due" \
  '[ -z "$out" ] && [ ! -e "$stamp" ]'
exit $fail
