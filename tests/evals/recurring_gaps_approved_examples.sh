#!/usr/bin/env bash
# approved-spec: the example the user ticked on 2026-11-05 for "Skill evals -
# seed the recurring gaps": each of the five corrections that came back most
# has an eval case, and each case fails against the plugin from just before
# the commit that fixed it. Run by hand: each run costs a Claude session.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
fail=0
# Each gap: its eval case, under evals/<skill>/<case>, and the commit that fixed it.
gaps="examples/read-the-doc-first 0e36dca
do/take-the-cheap-pick 21de49f
over-to-you/scratch-in-session-folder be4263e
red-pen/give-the-page-link 18fca20
do/settled-by-a-stated-deferral 81db017"

# Given the five recurring gaps: read the source before a design, take a cheap pick, keep scratch in the session folder, link the page, settle a question a stated deferral already answers
# When I run the whole suite
# Then each gap has a case, and each case fails against the skill text from before its fix
while read -r path commit; do
  name=${path#*/}
  if ! case_exists "$path"; then echo "FAIL S4-1 $name: no eval case at evals/$path"; fail=1; continue; fi
  if ! eval_case "$evals_plugin" "$name" "$name-now" --allow-tools "Bash"; then
    echo "FAIL S4-1 $name: the case fails against today's plugin"; fail=1; continue; fi
  plugin_before "$commit" "$evals_out/$name-before"
  if eval_case "$evals_out/$name-before" "$name" "$name-before" --allow-tools "Bash"; then
    echo "FAIL S4-1 $name: the case passes before $commit, so it can't go red"; fail=1
  else echo "ok   S4-1 $name: passes now, fails before $commit"; fi
done <<<"$gaps"
exit $fail
