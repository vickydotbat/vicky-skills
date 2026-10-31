#!/usr/bin/env bash
# approved-spec: the examples approved in chat for "brief-mode memes in the
# dungeon-master style". Each check is named after its example. The behaviour
# is the agent's, so each check reads the instruction that drives it.
set -u
style="$(dirname "$0")/../plugins/vicky-skills/output-styles/dungeon-master.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
memes=$(awk '/^## Memes/{on=1; next} /^## /{on=0} on' "$style")
brief=$(grep "In brief mode" <<<"$memes")

check "in brief mode, an explanation written while working reaches the user as a checkpoint message, with its meme" \
  'grep -q "SendUserMessage" <<<"$brief" && grep -q "explanation written while working goes into a checkpoint message, its meme with it" <<<"$brief"'
check "with brief mode off, the explanation and its meme stay in the running text" \
  'grep -q "Outside brief mode it stays in the running text" <<<"$brief"'
check "in brief mode, a routine step with nothing to explain sends no checkpoint message" \
  'grep -q "A routine step with nothing to explain sends no checkpoint" <<<"$brief"'
exit $fail
