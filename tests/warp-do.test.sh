#!/usr/bin/env bash
# Warp hands every star to do, and do picks up a star whose red tests
# pre-flight already committed, so the build never skips do.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/engineering"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "warp starts one do run per star, and never builds a star itself" \
  'grep -qF "one \`do\` run per star" "$root/warp/SKILL.md" && grep -qF "a warp never writes a star'"'"'s code itself" "$root/warp/SKILL.md"'
check "do goes on at step 3 when pre-flight made the tests red" \
  'grep -qF "When a warp'"'"'s pre-flight already committed them red, this step is done: go to step 3" "$root/do/SKILL.md"'
exit $fail
