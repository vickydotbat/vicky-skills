#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Lint blocks mechanical
# tells". Each check is named after its example.
set -u
here="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/human-voice"
lint="$here/scripts/lint-tells.py"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# lint <text>: prints the lint's output, then "exit=<code>".
lint() { printf '%s\n' "$1" > "$scratch/draft.md"; python3 "$lint" "$scratch/draft.md" 2>&1; echo "exit=$?"; }

out=$(lint $'A title\n\nThe library provides a robust solution.')
check "a draft saying \"The library provides a robust solution\" gets that line named with the tell Puffery" \
  'grep -q "^3: Puffery: robust$" <<<"$out" && grep -q "^exit=1$" <<<"$out"'

out=$(lint 'The cache stores results for an hour, ensuring fast searches.')
check "a draft saying \"The cache stores results for an hour, ensuring fast searches\" gets that line named with the tell Participle tails" \
  'grep -q "^1: Participle tails: , ensuring$" <<<"$out" && grep -q "^exit=1$" <<<"$out"'

out=$(lint $'Intro.\n\nOne — two — three — four.')
check "a paragraph with three em dashes gets that paragraph named with the tell Em dash flood" \
  'grep -q "^3: Em dash flood: 3 em dashes$" <<<"$out" && grep -q "^exit=1$" <<<"$out"'

out=$(lint 'One — two — three.')
check "a paragraph with two em dashes gets no em dash hit" \
  '! grep -q "Em dash" <<<"$out" && grep -q "^exit=0$" <<<"$out"'

out=$(lint $'Set `robust` to true.\n\n```\nrobust = true\n```')
check "a draft whose only \"robust\" sits in a code span or a code block passes quietly" \
  '[ "$out" = "exit=0" ]'

out=$(lint $'Plain line.\nShe said “hi”.')
check "a draft with curly quotes gets the line named with the tell Curly quotes" \
  'grep -q "^2: Curly quotes: " <<<"$out" && grep -q "^exit=1$" <<<"$out"'

out=$(lint $'# Release notes\n\nVersion 2.0 drops Node 16 support. The bundle is 40% smaller.\n\nRun `npm install` to update.')
check "a draft with none of the 26 tells a script can catch prints nothing and passes" \
  '[ "$out" = "exit=0" ]'

skill="$here/SKILL.md"
check "a draft the lint flags gets every hit rewritten by human-voice, and the lint passes, before the draft reaches the user" \
  'grep -q "scripts/lint-tells.py" "$skill" && grep -qi "rewrite every hit" "$skill" && grep -qi "until it prints nothing" "$skill" \
   && awk "/scripts\/lint-tells.py/{l=NR} /\*\*Show the draft/{s=NR} END{exit !(l && s > l)}" "$skill"'
exit $fail
