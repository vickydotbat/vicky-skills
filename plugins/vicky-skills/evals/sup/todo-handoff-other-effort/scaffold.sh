#!/usr/bin/env bash
# The session sits on branch feat-ABC-7, which names its own ticket. The last
# conn left its handoff on another effort's ticket, NEW-2, and pointed at it
# from .todo. sup must name that handoff. An agent can also reach it by reading
# .todo by hand, so this case guards the skill text; tests/find-handoff.test.sh
# proves the script reads the line on a keyed branch.
set -eu
git init -q -b main .
mkdir -p docs/agents ../tracker
echo '| Read, whole | `cat ../tracker/<key>` |' > docs/agents/issue-tracker.md
printf 'ABC-7 Tidy the parser\n\n- 2026-11-18: built and pushed, nothing waiting.\n' > ../tracker/ABC-7
printf 'NEW-2 Ship the carriers\n\n- 2026-11-19: **Handoff** the carrier models are exported; next, run the pack step.\n' > ../tracker/NEW-2
printf -- '- Tidy the parser (ABC-7)\n- Handoff: NEW-2 (2026-11-19)\n' > .todo
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feat-ABC-7
