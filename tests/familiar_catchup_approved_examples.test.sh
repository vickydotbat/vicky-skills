#!/usr/bin/env bash
# Approved examples for the familiar's catch-up (E27, changed, and E30): a
# session that starts while the familiar watches is found within a minute
# and watched from its first line, and a session already watched keeps its
# one watch.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
lister="$root/skills/productivity/familiar/scripts/familiar-sessions.sh"
skill="$root/skills/productivity/familiar/SKILL.md"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
mkdir -p "$fx/projects/-r"
live() { jq -nc '{type:"user",cwd:"/work/r",message:{content:"hi"}}' > "$fx/projects/-r/$1.jsonl"; }
live old
# The check for new sessions, every 0.2 seconds for 15 rounds instead of every minute.
FAMILIAR_PROJECTS_DIR="$fx/projects" CLAUDE_CODE_SESSION_ID=self FAMILIAR_SESSIONS_EVERY=0.2 FAMILIAR_SESSIONS_ROUNDS=15 \
  timeout 20 bash "$lister" --new > "$fx/new.out" & pid=$!
timeout 1 tail -f /dev/null
live fresh
wait $pid

# Given the familiar is watching
# When a new session starts on the machine
# Then within a minute the familiar starts watching it, from its first line
check "E27 a new session is announced by the minute check" 'grep -qx "NEW fresh $fx/projects/-r/fresh.jsonl /work/r" "$fx/new.out"'
check "E27 the check runs every minute" 'grep -qF "familiar-sessions.sh --new" "$skill" && grep -qF "every minute" "$skill"'
check "E27 a new session is watched from its first line" 'grep -qF "FAMILIAR_WATCH_FROM_START=1 bash <this skill'"'"'s folder>/scripts/familiar-watch.sh" "$skill"'

# Given the familiar already watches a session
# When the minute check for new sessions runs
# Then that session keeps its one watch
check "E30 a session already watched is never announced again" '! grep -q "^NEW old " "$fx/new.out" && [ "$(grep -c "^NEW fresh " "$fx/new.out")" = 1 ]'

exit $fail
