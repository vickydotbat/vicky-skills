#!/usr/bin/env bash
# SubagentStart and PreToolUse (Bash, Write, Edit) hook: gives each subagent
# its own scratch folder, /tmp/<session id>/<agent id>, and refuses a
# subagent's call that names the session folder above it. Every subagent
# inherits the parent's session id, so siblings writing the same obvious
# names there collide in silence. The main thread owns the session folder
# and passes. Off unless the plugin option guard_scratch is true.
case "${CLAUDE_PLUGIN_OPTION_GUARD_SCRATCH:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
event=$(jq -r '.hook_event_name // ""' <<<"$payload" 2>/dev/null)
agent=$(jq -r '.agent_id // ""' <<<"$payload" 2>/dev/null)
sid=$(jq -r '.session_id // ""' <<<"$payload" 2>/dev/null)
# agent_id is set only inside a subagent.
[ -n "$agent" ] && [ -n "$sid" ] || exit 0
dir="/tmp/$sid/$agent"

if [ "$event" = SubagentStart ]; then
  mkdir -p "$dir"
  jq -n --arg dir "$dir" '{hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: (
    "Scratch folder for this subagent: " + $dir + " (already created). Write every scratch file there, with the full path in every command. "
    + "/tmp/$CLAUDE_CODE_SESSION_ID itself is shared with every sibling subagent, and a Bash, Write or Edit call that names it is refused. "
    + "To read a file the parent left there, open it with the Read tool.")}}'
  exit 0 # mutant-ok delete: a SubagentStart payload has no tool input, so the check below finds nothing and exits 0 the same way
fi

# Only the fields that hold a path, so an edit whose text merely quotes the
# shared folder passes. shortcut: a heredoc that writes the path into a
# file's text is still refused; parse the shell if that starts to cost.
text=$(jq -r '[.tool_input.command, .tool_input.file_path] | map(select(. != null)) | join("\n")' <<<"$payload")
# Both spellings of the shared folder: the session id, and the variable. A
# path ends at a quote, a space or shell punctuation, so `D=<own folder>;`
# still reads as the subagent's own folder.
pattern="/tmp/($sid|\\\$\{?CLAUDE_CODE_SESSION_ID\}?)(/[^\"'\`[:space:];&|()<>]*)?"
bad=$(grep -oE "$pattern" <<<"$text" | grep -vE "^/tmp/[^/]+/$agent(/|\$)" | sort -u | head -3)
[ -n "$bad" ] || exit 0
{
  echo "scratch-guard: refused. This is the shared session folder:"
  sed 's/^/  /' <<<"$bad"
  echo "Every sibling subagent writes there under the same obvious names, and a collision is silent." # mutant-ok: the reason, for a person; the refusal works without it
  echo "Use your own folder instead: $dir"
} >&2
exit 2
