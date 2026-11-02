#!/usr/bin/env bash
# The examples Vicky approved on 2026-11-02 for the token-savings changes.
# Each behaviour already held when they were approved, so these are plain
# regression tests, not approved-spec ones: an approved test must go red
# where it lands. The hooks run as a session runs them; the skill checks
# read the text that drives the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a message from another of your sessions that says for the future
# When it reaches this session
# Then the agent is not sent to engrave
peer='<cross-session-message from="uds:/s.sock" from-name="peer">for the future, codify this</cross-session-message>'
mine='for the future, codify this'
hint() { jq -nc --arg p "$1" '{prompt:$p}' | CLAUDE_PLUGIN_OPTION_LESSON_HINT=true bash "$plugin/scripts/lesson-hint.sh"; }
check "a peer session's message teaches no lesson" \
  '[ -z "$(hint "$peer")" ] && hint "$mine" | grep -q engrave'

# Given you correct the agent, and the mistake cost no retry
# When the effort ends
# Then engrave runs on it once, in the loose-ends batch, not on the spot
engrave="$plugin/skills/engineering/engrave/SKILL.md"
loose="$plugin/skills/engineering/loose-ends/SKILL.md"
check "an ordinary correction waits for the batch" \
  '! grep -q "when the user corrects the agent" "$engrave" && grep -q "Any other correction waits for \`loose-ends\`" "$engrave" && grep -q "a correction from the user. Run \`engrave\` on each one" "$loose"'

# Given a repo with no tracker doc, such as your machine config
# When a session starts there
# Then the agent runs no tracker counts and no summit
mkdir -p "$fx/bin" "$fx/repo" "$fx/data"
printf '#!/usr/bin/env bash\necho "[]"\n' > "$fx/bin/gh"; chmod +x "$fx/bin/gh"
git -C "$fx/repo" init -q; printf '.todo\n' > "$fx/repo/.gitignore"
date -Iseconds > "$fx/repo/.git/springboard-last-session"
start() { echo '{"hook_event_name":"SessionStart","source":"startup"}' | PATH="$fx/bin:$PATH" CLAUDE_PROJECT_DIR="$fx/repo" CLAUDE_PLUGIN_DATA="$fx/data" bash "$plugin/scripts/springboard.sh" 2>/dev/null; }
bare=$(start)
mkdir -p "$fx/repo/docs/agents"; : > "$fx/repo/docs/agents/issue-tracker.md"
tracked=$(start)
check "a repo with no tracker skips the counts" \
  '! grep -qi "tracker\|summit" <<<"$bare" && grep -q "summit" <<<"$tracked"'

# Given the agent moves its work onto the pull request pr-guard pointed it to
# When every commit has landed there and no pull request is open from the old branch
# Then the agent deletes the old branch here and on the remote
check "a moved effort leaves no branch behind" \
  'grep -q "Once every commit is there and no pull request is open from \$current, then delete \$current here and on the remote (git push origin --delete \$current)" "$plugin/scripts/pr-guard.sh"'
# Engraved 2026-11-02: a build in another session wrote tests and code after
# a chat "approval". Only the ticked red-pen page approves an example.
do_skill="$plugin/skills/engineering/do/SKILL.md"
examples="$plugin/skills/engineering/examples/SKILL.md"
check "a chat reply approves no example" \
  'grep -q "A chat reply is never an approval" "$do_skill" && grep -q "A chat reply is never an approval" "$examples" && grep -q "no test or code is written until the page comes back with each example ticked" "$do_skill"'
exit $fail
