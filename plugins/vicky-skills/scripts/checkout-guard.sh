#!/usr/bin/env bash
# PreToolUse, PostToolUse (Bash) and SessionEnd hook: keeps two sessions from
# sharing one checkout. Each session's last git command in a checkout is kept
# in the plugin's data folder as "<checkout>\t<branch>\t<epoch>", one file per
# session, deleted when the session ends. A branch switch is refused while
# another session used the checkout in the last 12 hours, and a session whose
# checkout moved to another branch since its last git command is told once.
# Off unless the plugin option guard_checkout is true.
GUARD=checkout-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT:-}
case "$OPTION" in true|1) ;; *) exit 0 ;; esac
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0
command -v jq >/dev/null || exit 0
payload=$(cat)
session=$(jq -r '.session_id // empty' <<<"$payload" | tr -cd 'A-Za-z0-9_-')
[ -n "$session" ] || exit 0
records="$CLAUDE_PLUGIN_DATA/checkouts"
mine="$records/$session"
event=$(jq -r '.hook_event_name // empty' <<<"$payload")
if [ "$event" = SessionEnd ]; then rm -f "$mine"; exit 0; fi
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh" <<<"$payload"

top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git symbolic-ref --short -q HEAD || git rev-parse --short HEAD)
now=$(date +%s)
remember() {
  mkdir -p "$records" || return
  { grep -v "^$top	" "$mine" 2>/dev/null; printf '%s\t%s\t%s\n' "$top" "$branch" "$now"; } > "$mine.new" && mv "$mine.new" "$mine"
}
if [ "$event" = PostToolUse ]; then remember; exit 0; fi

was=$(awk -F '\t' -v t="$top" '$1 == t {print $2}' "$mine" 2>/dev/null)
if [ -n "$was" ] && [ "$was" != "$branch" ]; then
  remember
  refuse "$GUARD: this checkout moved from $was to $branch since your last git command here. Another session switched it." \
    "Leave $branch to that session, and work on yours in its own worktree: git worktree add <dir> $was"
fi

# A switch moves the checkout: git switch, or a checkout of a branch or commit
# with no "--" path list.
switch=""
if grep -Eq 'git[[:space:]]+([^|;&]*[[:space:]])?switch([[:space:]]|$)' <<<"$code"; then
  switch=yes
elif args=$(grep -oE 'git[[:space:]]+([^|;&]*[[:space:]])?checkout([[:space:]][^|;&]*)?' <<<"$code" | head -1) && [ -n "$args" ]; then
  args=${args#*checkout}
  if ! grep -Eq '(^|[[:space:]])--([[:space:]]|$)' <<<"$args"; then
    if grep -Eq '(^|[[:space:]])(-b|-B|--orphan|--detach)([[:space:]]|$)' <<<"$args"; then
      switch=yes
    else
      for arg in $args; do
        case "$arg" in -*) continue ;; esac
        { [ "$arg" = - ] || git rev-parse --verify -q "$arg^{commit}" >/dev/null; } && [ ! -e "$arg" ] && switch=yes
        break
      done
    fi
  fi
fi
if [ -n "$switch" ]; then
  for other in "$records"/*; do
    [ -f "$other" ] && [ "$other" != "$mine" ] || continue
    line=$(awk -F '\t' -v t="$top" '$1 == t' "$other")
    [ -n "$line" ] || continue
    when=${line##*	}; theirs=$(cut -f2 <<<"$line")
    case "$when" in ''|*[!0-9]*) continue ;; esac
    [ $((now - when)) -lt 43200 ] || continue
    refuse "$GUARD: another session works this checkout on branch $theirs (its last git command was $(( (now - when) / 60 )) minutes ago). Switching would move its files." \
      "Use your own worktree instead: git worktree add <dir> <branch>"
  done
fi
exit 0
