#!/usr/bin/env bash
# ABC-7 is open after !12 merged, and its thread says its done-when is still unmet. sup keeps it open and asks nothing.
set -eu
git init -q -b main .
git remote add origin https://forge.example.invalid/acme/app.git
mkdir -p docs/agents tracker
cat > docs/agents/issue-tracker.md <<'EOF'
# Tickets: notes

| Operation | Command |
| --- | --- |
| Read, whole | `cat tracker/<key>` |
| Close | `sed -i 's/^state:.*/state: Done/' tracker/<key>` |
| Comment | `printf -- '- %s\n' '<text>' >> tracker/<key>` |
EOF
printf 'ABC-7 Port the specimen loader\nstate: In Progress\n\nDone when: every specimen loads at parity.\n\n- 2026-11-18: !12 opened.\n- 2026-11-19: !12 merged. 85 of 151 specimens at parity, so this stays open until the rest are.\n' > tracker/ABC-7
printf -- '- Port the specimen loader (ABC-7, !12)\n' > .todo
# The forge stub parked-state.sh reads: pull request 12 merged.
printf '12 merged\n' > forge-stub
git config parked-state.stub forge-stub
printf '.todo\ntracker/\nforge-stub\n' > .gitignore
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
