#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a command that files a ticket (`plane file`,
# `tea issues create`, `gh issue create`) until the session has started a
# filing skill: mission-brief for planned work, groundhog-day for a bug report,
# away-team for a ticket titled "Research: <question>".
# Each searches the tracker and the codebase before it writes anything. On unless the plugin option
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
filing='(^|[;&|(][[:space:]]*|[[:space:]])((\./)?bin/)?plane[[:space:]]+file([[:space:]]|$)|(^|[^[:alnum:]_-])tea[[:space:]]+(issues?|i)[[:space:]]+(create|c)([[:space:]]|$)|(^|[^[:alnum:]_-])gh[[:space:]]+issue[[:space:]]+create([[:space:]]|$)'
grep -Eq "$filing" <<<"$command" || exit 0
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
agent=$(agent_of "$payload")
skill_started "$transcript" mission-brief "$agent" && exit 0
skill_started "$transcript" groundhog-day "$agent" && exit 0
# away-team files one note titled "Research: <question>": one filing command,
# whose title (plane's quoted title, or gh's and tea's --title or -t) opens with
# it. The title sits in quotes, so it is read from the raw command.
# xargs splits the words as the shell quotes them, so a "-t" inside a quoted
# body stays inside its word, and the words stop at a shell comment.
research_title() {
  [ "$(grep -Eo "$filing" <<<"$command" | wc -l)" = 1 ] || return 1
  local words word prev="" plane=0 title=""
  words=$(xargs printf '%s\n' <<<"$raw" 2>/dev/null) || return 1
  while IFS= read -r word; do
    case $word in \#*) break ;; esac
    case $plane:$word in
      0:plane | 0:bin/plane | 0:./bin/plane) plane=1 ;;
      1:file) plane=2 ;;
      2:*) plane=3 ;;
      3:*) title=$word plane=4 ;;
    esac
    case $prev in --title | -t) title=$word ;; esac
    case $word in --title=*) title=${word#--title=} ;; esac
    prev=$word
  done <<<"$words"
  [[ $title == Research:* ]]
}
research_title && skill_started "$transcript" away-team "$agent" && exit 0
echo "ticket-filing-guard: refused. A ticket is filed only through a filing skill, never by hand: groundhog-day for a bug report, away-team for a note titled Research: <question>, mission-brief for anything else. Each checks the source material (away-team when a fact is missing), searches the tracker for the same premise, and searches the codebase for anything that looks like the thing, before it writes a word. Start the one that fits, then file. Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2
exit 2
