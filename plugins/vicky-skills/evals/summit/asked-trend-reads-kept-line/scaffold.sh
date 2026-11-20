#!/usr/bin/env bash
# A repo with a local tracker: two tickets opened and one closed this week.
# Its Summit count line prints those counts, so the kept line reads
# 30 days: +2 / −1, C once a session has counted.
set -eu
git init -q -b main .
mkdir -p docs/agents .scratch/issues
cat > docs/agents/issue-tracker.md <<'EOF'
# Tickets: local

Tickets are files under .scratch/issues/, one per ticket, with a Status: line.

- **List items created or changed since <time>**: `find .scratch -path '*/issues/*.md' -newermt '<time>'`. Every one here is new.
- **List items closed since <time>**: `grep -l '^Status: done' .scratch/issues/*.md`. Give the count.

Summit count: `echo 2 1`
EOF
printf 'Status: open\n\nThe lantern flickers\n' > .scratch/issues/lantern-flickers.md
printf 'Status: open\n\nThe ferry sinks\n' > .scratch/issues/ferry-sinks.md
printf 'Status: done\n\nThe bell is silent\n' > .scratch/issues/bell-silent.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
echo '{"hook_event_name":"SessionStart","source":"startup"}' | CLAUDE_PROJECT_DIR="$PWD" bash "$CLAUDE_PLUGIN_ROOT/scripts/summit.sh" auto || true
