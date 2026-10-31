#!/usr/bin/env bash
# approved-spec: the examples approved for engrave's routing order: plugin,
# user setup, repo. Each check is named after its example, and reads the
# instructions that drive the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
s="$root/skills/engineering/engrave/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step3() { awk '/^3\. /{on=1} /^4\. /{on=0} on' "$s"; }
check "given I can push to the plugin's repo, and a lesson would help an agent in any repo, when the agent engraves it, then the rule lands in the plugin's repo" \
  'step3 | grep -q "only when the user can push to it" && step3 | grep -q "would help an agent in any repo" && step3 | grep -q "viewerPermission" && jq -e ".repository | test(\"github.com/\")" "$root/.claude-plugin/plugin.json" >/dev/null'
check "given a user who can't push to the plugin's repo, and a lesson about a pattern across tasks or repos, when the agent engraves it, then the rule lands in the user's own agent setup, such as their CLAUDE.md" \
  'step3 | grep -q "a pattern across tasks or repos" && step3 | grep -q "CLAUDE.md"'
check "given a lesson about the repo the agent works in, and nothing in it would help another repo, when the agent engraves it, then the rule lands in that repo" \
  'step3 | grep -q "a lesson about that repo"'
check "given a lesson with a part any repo could use and a part only this repo needs, when the agent engraves it, then each part lands in its own home, checked in the order plugin, user setup, repo" \
  'step3 | grep -q "each part to its own home, checked in the order plugin, user setup, repo"'
exit $fail
