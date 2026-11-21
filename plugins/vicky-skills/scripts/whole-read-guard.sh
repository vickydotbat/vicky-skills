#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a ticket read cut short by head, tail, sed -n,
# grep, cut or awk, piped later in its pipeline or reading it through <( ). A ticket's comments sit below its body, and
# they hold the decisions already made, so a clipped read leads to asking the
# user again. A ticket read is read-item.sh, `plane show`, or the command in
# the repo's "Read, whole" row of docs/agents/issue-tracker.md. On unless the
# plugin option guard_whole_read is false or 0.
# A read saved to a file and then cut in the same command counts as cut. A
# ticket the session already read whole, by an earlier read with no cutter in
# the transcript, may be cut: the decisions were read once. Without a readable
# transcript, every cut read is refused.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_WHOLE_READ:-true}" in true | 1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || { echo "whole-read-guard: jq is missing, guard is off" >&2; exit 0; } # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)
# A redirect such as 2>&1 joins streams and ends no command.
command=$(sed -E 's/[0-9]*>&[0-9-]+//g' <<<"$command")
reads='read-item\.sh|(bin/)?plane[[:space:]]+show'
# The repo's own read command, up to its first placeholder, counts too.
doc="$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null)/docs/agents/issue-tracker.md"
if [ -f "$doc" ]; then
  # shellcheck disable=SC2016 # the single quotes hold a sed program, not shell text
  row=$(grep -m1 -E '^\|[[:space:]]*Read, whole' "$doc" | sed -nE 's/^\|[^|]*\|[[:space:]]*`([^`<]+)[^`]*`.*/\1/p' | sed -E 's/[[:space:]]+$//')
  [ -n "$row" ] && reads="$reads|$(sed -E 's/[][\.*^$+?(){}|/]/\\&/g; s/[[:space:]]+/[[:space:]]+/g' <<<"$row")"
fi
tools='(head|tail|grep|cut|awk|sed[[:space:]]+(-[a-zA-Z]*n|--quiet|--silent))'
# A cutter anywhere later in the read's pipeline, or one reading it through <( ).
saved=$(grep -oE "($reads)[^;&|]*>[[:space:]]*[^[:space:];&|]+" <<<"$command" | sed -E 's/.*>[[:space:]]*//' | head -1)
cut_saved=no
[ -n "$saved" ] && grep -Eq "${tools}[^;&|]*[[:space:]]$(sed -E 's/[][\.*^$+?(){}|/]/\\&/g' <<<"$saved")([[:space:]]|$)" <<<"$command" && cut_saved=yes
[ "$cut_saved" = yes ] || grep -Eq "($reads)[^;&]*\\|[[:space:]]*$tools([[:space:]]|\$)|${tools}[^;&|]*<\\([[:space:]]*($reads)" <<<"$command" || exit 0
id=$(grep -oE "($reads)[[:space:]]+[^[:space:]|;&)>]+" <<<"$command" | head -1 | awk '{print $NF}')
# A whole read of the same ticket earlier this session: a read of this id with no cutter after it.
if [ -n "$id" ] && [ -f "$transcript" ]; then # mutant-ok: with no id the pattern needs a read with no ticket, and with no transcript jq reads nothing, so neither half lets a read through alone
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Bash") | .input.command // empty' "$transcript" 2>/dev/null |
    grep -E "($reads)[[:space:]]+$(sed -E 's/[][\.*^$+?(){}|/]/\\&/g' <<<"$id")([[:space:]]|$)" |
    grep -Evq "\\|[[:space:]]*$tools|>" && exit 0
fi
echo "whole-read-guard: a ticket's comments hold the decisions already made, and this pipe cuts them off. Read the whole thread: read-item.sh ${id:-<id>}" >&2
echo "Search the full output afterwards if it is long. Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2
exit 2
