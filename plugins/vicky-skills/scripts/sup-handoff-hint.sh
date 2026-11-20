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
  UserPromptSubmit) jq -r '.prompt // ""' <<<"$input" | grep -Eq '^[[:space:]]*(/(vicky-skills:)?sup([[:space:]]|$)|<command-name>/(vicky-skills:)?sup</command-name>)' || exit 0 ;;
  PostToolUse) skill=$(jq -r '.tool_input.skill // ""' <<<"$input"); [ "${skill##*:}" = sup ] || exit 0 ;;
  *) exit 0 ;;
esac
# A typed /sup also calls the skill: the finder runs once per ten minutes a session.
mark="${TMPDIR:-/tmp}/sup-handoff-$(jq -r '.session_id // "none"' <<<"$input")"
[ -n "$(find "$mark" -mmin -10 2>/dev/null)" ] && exit 0
touch "$mark"
cwd=$(jq -r '.cwd // ""' <<<"$input")
root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
out=$(cd "${cwd:-.}" 2>/dev/null && timeout "${SUP_HANDOFF_LIMIT:-50}" bash "$root/skills/housekeeping/sup/scripts/find-handoff.sh" 2>&1)
[ $? = 124 ] && out+=$'\n'"not read: the rest, the finder hit its ${SUP_HANDOFF_LIMIT:-50}-second limit: run it by hand."
[ -n "$out" ] || out="find-handoff.sh printed nothing: run it by hand."
# The state of each .todo line's refs, for step 3's Still want.
parked=$(cd "${cwd:-.}" 2>/dev/null && timeout "${SUP_PARKED_LIMIT:-30}" bash "$root/skills/housekeeping/sup/scripts/parked-state.sh" 2>&1)
[ $? = 124 ] && parked+=$'\n'"parked-state.sh hit its ${SUP_PARKED_LIMIT:-30}-second limit: run it by hand."
[ -n "$parked" ] && out+=$'\n\n'"parked-state.sh (sup step 3) read each .todo line's refs:"$'\n'"$parked"
jq -nc --arg e "$event" --arg h "sup started, so find-handoff.sh ran (sup step 1). Its output:
$out" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$h}}'
