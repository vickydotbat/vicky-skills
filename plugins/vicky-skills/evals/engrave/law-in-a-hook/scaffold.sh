#!/usr/bin/env bash
# A small plugin repo: one skill, one hook with its test, and an eval suite.
set -eu
git init -q -b main .
mkdir -p .claude-plugin skills/greet hooks tests evals/greet/says-hello/graders
echo '{"name":"tiny","skills":["./skills/greet"]}' > .claude-plugin/plugin.json
cat > skills/greet/SKILL.md <<'MD'
---
name: greet
description: Greet the user. Use when the user says hello.
---
# Greet

1. Say hello to the user by name.
MD
cat > hooks/guard.sh <<'SH'
#!/usr/bin/env bash
# PreToolUse hook: refuses nothing yet.
exit 0
SH
cat > tests/guard.test.sh <<'SH'
#!/usr/bin/env bash
# guard.sh lets a plain command through.
echo '{"tool_input":{"command":"ls"}}' | bash hooks/guard.sh && echo ok
SH
printf -- '---\nmax_turns: 3\n---\nhello\n' > evals/greet/says-hello/prompt.md
printf -- '---\ntype: regex\npattern: hello\nflags: i\n---\n' > evals/greet/says-hello/graders/word.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
