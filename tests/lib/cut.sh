#!/usr/bin/env bash
# cut.sh <SKILL.md> <cut line>: delete one part of a skill copy in place, for
# the cut arm of every_case.sh. Costs nothing, so it sits outside tests/evals, whose runners are paid.
#   A cut line that starts with # is a heading: the section goes, up to the
#   next heading of the same or a higher level.
#   Any other cut line is the start of a line, such as a numbered step's bold
#   title ("**Pick the kind**") or a table row ("| pitch |"): the first line
#   that starts with it, after an optional "1. " list marker, goes, with the
#   blank and indented lines after it, up to the next line at the left margin.
#   Either way, a fenced block inside the cut part goes whole.
# Exits 1, leaving the file untouched, when no line matches.
set -u
file=$1 cut=$2
[ -n "$cut" ] || { echo "cut: empty cut line" >&2; exit 1; }
tmp="$file.cut.$$"
if [ "${cut#\#}" != "$cut" ]; then
  level=${cut%%[^#]*}
  CUT=$cut awk -v lv="${#level}" '
    $0 == ENVIRON["CUT"] && !found {skip=1; found=1; next}
    skip && /^[ \t]*```/ {fence=!fence; next}
    skip && fence {next}
    skip && match($0, /^#+ /) && RLENGTH - 1 <= lv {skip=0}
    !skip
    END {exit !found}' "$file" > "$tmp"
else
  CUT=$cut awk '
    function starts(s,  c) { c = ENVIRON["CUT"]; return substr(s, 1, length(c)) == c }
    !found && (starts($0) || (match($0, /^[0-9]+\. /) && starts(substr($0, RLENGTH + 1)))) {skip=1; found=1; next}
    skip && /^[ \t]*```/ {fence=!fence; next}
    skip && fence {next}
    skip && $0 !~ /^([ \t]|$)/ {skip=0}
    !skip
    END {exit !found}' "$file" > "$tmp"
fi
status=$?
if [ $status = 0 ]; then mv "$tmp" "$file"; else rm -f "$tmp"; echo "cut: no line in $file matches \"$cut\"" >&2; exit 1; fi
