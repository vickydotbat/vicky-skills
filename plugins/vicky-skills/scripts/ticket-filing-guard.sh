#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a command that files a ticket (`plane file`,
# `tea issues create`, `gh issue create`) until the session has started the
# mission-brief skill, which checks the source material, the tracker and the
# codebase before it writes anything. On unless the plugin option
# guard_ticket_filing is false or 0. Reads the session transcript for Skill
# calls; a missing transcript or a missing jq lets the command through.
# A familiar debt note is refused on every tracker, mission-brief or not:
# debt notes are local only.
case "${CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
command=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null)
# Text a heredoc feeds a program, and quoted text such as a grep pattern, is
# never a command, so it is dropped first.
raw=$command
command=$(awk -f "$(dirname "$0")/heredoc-strip.awk" <<<"$command" | sed -zE "s/'[^']*'//g; s/\"([^\"\\\\]|\\\\.)*\"//g")
grep -Eq '(^|[;&|(][[:space:]]*|[[:space:]])((\./)?bin/)?plane[[:space:]]+file([[:space:]]|$)|(^|[^[:alnum:]_-])tea[[:space:]]+(issues?|i)[[:space:]]+(create|c)([[:space:]]|$)|(^|[^[:alnum:]_-])gh[[:space:]]+issue[[:space:]]+create([[:space:]]|$)' <<<"$command" || exit 0
# A call that only asks for the usage text files nothing.
grep -Eq '(file|create)[[:space:]]+--help([[:space:]]|$)' <<<"$command" && exit 0
# The title sits in quotes, which the stripped command no longer holds.
if grep -Eiq 'familiar[[:space:]]+debt' <<<"$raw"; then
  echo "ticket-filing-guard: refused. A familiar debt note never goes on a shared tracker: other people read it. Write it as a local note, where the familiar skill's step 2 says. Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2
  exit 2
fi
transcript=$(jq -r '.transcript_path // ""' <<<"$payload" 2>/dev/null)
[ -f "$transcript" ] || exit 0 # mutant-ok delete: jq reads no skills from a missing file, and the next test exits 0 the same way
# shellcheck source=skill-started.sh
. "$(dirname "$0")/skill-started.sh"
skill_started "$transcript" mission-brief && exit 0
echo "ticket-filing-guard: refused. A ticket is filed only through the mission-brief skill, never by hand. It checks the source material (away-team when a fact is missing), searches the tracker for the same premise, and searches the codebase for anything that looks like the thing, before it writes a word. Start mission-brief, then file. Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2
exit 2
