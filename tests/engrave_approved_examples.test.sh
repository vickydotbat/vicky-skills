#!/usr/bin/env bash
# approved-spec: the examples approved for "agents codify a lesson without being
# asked". Each check is named after its example. The hint is run as a hook, the
# rest reads the instructions that drive the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
hint="$root/scripts/lesson-hint.sh"
s="$root/skills/engineering/engrave/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
say() { jq -nc --arg p "$2" '{hook_event_name:"UserPromptSubmit",prompt:$p}' | CLAUDE_PLUGIN_OPTION_LESSON_HINT=$1 "$hint" 2>/dev/null; }

out=$(for p in "Codify that in the skills" "Note this as a lesson in the workbench" "For the future, sit at the gate" "From now on, hooks first"; do say true "$p"; echo; done)
check "given the lesson hint is on, when my message says codify that, note this as a lesson, for the future or from now on, then the agent engraves the lesson before its next reply, and the reply names the law it built and the file it went in" \
  '[ "$(grep -c "engrave" <<<"$out")" = 4 ] && grep -q "before your reply" <<<"$out" && grep -q "📓 Engraved: <snag> → <law> in \`<file>\`" "$s"'

check "given the lesson hint is on, when my message holds none of those phrases, then the agent gets no lesson hint" \
  '[ -x "$hint" ] && [ -z "$(say true "Make it so and merge it when done")" ]'

check "given the lesson hint is off, when my message says codify that, then the agent gets no lesson hint" \
  '[ -x "$hint" ] && [ -z "$(say false "Codify that")" ]'

check "given the agent made a mistake that I caught, when it engraves the lesson, then it builds a check or a hook where one can hold the rule, and a skill line only where neither can, saying why" \
  'grep -q "a check or a hook where one can hold the rule, and a skill line only where neither can, with the reason" "$s"'

check "given the agent works in a project's repo, I can push to the plugin's repo, and the lesson is about a skill or hook from the plugin, when it engraves the lesson, then the change lands in the plugin's repo, handed to an idle session there or built on a fresh branch in a worktree, without asking me first" \
  'grep -q "the plugin'"'"'s repo" "$s" && grep -q "only when the user can push to it" "$s" && grep -q "an idle session" "$s" && grep -q "a fresh branch from its main in a worktree, without asking" "$s"'

check "given the lesson is about the repo the agent works in, when it engraves the lesson, then the law lands in that repo, in a test, a standard or its agent docs, on the current effort's branch" \
  'grep -q "a test, a standard or its agent docs, on the current effort'"'"'s branch" "$s"'

le="$root/skills/engineering/loose-ends/SKILL.md"
check "given an effort hit a snag: a red check, a crash, a retry, or a correction from me, when the agent calls the effort done, then its report names each snag with the law built for it, or says why it needs none" \
  'grep -q "a red check, a crash, a retry, or a correction from the user" "$le" && grep -q "names each snag with the law built for it, or says why it needs none" "$le" && grep -q "engrave" "$le"'

cl="$root/skills/engineering/captains-log/SKILL.md"
check "given a captains-log retro reported its findings, when it ends, then every finding is engraved, or names what it waits on" \
  'grep -q "every finding is engraved, or names what it waits on" "$cl"'
exit $fail
