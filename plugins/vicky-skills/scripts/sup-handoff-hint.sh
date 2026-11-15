#!/usr/bin/env bash
# UserPromptSubmit and PostToolUse (Skill) hook: when sup starts, typed as /sup
# or called as a skill, runs find-handoff.sh in the session's folder and adds
# its output as context, so the catch-up reads every handoff place whether or
# not the agent runs step 1's command. On unless the plugin option
# sup_handoff_hint is false.
case "${CLAUDE_PLUGIN_OPTION_SUP_HANDOFF_HINT:-}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
input=$(cat)
event=$(jq -r '.hook_event_name // ""' <<<"$input")
case "$event" in
  UserPromptSubmit) grep -Eq '^[[:space:]]*(/(vicky-skills:)?sup([[:space:]]|$)|<command-name>/(vicky-skills:)?sup</command-name>)' <<<"$(jq -r '.prompt // ""' <<<"$input")" || exit 0 ;;
  PostToolUse) [ "$(jq -r '.tool_input.skill // ""' <<<"$input" | sed 's/.*://')" = sup ] || exit 0 ;;
  *) exit 0 ;;
esac
cwd=$(jq -r '.cwd // ""' <<<"$input")
root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
out=$(cd "${cwd:-.}" 2>/dev/null && timeout 100 bash "$root/skills/productivity/sup/scripts/find-handoff.sh" 2>&1)
[ -n "$out" ] || out="find-handoff.sh printed nothing: run it by hand."
jq -nc --arg e "$event" --arg h "sup started, so find-handoff.sh ran (sup step 1). Its output:
$out" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$h}}'
