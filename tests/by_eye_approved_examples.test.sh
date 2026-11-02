#!/usr/bin/env bash
# approved-spec: the by-eye examples Vicky approved on 2026-11-02. The
# behaviour is the agent's, so each check reads the skill text that drives it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
skill="$plugin/skills/engineering/by-eye/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
has() { grep -qF -- "$2" "$1" 2>/dev/null; }

# Given a change to a page you can see in the repo's dev site
# When the agent checks it by eye
# Then no browser window opens on your screen
check "no window on your screen" \
  'has "$skill" "Use the headless server" && has "$skill" "never fall back to the windowed one" && has "$skill" "stop before you start anything"'

# Given a page that only shows after you sign in
# When the agent checks it by eye
# Then the windowed browser opens, and the agent says it needs you to sign in
check "sign-in is the exception" \
  'has "$skill" "Use the windowed \`playwright\` server only for a page that shows after the user signs in, and say first that it needs the user to sign in"'

# Given a by-eye check
# When it runs
# Then the page is looked at in light mode, dark mode, on a narrow screen and with the keyboard alone
check "light, dark, narrow and keyboard" \
  'has "$skill" "light mode, dark mode, a narrow screen" && has "$skill" "the keyboard alone"'

# Given a by-eye check that has finished
# When you read its report
# Then each screenshot is attached, and kept in the repo's ignored .playwright-mcp folder
check "you see what it saw" \
  'has "$skill" "saved in the repo'"'"'s ignored \`.playwright-mcp\` folder" && has "$skill" "Add \`.playwright-mcp/\` to the repo'"'"'s \`.gitignore\` first" && has "$skill" "attach them to the report"'

# Given the agent started the dev site for a check
# When the check ends
# Then the dev site is stopped, and it ran under a memory cap the whole time
check "the dev site stops after" \
  'has "$skill" "under a memory cap" && has "$skill" "MemoryMax=" && has "$skill" "Stop the dev site** by the id you saved. Done when its address no longer answers"'

# Given a look only a person can judge, such as whether a page feels right
# When a build reaches it
# Then it comes to you as an over-to-you item, not as a by-eye check
check "taste stays with you" \
  'has "$skill" "it goes to the user as an \`over-to-you\` item" && has "$plugin/skills/productivity/over-to-you/SKILL.md" "\`by-eye\`"'

# Given a build whose approved examples include something you see on a page
# When do turns that example green
# Then the agent runs by-eye on it before the next example
check "where builds use it" \
  'has "$plugin/skills/engineering/do/SKILL.md" "run \`by-eye\` on it before the next example"'
exit $fail
