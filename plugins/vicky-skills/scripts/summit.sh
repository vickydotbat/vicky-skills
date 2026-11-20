#!/usr/bin/env bash
# The summit: tickets opened versus closed in a repo's tracker, counted with no
# agent. The repo's docs/agents/issue-tracker.md holds a line
#   Summit count: `<command>`
# whose command prints "<opened> <closed>" for the items since $SUMMIT_SINCE.
# The doc is the repo's own and trusted like its scripts, as read-item.sh
# trusts its "Read, whole" row. A repo without the line has no summit.
#   summit.sh auto   SessionStart hook: counts since the last session and over
#                    30 days, keeps both, and prints nothing the agent reads
#   summit.sh show   prints the kept line as "summit: <text>", which the
#                    viewscreen band shows; fails when nothing is kept
# One file per repo in the plugin's data folder keeps the line.
set -u
top=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --show-toplevel 2>/dev/null) || { echo "summit: not in a repository" >&2; exit 2; }
# shellcheck source=plugin-data.sh
. "$(dirname "$0")/plugin-data.sh"
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || { echo "summit: no plugin data folder" >&2; exit 2; }
file="$CLAUDE_PLUGIN_DATA/summit/$(tr '/' '_' <<<"$top")"
stamp="$(git -C "$top" rev-parse --absolute-git-dir)/summit-last-session"

# B when closed is within 10% of opened, either way.
verdict() {
  if [ $((10 * $2)) -gt $((11 * $1)) ]; then echo A
  elif [ $((10 * $2)) -lt $((9 * $1)) ]; then echo C
  else echo B; fi
}

# A start under a week old shows its weekday, an older one its day and month.
label() {
  local age=$(( $(date +%s) - $(date -d "$1" +%s) ))
  if [ "$age" -lt $((7 * 86400)) ]; then date -d "$1" +%a; else date -d "$1" '+%-d %b'; fi
}

# count <since>: the doc's command, cut off after 6 seconds, as "<opened> <closed>".
count() {
  local out # mutant-ok delete: a local declaration: no caller reads this name
  out=$(SUMMIT_SINCE="$1" timeout -k 1 6 bash -c "$cmd" </dev/null 2>/dev/null) &&
    [[ "$out" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([0-9]+)[[:space:]]*$ ]] &&
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
}

case "${1:-}" in
  auto)
    last=$(cat "$stamp" 2>/dev/null)
    date -Iseconds > "$stamp"
    rm -f "$file"
    row=$(grep -m1 -E '^Summit count:[[:space:]]*`[^`]+`' "$top/docs/agents/issue-tracker.md" 2>/dev/null) || exit 0
    cmd=$(sed -E 's/^Summit count:[[:space:]]*`([^`]+)`.*/\1/' <<<"$row")
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    count "$(date -d '30 days ago' +%F)" > "$tmp/thirty" &
    [ -n "$last" ] && count "$last" > "$tmp/since" &
    wait
    read -r o c 2>/dev/null < "$tmp/thirty"
    [ -n "${c:-}" ] || exit 0
    line="30 days: +$o / −$c, $(verdict "$o" "$c")"
    read -r so sc 2>/dev/null < "$tmp/since"
    if [ -n "${sc:-}" ]; then
      line="Since $(label "$last"): $so opened, $sc closed · $line"
    fi
    mkdir -p "${file%/*}" && echo "$line" > "$file" ;;
  show)
    [ -s "$file" ] || { echo "summit: nothing counted yet" >&2; exit 1; }
    echo "summit: $(cat "$file")" ;;
  *) echo "usage: summit.sh auto|show" >&2; exit 2 ;;
esac
