#!/usr/bin/env bash
# approved-spec: the flow's steps that do and make-it-so must name, approved
# 2026-11-13. It reads the skills, since the agent follows their text.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
do="$root/plugins/vicky-skills/skills/engineering/do/SKILL.md"
mis="$root/plugins/vicky-skills/skills/engineering/make-it-so/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# E1 Given review answered every finding, When the build goes on, Then a refactor pass runs with tests green before and after
check "E1 do refactors after review" \
  'grep -q "\*\*Refactor\*\* the code this build touched" "$do" && grep -q "green before and after" "$do" && grep -q "nothing to refactor" "$do"'
# E2 Given checks pass, When the change has an output, Then the agent looks at it and quotes what it saw
check "E2 do looks at the result" \
  'grep -q "\*\*Look at the result yourself\*\*" "$do" && grep -q "quotes or shows what you saw" "$do"'
# E3 Given make-it-so, When QA runs, Then an item checks docs, agent files and memory the diff makes untrue
check "E3 make-it-so sweeps current truth" \
  'grep -q "\*\*Q12 Current truth\.\*\*" "$mis" && grep -q "README, docs, agent files and project memory" "$mis"'
check "E3 make-it-so step 4 runs Q12" \
  'grep -q "^4\. .*then Q7 to Q10 and Q12" "$mis"'
check "E1 do step 6 is done only with the refactor report" \
  'grep -q "and the report names each refactor or says .nothing to refactor." "$do"'
# E4 Given a build starts outside a trunk repo, When the first edit comes, Then it lands in a worktree and the main checkout stays untouched
check "E4 do builds only in a worktree" \
  'grep -q "never edit, switch or detach the main checkout" "$do"'
# E5 Given the effort lands, When the report goes out, Then marie-kondo has run
check "E5 make-it-so cleans up after landing" \
  'grep -q "run \`marie-kondo\`" "$mis"'
# E6 Given the remote default moved, When the branch pushes, Then it always rebases with history-monks
check "E6 make-it-so always rebases with history-monks" \
  'grep -q "rebase it with \`history-monks\`, always" "$mis"'
exit $fail
