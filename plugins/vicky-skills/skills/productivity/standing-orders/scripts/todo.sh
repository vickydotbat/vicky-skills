#!/usr/bin/env bash
# The one writer of a repo's .todo: `todo.sh add <line>` appends a standing
# order as "- <line>", and `todo.sh done <text>` removes every line holding
# <text>. Run it from the repo; the file sits at the repo's top.
set -u
limit=80 # a standing order is one sentence of at most this many characters
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "todo.sh: not in a git repo" >&2; exit 2; }
file="$top/.todo"
case "${1:-}" in
  add)
    [ -n "${2:-}" ] || { echo "usage: todo.sh add <line>" >&2; exit 2; }
    line=${2#- }
    [ ${#line} -le $limit ] || echo "todo.sh: the line is ${#line} characters; a standing order is at most $limit, so shorten it." >&2
    [ -s "$file" ] && [ -n "$(tail -c1 "$file")" ] && echo >> "$file"
    printf -- '- %s\n' "$line" >> "$file" ;;
  done)
    [ -n "${2:-}" ] && [ -f "$file" ] || { echo "usage: todo.sh done <text>, with a .todo present" >&2; exit 2; }
    grep -qF -- "$2" "$file" || { echo "todo.sh: no line holds '$2'" >&2; exit 1; }
    grep -vF -- "$2" "$file" > "$file.new"; mv "$file.new" "$file" ;;
  *) echo "usage: todo.sh add <line> | todo.sh done <text> (removes every line holding it)" >&2; exit 2 ;;
esac
