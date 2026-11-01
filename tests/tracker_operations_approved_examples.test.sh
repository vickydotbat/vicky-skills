#!/usr/bin/env bash
# approved-spec: the S3 examples of the .todo springboard (tracker
# operations), approved 2026-11-01. first-contact copies a template into a
# repo's docs/agents/issue-tracker.md, so each check reads every template.
set -u
dir="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/first-contact"
templates=("$dir"/issue-tracker-*.md)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
op() { grep -F -- "**$2**" "$1"; }

# Given a repo set up by first-contact with any of its trackers
# When an agent needs to move a ticket to a state
# Then the repo's issue-tracker doc names a Move a ticket to state operation with a command for that tracker
check "every tracker can move a ticket's state" \
  '[ ${#templates[@]} -eq 6 ] && (for t in "${templates[@]}"; do op "$t" "Move a ticket to <state>" | grep -q "\`" || exit 1; done)'

# Given a repo set up by first-contact with any of its trackers
# When an agent asks what was created or changed since a time
# Then the issue-tracker doc names a List items created or changed since time operation, capped at five items plus a count of the rest
check "every tracker can list what changed since a time" \
  '(for t in "${templates[@]}"; do l=$(op "$t" "List items created or changed since <time>"); grep -q "\`" <<<"$l" && grep -q "at most five, then a count of the rest" <<<"$l" || exit 1; done) && op "$dir/issue-tracker-plane.md" "List items created or changed since <time>" | grep -q "plane since <PROJECT> <time>"'

# Given an open ticket assigned to you with no Waits on line, and one whose Waits on line names your merge
# When an agent lists the tickets waiting on you
# Then only the second one is listed
check "waiting on you reads the Waits on line, not the assignee" \
  '(for t in "${templates[@]}"; do l=$(op "$t" "List tickets waiting on you"); grep -q "whose \`Waits on:\` line names you" <<<"$l" && ! grep -qiE "assignee|assigned" <<<"$l" || exit 1; done)'
exit $fail
