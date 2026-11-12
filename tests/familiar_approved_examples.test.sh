#!/usr/bin/env bash
# Approved examples for the familiar skill (S2 to S5). The plugin owns three
# seams: the session lister, the voice hook that sets the voice on the turn
# /familiar is typed, and the skill text the agent follows. What the agent does
# with a watch line is model behaviour no shell test can run, so those
# examples are held by the skill's own words.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
skill="$root/skills/productivity/familiar/SKILL.md"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
has() { grep -qF -- "$1" "$skill" 2>/dev/null; }
# A projects folder with live sessions, one ended, and the familiar's own.
mkdir -p "$fx/projects/-repo-a" "$fx/projects/-repo-b"
live() { jq -nc --arg c "$2" '{type:"user",cwd:$c,message:{content:"hi"}}' > "$fx/projects/$1.jsonl"; }
live -repo-a/aaa /repo/a; live -repo-a/bbb /repo/a; live -repo-b/ccc /repo/b; live -repo-b/self /repo/b
live -repo-b/done /repo/b; jq -nc '{type:"cost-state"}' >> "$fx/projects/-repo-b/done.jsonl"
sessions() { CLAUDE_CODE_SESSION_ID=self FAMILIAR_PROJECTS_DIR="$fx/projects" bash "$root/skills/productivity/familiar/scripts/familiar-sessions.sh"; }
# The voice hook, given what the user typed and the transcript so far.
voice() { printf '%s\n' "$2" > "$fx/t.jsonl"
  jq -nc --arg p "$1" --arg t "$fx/t.jsonl" '{prompt:$p,transcript_path:$t}' | env ${KIND:+CLAUDE_PLUGIN_OPTION_FAMILIAR_KIND=$KIND} bash "$root/scripts/familiar-voice.sh" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

# Given other sessions are live on the machine
# When you type /familiar
# Then this session is the familiar for the rest of the session: it arms a watch on each live session, opens a debt note for each, and replies with the sessions and notes
check "E16 /familiar is typed only" 'grep -qx "disable-model-invocation: true" "$skill"'
check "E16 it arms a watch and opens a debt note for each live session" 'has "Arm one watch per session" && has "open one debt note per session" && has "reply with each session and its note"'
check "E16 the voice holds from the /familiar turn on" '[ -n "$(voice "/familiar" "")" ]'

# Given no familiar kind is set
# When the familiar speaks to you
# Then it speaks as the owl: quietly, with a tip or a debt line only
check "E17 the owl by default" 'voice "/familiar" "" | grep -qF "You are the owl familiar: quiet. Speak to the user only with a tip or a debt line."'

# Given the familiar kind is set to the imp
# When the familiar speaks to you
# Then it hisses, laughs and mocks, and it logs the same snags the owl would
check "E18 the imp hisses, laughs and mocks, and logs the same snags" 'KIND=imp voice "/familiar" "" | grep -qF "You are the imp familiar: hiss, laugh and mock." \
  && KIND=imp voice "/familiar" "" | grep -qF "The kind changes your voice only: log every snag, whatever the kind."'

# Given this session is the familiar
# When it sends a message to another session
# Then the message is plain agent language, with no voice
check "E19 plain words to other agents" 'voice "/familiar" "" | grep -qF "To another session or agent, write plain agent language, with no voice."'

# Given you typed /familiar earlier in this session
# When any later line reaches you
# Then it is in the familiar's voice, until the session ends
check "E20 the voice holds until the session ends" 'voice "/familiar" "" | grep -qF "Every line the user sees stays in this voice until the session ends."'

# Given the familiar is watching
# When a watched session shows a flow you could run smoother, such as a command you type often or a prompt a setting would spare
# Then you get one tip line when that stretch of work ends
check "E22 one tip when the stretch ends" 'has "send the user one tip line when that stretch of work ends"'

# Given an over-to-you sitting is open
# When a tip comes up
# Then the tip waits until the sitting ends
check "E23 no tip mid-sitting" 'has "While an over-to-you sitting is open, a tip waits until it ends"'

# Given the familiar already sent a tip in this stretch of work
# When a second tip comes up
# Then it waits for the next stretch
check "E24 at most one tip per stretch" 'has "At most one tip per stretch of work: a second waits for the next stretch"'

# Given a snag that an agent caused
# When the familiar notes it
# Then it becomes a debt line, and you get no tip about it
check "E25 an agent mistake is debt, not a tip" 'has "A snag an agent caused is a debt line, never a tip"'

# Given three other sessions are live
# When you type /familiar
# Then each gets its own watch and debt note, and every line names its session
check "E26 every live session is listed" '[ "$(sessions | wc -l)" = 3 ] && sessions | grep -q "^aaa " && sessions | grep -q "^bbb " && sessions | grep -q "^ccc "'

# Given the familiar watches two sessions
# When one of them hands off
# Then only that session's items are worked, and the other watch goes on
check "E28 one handoff closes one session" 'has "work only that session'"'"'s note, and keep every other watch armed"'

# Given this session is the familiar
# When it lists the live sessions
# Then it leaves itself out
check "E29 the familiar never watches itself" '! sessions | grep -q "^self "'

exit $fail
