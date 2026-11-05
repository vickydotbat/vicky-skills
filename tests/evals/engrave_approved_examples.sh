#!/usr/bin/env bash
# approved-spec: the examples the user ticked on 2026-11-05 for "Skill evals -
# a snag becomes a case": engrave writes an eval case beside a law it puts in
# a skill, and names the case on the ledger line, but writes none for a law
# that is a hook with its own test. Run by hand: each run costs a Claude session.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
fail=0

# Given a snag whose law lands in a skill
# When engrave builds the law
# Then the same pull request holds an eval case for that snag, and the ledger line names the case
if ! case_exists engrave/law-in-a-skill; then echo "FAIL S3-1 no eval case at evals/engrave/law-in-a-skill"; fail=1
elif eval_case "$evals_plugin" law-in-a-skill s3-1 --allow-tools "Bash"; then echo "ok   S3-1 a law in a skill brings its case"
else echo "FAIL S3-1 a law in a skill brings its case"; fail=1; fi

# Given a snag whose law is a hook with its own test
# When engrave builds the law
# Then no eval case is required, since the hook's test already covers it
if ! case_exists engrave/law-in-a-hook; then echo "FAIL S3-2 no eval case at evals/engrave/law-in-a-hook"; fail=1
elif eval_case "$evals_plugin" law-in-a-hook s3-2 --allow-tools "Bash"; then echo "ok   S3-2 a law in a hook needs no case"
else echo "FAIL S3-2 a law in a hook needs no case"; fail=1; fi

exit $fail
