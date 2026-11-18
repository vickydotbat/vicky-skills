#!/usr/bin/env bash
# Regression: assimilate grades a pull request it can't make better, and asks
# before it builds. E14 and E15, ticked on the drafts page 2026-11-17; the
# behaviour already held when they were approved, so they carry no approved mark.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sk="$root/plugins/vicky-skills/skills/shipping/assimilate/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
has() { grep -qF -- "$2" "$1"; }

# Given a pull request someone else opened
# And its verdict's only finding is a matter of taste, such as a name or a wording
# When an agent assimilates it
# Then it posts the verdict as a grade only, and claims nothing
check "E14 a nit alone is graded, not claimed" \
  'has "$sk" "A better way removes a bad state, a step or a failure the branch keeps; a matter of taste is not one." && has "$sk" "post the verdict as a grade only"'

# Given you asked an agent to take over a pull request
# And its verdict is a grade only
# When the verdict is posted
# Then the agent asks you how to proceed, with two options at most and its pick, and builds nothing until you answer
check "E15 after a grade, a takeover ask still asks first" \
  'has "$sk" "When the verdict finds work to do and the user asked you to take it over, run \`do\`" && has "$sk" "Otherwise, a grade only or no takeover ask, ask the user how to proceed, with two options at most and your pick, and build nothing until they answer."'
exit $fail
