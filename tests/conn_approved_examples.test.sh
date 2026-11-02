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

# Given a session in the middle of an effort with an open pull request or ticket
# When you type /conn
# Then the handoff is a comment on that pull request or ticket, and its link is in the reply
check "/conn comments the handoff on the pull request or ticket" \
  'grep -q "^name: conn$" "$conn" && grep -q "disable-model-invocation: true" "$conn" && grep -q "\"./skills/productivity/conn\"" "$plugin/.claude-plugin/plugin.json" && grep -q "Post it as a comment on the effort'"'"'s open pull request or ticket" "$conn" && grep -q "the comment'"'"'s link is in your reply" "$conn" && ! grep -q "temp folder" "$conn"'

# Given work on a project with no tracker, such as your machine config
# When you type /conn
# Then the handoff is a note in that project's vault folder, and its path is in the reply
check "/conn writes a vault note where there is no tracker" \
  'grep -q "With no tracker, write it as a note in the project'"'"'s vault folder" "$conn" && grep -q "the note'"'"'s path is in your reply" "$conn"'

# Given a session whose notes sit in its scratch folder
# When /conn posts the handoff
# Then the comment names no path outside the repo, and loose-lips checked it first
check "/conn posts only repo-relative paths, after loose-lips" \
  'grep -q "names no path outside the repo" "$conn" && grep -q "Run \`loose-lips\` on it before you post" "$conn"'

# Given a handoff comment on the effort's pull request or ticket
# When you ask sup in a fresh session
# Then sup names the handoff and checks each of its lines before it reports one
check "sup finds the handoff and checks it" \
  'sup="$plugin/skills/productivity/sup/SKILL.md"; grep -q "\*\*Handoff\*\*" "$sup" && grep -qi "check each of its lines before you report one" "$sup" && grep -q "Open it with a \`\*\*Handoff\*\*\` line" "$conn"'

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
