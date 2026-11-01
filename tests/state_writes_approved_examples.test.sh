#!/usr/bin/env bash
# approved-spec: the S4 examples of the .todo springboard (state writes),
# approved 2026-11-01. The behaviour is the agent's, so each check reads the
# instruction that drives it.
set -u
skills="$(dirname "$0")/../plugins/vicky-skills/skills/engineering"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
status_rule="$skills/ship-it/SKILL.md"

# Given a build with a draft pull request open
# When do, make-it-so, gamma-shift or warp stops, for any reason
# Then the pull request body has a Status section with a Done line, a Next line and a Waits on line, true at that moment
check "a stop leaves the pull request saying where it stands" \
  '(for s in do make-it-so gamma-shift warp; do grep -q "At every stop, write the pull request body'"'"'s Status section" "$skills/$s/SKILL.md" || exit 1; done) && grep -q "^## Status" "$status_rule" && grep -q "\`Done:\`" "$status_rule" && grep -q "\`Next:\`" "$status_rule" && grep -q "\`Waits on:\`" "$status_rule"'

# Given a stop where nothing waits on anyone
# When the skill writes the Status section
# Then its Waits on line reads nobody, and the Next line names what the next session does
check "a stop with nothing waiting says so" \
  'grep -q "\`Waits on: nobody\`" "$status_rule" && grep -q "\`Next:\` names what the next session does" "$status_rule"'

# Given a ticket in the tracker's not-started state
# When do begins work on it
# Then the ticket shows the started state, In Progress, before the first commit lands
check "work beginning moves the ticket to started" \
  'grep -q "Move the ticket to the started state (In Progress) before the first commit" "$skills/do/SKILL.md"'

# Given a ticket in progress whose slice the build parks
# When do, gamma-shift or warp parks it
# Then the ticket shows the not-started state and a Waits on line naming what it waits on
check "a parked slice moves its ticket back" \
  '(for s in do gamma-shift warp; do grep -q "move its ticket back to the not-started state with a \`Waits on:\` line" "$skills/$s/SKILL.md" || exit 1; done)'

# Given a ticket the branch names that still shows not-started while its pull request is open
# When loose-ends runs
# Then the ticket shows In Progress, and the report names the move
check "loose-ends fixes a state that lags" \
  'grep -q "A ticket whose state lags the work moves now" "$skills/loose-ends/SKILL.md" && grep -q "the report names each move" "$skills/loose-ends/SKILL.md"'
exit $fail
