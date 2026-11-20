#!/usr/bin/env bash
# .todo holds two parked lines. ABC-9's ticket is Done, so its line is finished
# work: sup must strike it and offer nothing from it. ABC-8 is still open and
# its line stays. The old sup offered every .todo line as Still want.
set -eu
git init -q -b main .
mkdir -p docs/agents ../tracker
echo '| Read, whole | `cat ../tracker/<key>` |' > docs/agents/issue-tracker.md
printf 'ABC-9 Ship the parser\nstate: Done\n\n- 2026-11-18: merged and released.\n' > ../tracker/ABC-9
printf 'ABC-8 Tidy the lexer\nstate: Backlog\n\n- 2026-11-18: parked until the parser ships.\n' > ../tracker/ABC-8
printf -- '- Ship the parser (ABC-9)\n- Tidy the lexer (ABC-8)\n' > .todo
echo .todo > .gitignore
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
