#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a command that files a ticket (`plane file`,
# `tea issues create`, `gh issue create`) until the session has started the
# mission-brief skill, which checks the source material, the tracker and the
# codebase before it writes anything. On unless the plugin option
# guard_ticket_filing is false or 0. Reads the session transcript for Skill
# calls; a missing transcript or a missing jq lets the command through.
case "${CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
command=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null)
# Text a heredoc feeds a program, and quoted text such as a grep pattern, is
# never a command, so it is dropped first.
command=$(awk -f "$(dirname "$0")/heredoc-strip.awk" <<<"$command" | sed -zE "s/'[^']*'//g; s/\"([^\"\\\\]|\\\\.)*\"//g")
grep -Eq '(^|[;&|(][[:space:]]*|[[:space:]])((\./)?bin/)?plane[[:space:]]+file([[:space:]]|$)|(^|[^[:alnum:]_-])tea[[:space:]]+(issues?|i)[[:space:]]+(create|c)([[:space:]]|$)|(^|[^[:alnum:]_-])gh[[:space:]]+issue[[:space:]]+create([[:space:]]|$)' <<<"$command" || exit 0
transcript=$(jq -r '.transcript_path // ""' <<<"$payload" 2>/dev/null)
[ -f "$transcript" ] || exit 0 # mutant-ok delete: jq reads no skills from a missing file, and the next test exits 0 the same way
if jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill' "$transcript" 2>/dev/null | sed 's/.*://' | grep -qx mission-brief; then
  exit 0
fi
echo "ticket-filing-guard: refused. A ticket is filed only through the mission-brief skill, never by hand. It checks the source material (away-team when a fact is missing), searches the tracker for the same premise, and searches the codebase for anything that looks like the thing, before it writes a word. Start mission-brief, then file. Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2
exit 2
