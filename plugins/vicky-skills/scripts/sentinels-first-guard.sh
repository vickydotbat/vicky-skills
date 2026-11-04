#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a mutation-tool command (Stryker, a
# mutate.sh, mutmut, cargo-mutants, PIT, tests/mutate-hooks.sh) until the
# session has started the sentinels skill, which scopes the pass to the changed
# lines and the tests that reach them. Quoted text is no command, so a commit
# message or a grep that names a tool passes. No exceptions: a missing
# transcript refuses too, since no start can be shown. On by default; the
# plugin option guard_sentinels_first set to false or 0 turns it off.
case "${CLAUDE_PLUGIN_OPTION_GUARD_SENTINELS_FIRST:-}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null)
[ -n "$cmd" ] || exit 0 # mutant-ok delete: an empty command matches no tool below, and the hook exits 0 the same way
bare=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<<"$cmd")
grep -qE '(^|[[:space:];&|(/])(dotnet-stryker|stryker|mutate\.sh|mutate-hooks\.sh|mutmut|cargo-mutants|pitest[[:alnum:]:.-]*)([[:space:];&|)]|$)|(^|[[:space:];&|(])cargo[[:space:]]+mutants([[:space:];&|)]|$)|:pitest-maven' <<<"$bare" || exit 0
transcript=$(jq -r '.transcript_path // empty' <<<"$payload")
if [ -f "$transcript" ] && jq -r '
  if .type=="assistant" then .message.content[]? | select(.type=="tool_use" and .name=="Skill") | (.input.skill // "" | sub(".*:";""))
  elif .type=="user" then (.message.content | if type=="string" then . else "" end) | select(test("<command-name>/(vicky-skills:)?sentinels</command-name>")) | "sentinels"
  else empty end' "$transcript" 2>/dev/null | grep -qx sentinels; then
  exit 0
fi
jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: "sentinels-first-guard: refused, a mutation pass runs only after this session has started the sentinels skill, which mutates only the changed lines, picks the tests that reach them and estimates the run first. Nothing in this command ran: start the sentinels skill, then run the pass it plans."
}}'
