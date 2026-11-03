#!/usr/bin/env bash
# PreToolUse, PostToolUse (Bash), UserPromptSubmit and SessionEnd hook:
# keeps two sessions from sharing one checkout. Each session's last git
# command in a checkout is kept in the plugin's data folder as
# "<checkout>\t<branch>\t<epoch>", one file per session, deleted when the
# session ends. Beside it, "<session>.pid" holds the session's process id and
# start time, so the record of a session that closed without SessionEnd (its
# terminal closed) is dropped once that process is gone. A prompt that starts
# the conn skill writes "<session>.handoff": that session handed the work on,
# so its record stops counting until the user's next prompt to it.
# "<session>.first" keeps when the session first ran git in each checkout: the
# session that came first keeps committing there, and a newcomer is sent to a
# worktree of its own. A branch switch is refused while another session used
# the checkout in the last 12 hours, and a session whose checkout moved to
# another branch since its last git command is told once. A git command that
# writes history there (commit, rebase, reset, merge, cherry-pick, stash,
# pull) is refused like a switch, so the session works in its own worktree. On
# unless the plugin option guard_checkout is false.
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
if [ "$event" = SessionEnd ]; then rm -f "$mine" "$mine".*; exit 0; fi
if [ "$event" = UserPromptSubmit ]; then
  if jq -r '.prompt // empty' <<<"$payload" | head -1 | grep -Eq '^[[:space:]]*/([A-Za-z0-9_-]+:)?conn([[:space:]]|$)'; then
    mkdir -p "$records" && : > "$mine.handoff"
  else
    rm -f "$mine.handoff"
  fi
  exit 0 # mutant-ok delete: a prompt carries no command, so the checks below pass it the same way
fi
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh" <<<"$payload"

# The library exited outside a repository, so this always finds one.
top=$(git rev-parse --show-toplevel)
# A rebase in progress detaches HEAD but stays on the branch it rebases.
gitdir=$(git rev-parse --absolute-git-dir)
rebasing=$(cat "$gitdir/rebase-merge/head-name" "$gitdir/rebase-apply/head-name" 2>/dev/null | head -1)
branch=${rebasing#refs/heads/}
[ -n "$branch" ] || branch=$(git symbolic-ref --short -q HEAD || git rev-parse --short HEAD)
now=$(date +%s)
procstat() { # pid field -> that field of /proc/<pid>/stat, counted after the name
  sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | awk -v n="$2" '{print $n}'
}
started() { procstat "$1" 20; }
# The session's process: the nearest ancestor named claude. Without /proc
# there is none, and the record stands for its 12 hours as before.
owner() {
  local p=${CHECKOUT_GUARD_OWNER_PID:-} _ start
  if [ -z "$p" ]; then
    p=$PPID
    for _ in 1 2 3 4 5 6; do
      case "$(cat "/proc/$p/comm" 2>/dev/null)" in *claude*) break ;; esac
      p=$(procstat "$p" 2)
    done
    case "$(cat "/proc/$p/comm" 2>/dev/null)" in *claude*) ;; *) return 1 ;; esac
  fi
  start=$(started "$p"); [ -n "$start" ] || return 1
  printf '%s %s\n' "$p" "$start"
}
gone() { # record -> 0 when its session's process has ended
  local pid start # mutant-ok delete: the names only stay local, and no caller reads them
  read -r pid start 2>/dev/null < "$1.pid" || return 1 # mutant-ok delete: with no process record both start times read empty, so the record stands either way
  [ "$(started "$pid")" != "$start" ]
}
remember() {
  mkdir -p "$records" || return
  { grep -v "^$top	" "$mine" 2>/dev/null; printf '%s\t%s\t%s\n' "$top" "$branch" "$now"; } > "$mine.new" && mv "$mine.new" "$mine"
  [ -e "$mine.pid" ] || { owner > "$mine.pid" || rm -f "$mine.pid"; }
  [ -n "$(first "$mine")" ] || printf '%s\t%s\n' "$top" "$now" >> "$mine.first"
}
first() { # record -> when its session first ran git in this checkout
  awk -F '\t' -v t="$top" '$1 == t {print $2; exit}' "$1.first" 2>/dev/null
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
    case "${other##*/}" in *.*) continue ;; esac # a session id holds no dot, so this is a side file
    if gone "$other"; then rm -f "$other" "$other".*; continue; fi
    [ -e "$other.handoff" ] && continue
    line=$(awk -F '\t' -v t="$top" '$1 == t' "$other")
    when=${line##*	}; theirs=$(cut -f2 <<<"$line")
    case "$when" in ''|*[!0-9]*) continue ;; esac
    [ $((now - when)) -lt 43200 ] || continue
    if [ -z "$switch" ]; then
      ours=$(first "$mine"); came=$(first "$other")
      [ -n "$ours" ] && [ -n "$came" ] && [ "$ours" -lt "$came" ] && continue # mutant-ok: with no first time of our own the comparison fails the same way, only louder
    fi
    refuse "$GUARD: another session works this checkout on branch $theirs (its last git command was $(( (now - when) / 60 )) minutes ago). ${switch:+Switching would move its files.}${writes:+Writing history here would land on its branch.}" \
      "Work on a branch of your own in its own worktree: git worktree add -b <branch> .claude/worktrees/<branch> origin/main. When your work belongs on $theirs, ask the user to hand that session off with /conn first."
  done
fi
