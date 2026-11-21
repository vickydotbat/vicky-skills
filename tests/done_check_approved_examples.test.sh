#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# shellcheck disable=SC2329 # helpers are called inside check()'s eval
# approved-spec: the examples approved on the notes "LC-1 A Stop hook runs the
# repo's check before done" and "LC-2 A subagent's done is checked too".
# done-check.sh records the tree's state on UserPromptSubmit and SubagentStart,
# and on Stop and SubagentStop runs the "Check:" line of docs/agents/testing.md
# when the tree changed since then. The first-contact example is an eval case,
# plugins/vicky-skills/evals/first-contact/writes-check-line.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
hook="$scripts/done-check.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
export DONE_CHECK_STATE="$fx/state"
repo="$fx/repo"
setup() { # setup <testing.md line or empty>
  rm -rf "$repo" "$DONE_CHECK_STATE"; mkdir -p "$repo/docs/agents"
  git -C "$repo" init -q; git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
  echo a >"$repo/a.txt"
  [ -z "$1" ] || printf '# Testing\n\n%s\n' "$1" >"$repo/docs/agents/testing.md"
  git -C "$repo" add -A; git -C "$repo" commit -qm init
}
ev() { # ev <event> [agent_id] [stop_hook_active]; returns 127 while the hook is missing
  [ -f "$hook" ] || return 127
  jq -nc --arg e "$1" --arg d "$repo" --arg a "${2:-}" --argjson s "${3:-false}" \
    '{hook_event_name:$e,session_id:"s1",cwd:$d,stop_hook_active:$s} + (if $a == "" then {} else {agent_id:$a} end)' |
    CLAUDE_PLUGIN_OPTION_GUARD_DONE_CHECK="${opt-}" bash "$hook" 2>/dev/null
}
blocked() { jq -e '.decision == "block"' <<<"$1" >/dev/null 2>&1; }
ran() { [ -f "$fx/ran" ]; }
failing="Check: touch $fx/ran; seq 1 100; exit 1"
passing="Check: touch $fx/ran; true"

# Given a repo whose docs/agents/testing.md has a "Check: <command>" line
# And the agent edited a file this turn
# When the agent ends the turn and the command exits non-zero
# Then the stop is blocked
# And the agent reads the command's last 40 lines of output
setup "$failing"; ev UserPromptSubmit >/dev/null; echo b >"$repo/a.txt"
out=$(ev Stop)
check "LC-1 E1 a failing check blocks the stop" 'blocked "$out"'
reason=$(jq -r '.reason // ""' <<<"$out" 2>/dev/null)
check "LC-1 E1 the reason holds the last 40 lines" 'grep -qx 100 <<<"$reason" && grep -qx 61 <<<"$reason" && ! grep -qx 60 <<<"$reason"'

# Given the same repo and a turn that edited a file
# When the agent ends the turn and the command exits 0
# Then the turn ends with nothing added
setup "$passing"; ev UserPromptSubmit >/dev/null; echo b >"$repo/a.txt"
out=$(ev Stop); rc=$?
check "LC-1 E2 a passing check ends the turn with nothing added" '[ $rc = 0 ] && [ -z "$out" ] && ran'

# Given a turn that edited no file
# When the agent ends the turn
# Then the check does not run
rm -f "$fx/ran"; setup "$failing"; ev UserPromptSubmit >/dev/null
out=$(ev Stop)
rc=$?
check "LC-1 E3 a turn that edited no file runs no check" '[ $rc = 0 ] && [ -z "$out" ] && ! ran'

# Given a repo with no "Check:" line
# When the agent ends a turn that edited a file
# Then the turn ends
# And the agent reads one line naming the missing "Check:" line
setup ""; ev UserPromptSubmit >/dev/null; echo b >"$repo/a.txt"
out=$(ev Stop)
check "LC-1 E4 no Check: line ends the turn with one note" '! blocked "$out" && [ "$(jq -r ".systemMessage // empty" <<<"$out" | grep -c "Check:")" = 1 ]'

# Given a repo with no "Check:" line
# And the missing-line note was already shown once this session
# When the agent ends another turn that edited a file
# Then the turn ends with nothing added
ev UserPromptSubmit >/dev/null; echo c >"$repo/a.txt"
out=$(ev Stop)
rc=$?
check "LC-1 E9 the missing-line note shows once a session" '[ $rc = 0 ] && [ -z "$out" ]'

# Given a repo whose line reads "Check: none"
# When the agent ends a turn that edited a file
# Then the turn ends with nothing added
setup "Check: none"; ev UserPromptSubmit >/dev/null; echo b >"$repo/a.txt"
out=$(ev Stop); rc=$?
check "LC-1 E5 Check: none adds nothing" '[ $rc = 0 ] && [ -z "$out" ]'

# Given the check has blocked the stop 3 times in a row
# When the agent ends the turn again
# Then the turn ends
# And the agent reads that the check still fails
setup "$failing"; ev UserPromptSubmit >/dev/null; echo b >"$repo/a.txt"
n=0; for i in 1 2 3; do blocked "$(ev Stop "" true)" && n=$((n + 1)); done
out=$(ev Stop "" true)
check "LC-1 E6 three blocks in a row" '[ $n = 3 ]'
check "LC-1 E6 the fourth stop ends the turn saying the check still fails" '! blocked "$out" && jq -r ".systemMessage // empty" <<<"$out" | grep -qi "still fails"'

# Given a check that runs past its 300-second limit
# When the agent ends the turn
# Then the stop is blocked with a line saying the check timed out
setup "Check: touch $fx/ran; sleep 20"; ev UserPromptSubmit >/dev/null; echo b >"$repo/a.txt"
out=$(DONE_CHECK_TIMEOUT=1 ev Stop)
check "LC-1 E7 a check past its limit blocks saying it timed out" 'blocked "$out" && jq -r .reason <<<"$out" | grep -qi "timed out"'
mkdir -p "$fx/bin"; printf '#!/usr/bin/env bash\necho "$1" >"%s/limit"\nexit 124\n' "$fx" >"$fx/bin/timeout"; chmod +x "$fx/bin/timeout"
rm -rf "$DONE_CHECK_STATE"; ev UserPromptSubmit >/dev/null; echo d >"$repo/a.txt"
PATH="$fx/bin:$PATH" ev Stop >/dev/null
check "LC-1 E7 the default limit is 300 seconds" '[ "$(cat "$fx/limit" 2>/dev/null)" = 300 ]'
rm -rf "$DONE_CHECK_STATE"; ev UserPromptSubmit >/dev/null; echo c >"$repo/a.txt"; DONE_CHECK_TIMEOUT=1 ev Stop >/dev/null

# Given the check timed out on the previous stop
# When the agent ends the turn again
# Then the turn ends and the check does not run again
rm -f "$fx/ran"; out=$(DONE_CHECK_TIMEOUT=1 ev Stop "" true); rc=$?
check "LC-1 E10 after a timeout the next stop ends without running the check" '[ $rc = 0 ] && ! blocked "$out" && ! ran'

# Given the plugin option guard_done_check is false
# When the agent ends a turn that edited a file
# Then the check does not run
rm -f "$fx/ran"; setup "$failing"; ev UserPromptSubmit >/dev/null; echo b >"$repo/a.txt"
out=$(opt=false ev Stop); rc=$?
check "LC-1 E8 the option off runs no check" '[ $rc = 0 ] && [ -z "$out" ] && ! ran'

# Given the agent changed a tracked file through a REPL script or a shell redirect
# When the agent ends the turn and the check exits non-zero
# Then the stop is blocked
setup "$failing"; ev UserPromptSubmit >/dev/null; printf 'x\n' >>"$repo/a.txt"
check "LC-1 E11 a change made by a shell redirect is checked" 'blocked "$(ev Stop)"'

# Given a repo with a "Check:" line
# And a subagent that edited a file
# When the subagent stops and the command exits non-zero
# Then the subagent is sent back with the failing output
setup "$failing"; ev SubagentStart ag1 >/dev/null; echo b >"$repo/a.txt"
out=$(ev SubagentStop ag1)
check "LC-2 E1 a failing check sends the subagent back with its output" 'blocked "$out" && jq -r .reason <<<"$out" | grep -qx 100'

# Given a subagent the check has blocked 3 times in a row
# When it stops again
# Then it returns to the parent and the parent reads that the check still fails
for i in 1 2; do ev SubagentStop ag1 true >/dev/null; done
out=$(ev SubagentStop ag1 true)
check "LC-2 E2 a subagent's fourth stop returns saying the check still fails" '! blocked "$out" && jq -r ".systemMessage // empty" <<<"$out" | grep -qi "still fails"'

# Given a subagent blocked 3 times
# When the parent ends its own turn
# Then the parent's block count starts at 0
ev UserPromptSubmit >/dev/null; echo c >"$repo/a.txt"
check "LC-2 E4 the parent's count starts at 0" 'blocked "$(ev Stop)"'

# Given a subagent that edited no file
# When it stops
# Then the check does not run
rm -f "$fx/ran"; setup "$failing"; ev SubagentStart ag2 >/dev/null
out=$(ev SubagentStop ag2); rc=$?
check "LC-2 E3 a subagent that edited no file runs no check" '[ $rc = 0 ] && [ -z "$out" ] && ! ran'

exit $fail
