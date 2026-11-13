#!/usr/bin/env bash
# Found work from the 13 November backlog triage, held as the skill lines that
# carry it. Each line is model behaviour no shell test can run, so these
# checks hold the words the agent reads.
set -u
skills="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills"
review="$skills/engineering/review/SKILL.md"
familiar="$skills/productivity/familiar/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a review with no ticket behind it
# When review dispatches its reviewers
# Then the spec axis still runs, on the user's ask as the spec
check "review runs the spec axis on the user's ask when there is no ticket" '! grep -qF "skip it when there is none" "$review" && grep -qF "with no ticket, give it the user'"'"'s ask, in their words, as the spec" "$review"'

# Given the idle-stop guard was cut
# When familiar tells the agent to end a watch turn silent
# Then it names no hook that no longer exists
check "familiar names no idle-stop guard" '! grep -qi "idle-stop" "$familiar"'

# Given a friction complaint about one repo
# When the familiar watches the fix
# Then a fix that adds a refusal, or moves the rule into the shared plugin, is a snag
check "familiar's snag shapes hold the friction fix that adds friction" 'grep -qF "A fix for a friction complaint that adds a refusal, or moves a rule one repo owns into the shared plugin" "$familiar"'

# Given the familiar wants to reach a peer session
# When it has not listed the agents
# Then a probe message is a snag
check "familiar's snag shapes hold the probe sent before ListAgents" 'grep -qF "A message sent to a peer session to find it, before \`ListAgents\` was read" "$familiar"'
exit $fail
