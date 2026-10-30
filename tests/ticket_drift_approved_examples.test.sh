#!/usr/bin/env bash
# approved-spec: the examples approved on the star "A hook flags ticket
# drift". Each check is named after its example. The hook's checks run it;
# the drift checks read the ticket-drift agent's instructions, since reading
# tickets is the agent's work.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/ticket-drift.sh"
agent="$root/plugins/vicky-skills/agents/ticket-drift.md"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"
stamp="$dir/repo/.git/ticket-drift-last"
day=86400
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS="$1" CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null; }
ago() { echo $(( $(date +%s) - $1 * day )) > "$stamp"; }
compare=$(awk '/^4\. /{on=1} /^5\. /{on=0} on' "$agent")

ago 8; out=$(run 7)
check "at drift_every_days 7, eight days after the last check, the agent runs the drift check in the background while it serves my first request" \
  'grep -q "ticket-drift agent now as one background subagent" <<<"$out" && grep -q "first request is served alongside it" <<<"$out" && [ "$(cat "$stamp")" -gt $(( $(date +%s) - 60 )) ]'

ago 2; out=$(run 7)
check "at drift_every_days 7, two days after the last check, no drift check runs" '[ -z "$out" ]'

rm -f "$stamp"; out=$(run 0); out2=$(env -u CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS CLAUDE_PROJECT_DIR="$dir/repo" bash "$hook" </dev/null)
check "at drift_every_days 0, the default, no drift check runs" \
  '[ -z "$out$out2" ] && grep -A4 "\"drift_every_days\"" "$root/plugins/vicky-skills/.claude-plugin/plugin.json" | grep -q "\"default\": \"0\""'

check "a body saying port 8080 under a later comment saying 9090 gets a comment naming the body line and the comment, and the body stays unchanged" \
  'grep -q "a later comment or a merged pull request contradicts" <<<"$compare" && grep -q "Quote the body line, then the comment or pull request that contradicts it" "$agent" && grep -q "You never edit a body" "$agent" && ! grep -qE "^tools:.*\b(Edit|Write)\b" "$agent"'
check "a body asking for CSV under a merged PR that names the ticket and ships JSON gets a comment naming the body line and the PR" \
  'grep -q "merged pull requests that name it" "$agent" && grep -q "title, body and changed-file list" "$agent" && grep -q "with its date or number" "$agent"'
check "a ticket whose body and comments agree, and that no merged PR names, gets nothing posted" \
  'grep -q "Done when each ticket has its drifts, or none" <<<"$compare" && grep -q "Comment on each drifted ticket" "$agent"'

mkdir -p "$dir/repo/docs/agents"; printf 'Ticket drift: off\n' > "$dir/repo/docs/agents/issue-tracker.md"; rm -f "$stamp"; out=$(run 7)
templates=$(grep -lx 'Ticket drift: on' "$root"/plugins/vicky-skills/skills/engineering/first-contact/issue-tracker-*.md | wc -l)
check "in a repo whose docs/agents/issue-tracker.md says \"Ticket drift: off\", nothing runs when a check is due" \
  '[ -z "$out" ] && [ ! -e "$stamp" ] && [ "$templates" = 6 ] && grep -q "Ticket drift: off" "$agent"'
exit $fail
