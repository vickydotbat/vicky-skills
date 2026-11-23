#!/usr/bin/env bash
# approved-spec: the examples the user ticked on 2026-11-23 for the star
# "Soapbox skill". Each shows only in what the agent writes, so each is an eval
# case under plugins/vicky-skills/evals/soapbox. Run by hand: each run costs a Claude session.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
fail=0
# S1: Given the user types soapbox it after a reply that weighed options
# When the agent answers
# Then the reply opens with the agent's opinion in one or two plain sentences
# And each option says whether the agent argues for it or against it, and why
# And each option follows with at least one pro and one con
# And the reply ends with the agent's pick and one way to answer
run soapbox/pitch-case-options-pick s1 "the case, each option's pros and cons, then the pick"
# S2: Given a soapbox about a technical choice
# When the agent writes it
# Then each option is explained without jargon a non-technical reader would need to look up
# And any term it must use is explained in a few words the first time
run soapbox/plain-words s2 "no jargon a non-technical reader would look up"
# S3: Given a soapbox with three options
# When the agent writes it
# Then the whole reply stays under 200 words
# And each pro or con is one short line
run soapbox/brief-under-200 s3 "under 200 words, one short line per pro or con"
# S4: Given the user types soapbox it when the last reply offered no options
# When the agent answers
# Then it states its one recommendation with its pros and cons
# And it does not invent options to fill the format
run soapbox/nothing-to-weigh s4 "one recommendation, no invented options"
# S5: Given the user types soapbox it in the middle of a task
# When the agent answers
# Then it gives its soapbox and changes no file and runs no command for the task
# And it goes on only after the user answers
run soapbox/opinion-before-work s5 "the soapbox comes first, the task waits"
exit $fail
