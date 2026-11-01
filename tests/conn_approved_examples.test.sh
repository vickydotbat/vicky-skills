#!/usr/bin/env bash
# approved-spec: the S6 examples of the .todo springboard (conn), approved
# 2026-11-01. The behaviour is the agent's, so each check reads the plugin
# files that drive it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
conn="$plugin/skills/productivity/conn/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a session in the middle of an effort
# When you type /conn
# Then the handoff is written and its path is in the reply, as /you-have-the-conn did before
check "/conn writes the handoff" \
  'grep -q "^name: conn$" "$conn" && grep -q "disable-model-invocation: true" "$conn" && grep -q "\"./skills/productivity/conn\"" "$plugin/.claude-plugin/plugin.json" && grep -q "Done when the path is in your reply" "$conn"'

# Given the plugin after the rename
# When you read any skill, hook, test or the README
# Then each one says conn, and none says you-have-the-conn
check "the old name is gone everywhere" \
  '[ ! -e "$plugin/skills/productivity/you-have-the-conn" ] && ! grep -rq "you-have-the-conn" "$plugin" "$root/README.md" "$root/tests" --exclude=conn_approved_examples.test.sh && grep -q "^| \*\*\`conn\`\*\*" "$root/README.md" && grep -q "/conn\`" "$plugin/skills/productivity/council-of-elrond/SKILL.md"'

# Given work with an open ticket and pull request
# When you type /conn
# Then the tickets and pull request body get their Done, Next and Waits on first, and the handoff holds only the goal, the links and what the session was in the middle of
check "the handoff points at the tickets and holds no state of its own" \
  'grep -q "Write the state where it lives first" "$conn" && grep -q "Status section" "$conn" && grep -q "holds only the goal, the links and what this session was in the middle of" "$conn" && ! grep -q "Prove each state claim" "$conn"'
exit $fail
