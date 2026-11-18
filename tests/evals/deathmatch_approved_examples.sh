#!/usr/bin/env bash
# approved-spec: the Deathmatch examples ticked on 2026-11-18 whose result is an
# agent's judgement: E1 to E4, E9 to E15, E18 to E21, E26 and E28. Each runs its
# eval case under evals/deathmatch once against the plugin (D17: green once).
# E2 also runs against the plugin with deathmatch deleted, to prove it can go
# red. Each run is a full Claude session on your own credential, so CI never
# runs this file: run it by hand. It caps every run at --max-cost-usd.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
plugin=$evals_plugin
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
for c in proven-finding unproven-never-blocks own-branch-fix claims-untrue-proof host-undeclared-tool \
  symptom-meets-rival graft-stronger-part cause-fix-no-arena simplicity-by-contest assimilate-posts-verdict \
  planted-cause-checked second-model-on-dispute approved-tests-stay failing-lines-not-log make-it-so-fires \
  no-review-trails-star outside-report-checked; do
  if eval_case "$plugin" "$c" "$c"; then echo "ok   $c"; else
    echo "FAIL $c: score $(case_score "$c"), failed: $(failed_graders "$c")"; fail=1; fi
done

# Given an opponent's finding whose command passes when it is run again
# When deathmatch reports, with the deathmatch skill deleted
# Then the case goes red, so it can fail
cp -r "$plugin" "$dir/cut"; rm -rf "$dir/cut/skills/shipping/deathmatch"
if eval_case "$dir/cut" unproven-never-blocks cut; then echo "FAIL E2 goes red without deathmatch: it passed"; fail=1
elif ! graded_red cut; then echo "FAIL E2 goes red without deathmatch: the run broke before grading"; fail=1
else echo "ok   E2 goes red without deathmatch"; fi
exit $fail
