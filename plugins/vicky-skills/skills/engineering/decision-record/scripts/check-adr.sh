#!/usr/bin/env bash
# Checks decision records against FORMAT.md beside this folder: the current
# shape and the two older ones. Prints one line per problem, exits 1 on any.
set -u
# --template: the record follows a repo's own template, so check only the
# rules that hold in any shape.
tpl=0; [ "${1:-}" = "--template" ] && { tpl=1; shift; }
[ $# -gt 0 ] || { echo "usage: check-adr.sh [--template] <record>..." >&2; exit 2; }
categories='Architecture|Data|Interface|Infrastructure|Security|Dependencies|Tooling|Process|Other'
ref='([a-z0-9][a-z0-9-]* )?ADR-[0-9]{4}'
date='[0-9]{4}-[0-9]{2}-[0-9]{2}'
fail=0
for f in "$@"; do
  [ -r "$f" ] || { echo "$f: cannot read"; fail=1; continue; }
  limit=180
  if [ $tpl -eq 1 ]; then
    grep -qE '^While .' "$f" || { echo "$f: no Decision line opens with While and its forces"; fail=1; }
    grep -qE '^#+ .*Consequences' "$f" || { echo "$f: no Consequences heading"; fail=1; }
    grep -qE '^#+ .*Guard' "$f" || { echo "$f: no Guard heading"; fail=1; }
  else
    # One token per line or paragraph. Text inside a section is a paragraph,
    # however many lines it wraps over; text outside one is "other".
    tokens=$(awk -v cats="$categories" -v ref="$ref" -v date="$date" '
      /^[[:space:]]*$/ { inpara = 0; next }
      /^# ADR-[0-9][0-9][0-9][0-9]: ./ { print "what"; sec = ""; next } # mutant-ok: the sec reset only changes tokens after a line the shape already refuses or that opens the file
      $0 ~ "^Category: (" cats ")\\.$" { print "category"; next }
      /^Decided [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\.$/ { print "when"; next }
      $0 ~ "^Superseded by " ref "\\.$" && sec != "status" { print "superseded"; sec = ""; next } # mutant-ok: the sec reset only changes tokens after a line the shape already refuses or that opens the file
      /^## (Brief|Rationale|Status|Context|Decision|Consequences|Guard)$/ {
        sec = tolower($2); print sec; inpara = 0; next }
      /^#/ { print "other"; sec = ""; next } # mutant-ok: the sec reset only changes tokens after a line the shape already refuses or that opens the file
      sec == "status" {
        if ($0 ~ "^Accepted " date "\\.$") print "accepted"
        else if ($0 ~ "^Superseded by " ref " on " date ": F[0-9]+ no longer holds\\.$") print "later"
        else if ($0 ~ "^Amended by " ref " on " date "\\.$") print "later"
        else print "other"
        next }
      sec == "context" { print ($0 ~ /^- F[0-9]+: ./ ? "force" : "other"); next }
      sec == "decision" && !inpara { print ($0 ~ /^While ./ ? "while" : "para"); inpara = 1; next }
      sec != "" { if (!inpara) print "para"; inpara = 1; next }
      /^Because ./ { print "why"; next }
      { print "other" }
    ' "$f")
    # The shape folds repeated force and later lines; the report counts every run.
    report=$(printf '%s\n' "$tokens" | uniq -c | awk '{ printf "%s%s ", $2, ($1 > 1 ? "(x" $1 ")" : "") }')
    shape=$(printf '%s\n' "$tokens" | awk '$0 == "later" || $0 == "force" { if (prev == $0) next } { print; prev = $0 }' | tr '\n' ' ')
    limit=100
    case "$shape" in
      "what category when brief para rationale para "|"what category when brief para rationale para superseded ") ;;
      "what category when why "|"what category when why superseded ") limit=55 ;;
      "what category status accepted context force decision while consequences para guard para "|\
      "what category status accepted later context force decision while consequences para guard para ")
        limit=180
        forces=$(grep -oE '^- F[0-9]+:' "$f" | grep -oE 'F[0-9]+' | sort)
        [ "$(printf '%s\n' "$forces" | uniq -d)" = "" ] || { echo "$f: a force number is used twice in Context"; fail=1; }
        cited=$(awk '/^## Decision$/{d=1;next} /^## /{d=0} d' "$f" | grep -oE '\bF[0-9]+\b' | sort -u)
        [ -n "$cited" ] || { echo "$f: the Decision names no force it rests on"; fail=1; }
        for c in $cited; do printf '%s\n' "$forces" | grep -qx "$c" || { echo "$f: the Decision cites $c, which Context lacks"; fail=1; }; done
        for c in $(grep -oE 'F[0-9]+ no longer holds' "$f" | grep -oE '^F[0-9]+'); do
          printf '%s\n' "$forces" | grep -qx "$c" || { echo "$f: Status cites $c, which Context lacks"; fail=1; }; done ;;
      *) echo "$f: needs what, category, Status, Context, Decision, Consequences and Guard (or an older shape), and nothing else; found: $report"; fail=1 ;;
    esac
  fi
  # A record replaced in full is deleted once a Retires line names it.
  for n in $(grep -oE 'Retires ADR-[0-9]{4}([^0-9]|$)' "$f" | grep -oE '[0-9]{4}'); do
    for old in "$(dirname "$f")/$n"-*.md; do
      [ -e "$old" ] && { echo "$f: ADR-$n is retired but still present: delete it"; fail=1; }
    done
  done
  grep -q '`' "$f" && { echo "$f: names code in backticks: that belongs in the code"; fail=1; }
  words=$(wc -w < "$f")
  [ "$words" -le "$limit" ] || { echo "$f: $words words, the limit is $limit"; fail=1; }
done
exit $fail
