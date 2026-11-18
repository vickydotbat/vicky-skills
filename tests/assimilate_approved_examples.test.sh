#!/usr/bin/env bash
# approved-spec: the assimilate examples, ticked on the drafts page
# 2026-11-17. The behaviour is the agent's, so each check reads the plugin
# files that drive it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
sk="$plugin/skills/shipping/assimilate/SKILL.md"
cause="$plugin/skills/shipping/review/CAUSE.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
has() { grep -qF -- "$2" "$1"; }
# The Borg line opens the comment, and the plain paragraph comes after it.
borg_first() { awk '/Open the verdict comment with/{o=NR} /Then a plain paragraph/{p=NR} END{exit !(o && p && o<p)}' "$sk"; }

# Given any pull request, a fix, a feature or a refactor
# When you tell an agent to assimilate it
# Then a comment on that pull request answers four questions: do the changes hold, is the principle behind them met, do they fix a cause or a symptom, and is there a better way
# And it lists what stays from the branch
check "E1 the verdict answers four questions about any change, and lists what stays" \
  'has "$sk" "name: assimilate" && grep -q "\"./skills/shipping/assimilate\"" "$plugin/.claude-plugin/plugin.json" && has "$sk" "any change: a fix, a feature or a refactor" && has "$sk" "**Do the changes hold?**" && has "$sk" "**List what stays**" && has "$sk" "Post the verdict" && has "$cause" "**Is the principle met?**" && has "$cause" "**Cause or symptom?**" && has "$cause" "**Is there a better way?**"'

# Given a change that passes locally but breaks a CI job the diff never touches
# When an agent assimilates it
# Then the verdict's first answer names that CI break, checked against the current main
check "E2 do the changes hold is traced past the diff, through CI, against current main" \
  'has "$sk" "past the diff" && has "$sk" "how each CI job gets the files the change writes" && has "$sk" "checked against main at" && has "$sk" "git merge-tree --write-tree"'

# Given a fix that adds a guard against a bad state
# When an agent assimilates it
# Then the verdict says whether the bad state could be made impossible instead, and when it can, the better way describes that design
check "E3 a guard is asked whether the bad state could be made impossible" \
  'has "$cause" "For a guard, ask whether the design could make the bad state impossible instead" && has "$cause" "the better way describes that design"'

# Given a pull request someone else opened
# And its verdict finds the agent can make it better: a change that doesn't hold, a principle missed, a symptom fixed in place of the cause, or a better way than the branch
# When an agent assimilates it
# Then the pull request is assigned to you
# And its comment opens in the Borg voice, such as We Are Borg. Your PR has been assimilated. Resistance is futile.
# And a plain second paragraph tells other agents not to push to it
check "E4 claiming someone else's pull request, when the verdict finds work, assigns it and posts the Borg lines" \
  'has "$sk" "**Claim it only when the verdict finds work to do**" && has "$sk" "a change that doesn'"'"'t hold, a principle missed, a symptom fixed in place of the cause, or a better way than the branch" && has "$sk" "Assign the pull request to the user" && has "$sk" "We Are Borg. Your PR has been assimilated. Resistance is futile." && has "$sk" "Other agents: do not push to this PR. The agent that claimed it is repurposing it." && borg_first'

# Given a pull request you or one of your agents opened
# When an agent assimilates it
# Then it posts the verdict, with no Borg line and no change of assignee
check "E5 the user's own pull request gets no Borg line and keeps its assignee" \
  'has "$sk" "gets no Borg line and keeps its assignee"'

# Given you asked for a verdict and said a new session will take over
# When the verdict is posted
# Then the agent stops, and its reply links the comment
check "E6 a verdict-only ask stops at the verdict" \
  'has "$sk" "When the user asked only for a verdict, stop" && has "$sk" "the reply links the comment"'

# Given an assimilated pull request whose verdict names a better way
# When you ask an agent to take it over
# Then it builds the verdict on that pull request's own branch, and opens no new pull request
check "E7 a takeover builds on the pull request's own branch" \
  'has "$sk" "run \`do\` with the verdict as its source" && has "$sk" "on the pull request'"'"'s own branch" && has "$sk" "open no new pull request"'

# Given this change has landed
# When you read your global agent file
# Then the Borg paragraph is gone from it, and the assimilate skill holds the rule
# (The global file lives outside this repo: this checks the skill's half.)
check "E8 the assimilate skill holds the claim rule" \
  'has "$sk" "The claiming agent, and the user'"'"'s agents working for it, may push."'

# Given a pull request whose design grew out of earlier workarounds
# When an agent asks whether there is a better way
# Then it first works out its own solution from the problem alone, as if reinventing the wheel, without starting from the branch or main as they stand
# And only then compares that solution with the branch, and says which is better and why
check "E12 the better way starts from the problem, not the branch" \
  'has "$cause" "Reinvent the wheel" && has "$cause" "from the problem alone, as if the branch and main as they stand did not exist" && has "$cause" "Only then compare it with the change, and say which is better and why"'

# Given a pull request someone else opened
# And its verdict finds the changes hold, the principle is met, the cause is fixed, and there's no better way
# When an agent assimilates it
# Then it posts the verdict as a grade only, with no Borg line and no change of assignee
# And it asks you how to proceed, with two options at most and its pick
check "E13 a sound pull request is graded, not claimed" \
  'has "$sk" "post the verdict as a grade only, with no Borg line and no change of assignee" && has "$sk" "ask the user how to proceed, with two options at most and your pick"'
exit $fail
