#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git commit or push on a branch whose remote
# branch is gone, because its pull request merged and the branch is finished.
# It asks origin whether the branch still exists (5 seconds at most), fetches
# origin's default when it is gone, and falls back to the last fetch's record
# when origin can't answer. The refusal holds the move: a fresh branch from
# origin's default, plus the commits made after the merge, found as those after
# the newest commit whose tree the default branch holds, and the heads of the
# user's open pull requests there.
#
# SessionStart hook, and the first other command in each checkout per session:
# tells the agent the same, without refusing, so a session that only reads and
# edits on a merged branch hears it before its first commit. A branch that was
# never pushed is not checked. On unless the plugin option guard_merged_branch
# is false or 0.
GUARD=merged-branch-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_MERGED_BRANCH:-true}
case "$OPTION" in true|1) ;; *) exit 0 ;; esac
payload=$(cat)
event=$(jq -r '.hook_event_name // ""' <<<"$payload" 2>/dev/null)
commit_re='(^|[^[:alnum:]_-])git[[:space:]]([^;&|]*[[:space:]])?(commit|push)([[:space:]]|$)'

# gone: 0 when the branch $current has an upstream and that remote branch is gone.
# Leaves remote and reach (0 live, 2 gone, else origin could not answer).
gone() {
  local upstream merge_ref # mutant-ok delete: a local declaration: no caller reads these names
  [ -n "$current" ] || return 1 # mutant-ok delete: on a detached HEAD the upstream read below comes back empty and returns 1 the same way
  upstream=$(git for-each-ref --format='%(upstream:short)' "refs/heads/$current")
  [ -n "$upstream" ] || return 1 # mutant-ok delete: the remote and branch read below come back empty, so origin is asked for nothing and the record check returns 1 the same way
  remote=$(git config "branch.$current.remote")
  merge_ref=$(git config "branch.$current.merge")
  GIT_TERMINAL_PROMPT=0 timeout 5 git ls-remote --exit-code "$remote" "$merge_ref" >/dev/null 2>&1
  reach=$?
  case $reach in
    0) return 1 ;;
    2) return 0 ;;
    *) [ "$(git for-each-ref --format='%(upstream:track)' "refs/heads/$current")" = "[gone]" ] ;;
  esac
}

# move: fills default_ref and moving, the commits to carry onto a fresh branch.
move() {
  local point after # mutant-ok delete: a local declaration: no caller reads these names
  default_ref=$(default_ref_of "$remote")
  [ -n "$default_ref" ] || default_ref="$remote/main"
  # Origin answered, so bring its default branch in: the merge is on it.
  [ "$reach" = 2 ] && GIT_TERMINAL_PROMPT=0 timeout 5 git fetch -q "$remote" "${default_ref#"$remote"/}" >/dev/null 2>&1
  # shellcheck source=merge-point.sh
  . "$(dirname "$0")/merge-point.sh"
  point=$(merge_point "$default_ref")
  [ -n "$point" ] && after=$(git log --reverse --format='  %h %s' "$point..HEAD")
  if [ -z "$(git rev-list "$default_ref..HEAD" 2>/dev/null)" ] || { [ -n "$point" ] && [ -z "$after" ]; }; then
    moving="Every commit here is already in $default_ref, so nothing needs moving."
  elif [ -n "$point" ]; then
    moving="Carry the commits made after the merge onto it with 'git cherry-pick ${point:0:12}..$current':
$after"
  else
    moving="The merge point is unknown. Compare 'git log $default_ref..HEAD' with the pull request's merged head ('gh pr view --json headRefOid') before carrying anything over."
  fi
}

# shellcheck source=open-heads.sh
. "$(dirname "$0")/open-heads.sh"

# heads_line: what the user's open pull requests say about where to work.
heads_line() {
  local heads # mutant-ok delete: a local declaration: no caller reads this name
  if ! heads=$(open_heads "$(git config "remote.$remote.url")" 4); then
    echo "Ask the forge which pull request of yours is open here: gh pr list --author @me --state open (tea pulls list --state open on Gitea), and carry on in its branch."
    return
  fi
  heads=$(grep -vxF -- "$current" <<<"$heads" | awk 'NF && !seen[$0]++')
  if [ -z "$heads" ]; then
    echo "No pull request of yours is open here."
  else
    echo "Your open pull requests here have the heads: $(paste -sd, <<<"$heads" | sed 's/,/, /g'). Carry on in the one this work belongs to: git switch $(head -n 1 <<<"$heads"), or its worktree."
  fi
}

# A session start, or a first command that is no commit or push, is told, not
# refused. The lib takes a git command in the session's folder in its place, so
# it stands in that repository and stays quiet outside one.
hint=0
if [ "$event" = SessionStart ] || { [ "$event" = PreToolUse ] && ! grep -Eq "$commit_re" <<<"$(jq -r '.tool_input.command // ""' <<<"$payload")"; }; then
  hint=1
  # tr also turns jq's closing newline into _, so no id can name . or ..
  session=$(jq -r '.session_id // "none"' <<<"$payload" | tr -c '[:alnum:]_.-' _)
  # The command keeps its leading cd or git -C, so the lib finds the checkout it aims at.
  payload=$(jq -c '{cwd, tool_input: {command: ((.tool_input.command // "") + "\ngit rev-parse")}}' <<<"$payload")
fi

# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh" <<<"$payload"

if [ "$hint" = 1 ]; then
  # Told once per checkout per session. Until then, $key's time is the last
  # check, and a later command checks again once 10 minutes have passed, so a
  # branch that merges mid-session is told too.
  told="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}/merged-branch-told/$session"
  key=$(git rev-parse --show-toplevel | cksum | cut -d' ' -f1)
  mkdir -p "$told" 2>/dev/null && [ ! -e "$told/$key.told" ] || exit 0
  [ -n "$(find "$told/$key" -mmin -10 2>/dev/null)" ] && exit 0
  touch "$told/$key" 2>/dev/null || exit 0
  gone || exit 0
  touch "$told/$key.told"
  move
  jq -nc --arg e "$event" --arg h "$GUARD: this checkout stands on '$current', and its remote branch is gone: its pull request merged, or the branch was deleted, so the branch is finished. $(heads_line) Or start fresh: git fetch --prune && git switch -c <new-branch> $default_ref. $moving" \
    '{hookSpecificOutput:{hookEventName:$e,additionalContext:$h}}'
else
  grep -Eq "$commit_re" <<<"$code" || exit 0
  grep -Eq -- 'push[^;&|]*(--delete|[[:space:]]-d([[:space:]]|$))' <<<"$code" && exit 0
  gone || exit 0
  move
  refuse "$GUARD: '$current' is finished: its remote branch is gone, so its pull request merged or the branch was deleted." \
    "$(heads_line)" \
    "Carry on from a fresh branch:" \
    "  git fetch --prune && git switch -c <new-branch> ${default_ref}" \
    "$moving"
fi
