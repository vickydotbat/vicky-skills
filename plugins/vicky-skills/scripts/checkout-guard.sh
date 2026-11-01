#!/usr/bin/env bash
# PreToolUse, PostToolUse (Bash) and SessionEnd hook: keeps two sessions from
# sharing one checkout. Each session's last git command in a checkout is kept
# in the plugin's data folder as "<checkout>\t<branch>\t<epoch>", one file per
# session, deleted when the session ends. A branch switch is refused while
# another session used the checkout in the last 12 hours, and a session whose
# checkout moved to another branch since its last git command is told once. A
# git command that writes history there (commit, rebase, reset, merge,
# cherry-pick, stash, pull) is refused like a switch, so the session works in
# its own worktree. On unless the plugin option guard_checkout is false.
GUARD=checkout-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT:-true}
case "$OPTION" in false|0) exit 0 ;; esac
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0 # mutant-ok delete: the records would go to /checkouts, which a hook cannot write
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
session=$(jq -r '.session_id // empty' <<<"$payload" | tr -cd 'A-Za-z0-9_-')
[ -n "$session" ] || exit 0
records="$CLAUDE_PLUGIN_DATA/checkouts"
mine="$records/$session"
event=$(jq -r '.hook_event_name // empty' <<<"$payload")
if [ "$event" = SessionEnd ]; then rm -f "$mine"; exit 0; fi
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh" <<<"$payload"

# The library exited outside a repository, so this always finds one.
top=$(git rev-parse --show-toplevel)
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
    "Leave $branch to that session, and work on yours in its own worktree: git worktree add <dir> $was, with <dir> at .claude/worktrees/$was"
fi

# A switch moves the checkout: git switch, or a checkout of a branch or commit
# with no "--" path list.
switch=""
if grep -Eq 'git[[:space:]]+([^|;&]*[[:space:]])?switch([[:space:]]|$)' <<<"$code"; then
  switch=yes
elif args=$(grep -oE 'git[[:space:]]+([^|;&]*[[:space:]])?checkout([[:space:]][^|;&]*)?' <<<"$code" | head -1); [ -n "$args" ]; then
  args=${args#*checkout}
  if ! grep -Eq '(^|[[:space:]])--([[:space:]]|$)' <<<"$args"; then
    if grep -Eq '(^|[[:space:]])(-b|-B|--orphan|--detach)([[:space:]]|$)' <<<"$args"; then
      switch=yes
    else
      for arg in $args; do
        case "$arg" in -?*) continue ;; esac
        { [ "$arg" = - ] || git rev-parse --verify -q "$arg^{commit}" >/dev/null; } && [ ! -e "$arg" ] && switch=yes
        break
      done
    fi
  fi
fi
# A history write is a git command whose subcommand, the first word after git
# and its global options, writes history. stash list and stash show only read.
writes=$(awk '{
  split($0, seg, /[|;&()]/)
  for (s in seg) {
    m = split(seg[s], w, /[[:space:]]+/)
    for (i = 1; i <= m; i++) {
      if (w[i] != "git" && w[i] !~ /\/git$/) continue
      j = i + 1
      while (j <= m && w[j] ~ /^-/) j += (w[j] ~ /^(-C|-c|--git-dir|--work-tree|--namespace)$/) ? 2 : 1
      if (w[j] ~ /^(commit|rebase|reset|merge|cherry-pick|pull)$/ || (w[j] == "stash" && w[j + 1] !~ /^(list|show)$/)) { print "yes"; exit }
    }
  }
}' <<<"$code")
if [ -n "$switch$writes" ]; then
  for other in "$records"/*; do
    [ -f "$other" ] && [ "$other" != "$mine" ] || continue
    line=$(awk -F '\t' -v t="$top" '$1 == t' "$other")
    when=${line##*	}; theirs=$(cut -f2 <<<"$line")
    case "$when" in ''|*[!0-9]*) continue ;; esac
    [ $((now - when)) -lt 43200 ] || continue
    refuse "$GUARD: another session works this checkout on branch $theirs (its last git command was $(( (now - when) / 60 )) minutes ago). ${switch:+Switching would move its files.}${writes:+Writing history here would land on its branch.}" \
      "Use your own worktree instead: git worktree add .claude/worktrees/<branch> <branch>"
  done
fi
