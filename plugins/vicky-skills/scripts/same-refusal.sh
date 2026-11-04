#!/usr/bin/env bash
# PreToolUse hook (Bash, Edit, Write, MultiEdit; guard_same_refusal, on by
# default): refuses a tool call identical to the call just before it, when a
# hook refused that one. A refusal says what to change; the same call again
# meets the same refusal. A call in between (a rebase, a skill start, a read)
# can change what the hook sees, so only a back-to-back repeat is stopped.
case "${CLAUDE_PLUGIN_OPTION_GUARD_SAME_REFUSAL:-true}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
transcript=$(jq -r '.transcript_path // empty' <<<"$payload" 2>/dev/null)
now=$(jq -c '{n: .tool_name, i: .tool_input}' <<<"$payload")
# The last tool call before this one, and whether a hook refused it.
last=$(tail -n 200 "$transcript" 2>/dev/null | jq -cs '
  [.[] | .message.content[]? | select(.type == "tool_use" or .type == "tool_result")] as $b
  | ([$b[] | select(.type == "tool_use")] | last) as $u
  | if $u == null then empty else
      {n: $u.name, i: $u.input,
       refused: any($b[]; .type == "tool_result" and .tool_use_id == $u.id and .is_error == true
                          and ((.content | tostring) | test("hook error")))}
    end' 2>/dev/null)
[ "$(jq -r '.refused' <<<"$last" 2>/dev/null)" = true ] || exit 0
[ "$(jq -c '{n, i}' <<<"$last")" = "$now" ] || exit 0
jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"same-refusal: refused, this is the same call a hook refused just before, unchanged, so it meets the same refusal. Read that refusal again and do what it says first: change the call, run the step it names, or wait as it says."}}'
