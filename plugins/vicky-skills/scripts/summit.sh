#!/usr/bin/env bash
# The summit record: tickets opened versus closed in a repo's tracker. One file
# per repo in the plugin's data folder holds the day of the last 30-day count,
# then the opened and closed numbers, tab-separated. The agent counts with the
# tracker's "since" operations and hands the numbers here.
#   summit.sh record <opened> <closed> [<since-opened> <since-closed>]
#     keeps today's 30-day count and prints the summit line
#   summit.sh show [<since-opened> <since-closed>]
#     prints the summit line from the kept count
#   summit.sh today
#     prints the 30-day part when it was counted today, and fails otherwise
#   summit.sh since
#     prints when the last session started, as Sat or 23 Oct
# The line goes out as "summit: <text>", which the viewscreen band shows.
set -u
top=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --show-toplevel 2>/dev/null) || { echo "summit: not in a repository" >&2; exit 2; }
file="${CLAUDE_PLUGIN_DATA:-}/summit/$(tr '/' '_' <<<"$top")"
stamp="$(git -C "$top" rev-parse --absolute-git-dir)/springboard-last-session"
num() { [[ "$1" =~ ^[0-9]+$ ]] || { echo "summit: counts are whole numbers, got '$1'" >&2; exit 2; }; }

# B when closed is within 10% of opened, either way.
verdict() {
  if [ $((10 * $2)) -gt $((11 * $1)) ]; then echo A
  elif [ $((10 * $2)) -lt $((9 * $1)) ]; then echo C
  else echo B; fi
}
thirty() { echo "30 days: +$1 / −$2, $(verdict "$1" "$2")"; }

# A start under a week old shows its weekday, an older one its day and month.
since() {
  [ -f "$stamp" ] || return 0
  local t; t=$(cat "$stamp")
  local age=$(( $(date +%s) - $(date -d "$t" +%s) ))
  if [ "$age" -lt $((7 * 86400)) ]; then date -d "$t" +%a; else date -d "$t" '+%-d %b'; fi
}

line() { # opened closed [since-opened since-closed]
  local out; out=$(thirty "$1" "$2")
  if [ $# -ge 4 ] && [ -n "$(since)" ]; then out="Since $(since): $3 opened, $4 closed · $out"; fi
  echo "summit: $out"
}

[ "${1:-}" = since ] && { since; exit 0; }
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || { echo "summit: no plugin data folder" >&2; exit 2; }
case "${1:-}" in
  record)
    [ $# -eq 3 ] || [ $# -eq 5 ] || { echo "usage: summit.sh record <opened> <closed> [<since-opened> <since-closed>]" >&2; exit 2; }
    for n in "${@:2}"; do num "$n"; done
    mkdir -p "${file%/*}"
    printf '%s\t%s\t%s\n' "$(date +%F)" "$2" "$3" > "$file"
    line "${@:2}" ;;
  show)
    [ -f "$file" ] || { echo "summit: nothing counted yet" >&2; exit 1; }
    for n in "${@:2}"; do num "$n"; done
    IFS=$'\t' read -r _ o c < "$file"
    line "$o" "$c" "${@:2}" ;;
  today)
    [ -f "$file" ] || exit 1
    IFS=$'\t' read -r day o c < "$file"
    [ "$day" = "$(date +%F)" ] || exit 1
    thirty "$o" "$c" ;;
  *) echo "usage: summit.sh record|show|today|since" >&2; exit 2 ;;
esac
