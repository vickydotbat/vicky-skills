#!/usr/bin/env bash
# PreToolUse hook (Bash, Edit, Write, MultiEdit; guard_same_refusal, on by
# default): refuses a tool call identical to the call just before it, when a
# hook refused that one. A refusal says what to change; the same call again
# meets the same refusal. A call in between (a rebase, a skill start, a read)
# can change what the hook sees, so only a back-to-back repeat is stopped. The
# current call, when Claude Code has already written it, has no result yet, and
# only a call with a result counts. Identical calls sent side by
# side in one message have no result yet, so only a later repeat is stopped.
# A refusal is a tool result with is_error set whose text holds "hook error",
# as Claude Code writes a PreToolUse denial. Only the transcript's last 200
# lines are read.
case "${CLAUDE_PLUGIN_OPTION_GUARD_SAME_REFUSAL:-true}" in false|0) exit 0 ;; esac
payload=$(cat)
transcript=$(jq -r '.transcript_path // empty' <<<"$payload" 2>/dev/null)
now=$(jq -c '{n: .tool_name, i: .tool_input}' <<<"$payload" 2>/dev/null)
# The last tool call before this one, and whether a hook refused it.
same=$(tail -n 200 "$transcript" 2>/dev/null | jq -s --argjson now "${now:-null}" '
  [.[] | .message.content[]? | select(.type == "tool_use" or .type == "tool_result")] as $b
  | ([$b[] | select(.type == "tool_use") | select(.id as $i | any($b[]; .type == "tool_result" and .tool_use_id == $i))] | last) as $u
  | $u != null and {n: $u.name, i: $u.input} == $now
    and any($b[]; .type == "tool_result" and .tool_use_id == $u.id and .is_error == true
                  and ((.content | tostring) | test("hook error")))' 2>/dev/null)
[ "$same" = true ] || exit 0
jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"same-refusal: refused, this is the same call a hook refused just before, unchanged, so it meets the same refusal. Read that refusal again and do what it says first: change the call, run the step it names, or wait as it says."}}'
