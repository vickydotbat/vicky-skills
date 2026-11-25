#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a command that files a ticket (`plane file`,
# `tea issues create`, `gh issue create`) until the session has started a
# filing skill: groundhog-day for one ticket or issue, mission-brief for a chart,
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
# never a command, so it is dropped first. A quoted lone variable ("$GH") is a
# command name, so it loses its quotes before that.
raw=$command
command=$(awk -f "$(dirname "$0")/heredoc-strip.awk" <<<"$command" | sed -zE 's/"(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)"/\1/g' | sed -zE "s/'[^']*'//g; s/\"([^\"\\\\]|\\\\.)*\"//g")
# A forge CLI can sit behind a variable ($GH, ${GH}) or a full path.
cli='\$\{?[A-Za-z_][A-Za-z0-9_]*\}?'
filing="(^|[;&|(][[:space:]]*|[[:space:]])((\./)?bin/)?plane[[:space:]]+file([[:space:]]|$)|(^|[^[:alnum:]_-])($cli|tea|[^[:space:];&|()]*/tea)[[:space:]]+(issues?|i)[[:space:]]+(create|c)([[:space:]]|$)|(^|[^[:alnum:]_-])($cli|gh|[^[:space:];&|()]*/gh)[[:space:]]+issue[[:space:]]+create([[:space:]]|$)"
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
# away-team files one note titled "Research: <question>", through one plain
# command on one line: the tracker's create command, then its quoted title
# (plane's after the project, gh's and tea's after --title or -t) opening
# with Research: and holding no $, backtick or backslash, then at most a
# --body-file in the repo, /tmp or $TMPDIR, with no folder or file that starts with a
# dot, and a </dev/null. Nothing else fits, so a second title, an
# inline body, a comment or a chained command is refused.
# shellcheck disable=SC2016 # $TMPDIR is matched as text, never expanded
research='^[[:space:]]*(((\./)?bin/)?plane[[:space:]]+file[[:space:]]+[[:alnum:]][[:alnum:]_-]*[[:space:]]+|gh[[:space:]]+issue[[:space:]]+create[[:space:]]+(--title|-t)([[:space:]]+|=)|tea[[:space:]]+(issues?|i)[[:space:]]+(create|c)[[:space:]]+(--title|-t)([[:space:]]+|=))("Research:[^"$`\\]*"|'"'"'Research:[^'"'"']*'"'"')([[:space:]]+(--body-file|-F)[[:space:]]+"?(/tmp/|\$TMPDIR/|\$\{TMPDIR\}/)?[[:alnum:]_][[:alnum:]_.-]*(/[[:alnum:]_][[:alnum:]_.-]*)*"?)?([[:space:]]+<[[:space:]]*/dev/null)?[[:space:]]*$'
research_title() {
  [[ $raw != *$'\n'* ]] && grep -Eq "$research" <<<"$raw"
}
research_title && skill_started "$transcript" away-team "$agent" && exit 0
echo "ticket-filing-guard: refused. A ticket is filed only through a filing skill, never by hand: groundhog-day for one ticket or issue, a bug or not, mission-brief for a star chart and its stars, and away-team for a note titled Research: <question>, filed by one plain command of its own with its body in --body-file. Each checks the source material (away-team when a fact is missing), searches the tracker for the same premise, and searches the codebase for anything that looks like the thing, before it writes a word. Start the one that fits, then file. Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2
exit 2
