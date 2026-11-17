#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git-spice command that rebases onto trunk
# (branch create, onto or restack; upstack onto or restack; downstack, stack
# or repo restack) while the local trunk differs from origin's. git-spice
# rebases onto the local branch, so a stale one replays commits a squash merge
# already holds, and the conflicts hide the cause. Trunk is origin's default
# branch; origin is fetched first (10 seconds at most), and a failed fetch lets
# the command through with a note on stderr. A trunk sync earlier in the same command (gs repo sync,
# a fetch into trunk, or trunk reset to origin's) passes.
# On unless the plugin option guard_restack_origin is false or 0.
case "${CLAUDE_PLUGIN_OPTION_GUARD_RESTACK_ORIGIN:-true}" in true|1) ;; *) exit 0 ;; esac
set -u
for tool in jq git; do
  command -v "$tool" >/dev/null || { echo "restack-origin-guard: $tool is missing, so this guard is off." >&2; exit 0; }
done
payload=$(cat)
command=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null) || exit 0
cwd=$(jq -r '.cwd // ""' <<<"$payload")
grep -Eq '(^|[[:space:];&|(])gs[[:space:]]' <<<"$command" || exit 0 # mutant-ok delete: a fast path: the loop below refuses nothing in a command with no gs
[ -n "$cwd" ] && { cd "$cwd" 2>/dev/null || exit 0; }
# Quoted strings and heredoc bodies are text, not commands. git-hook-lib.sh
# holds the same strip, and its trunk lookup below, but exits for any command
# without git in it, so a bare gs never reaches them there.
code=$(awk -f "$(dirname "$0")/heredoc-strip.awk" <<<"$command" | sed -zE "s/'[^']*'//g; s/\"([^\"\\\\]|\\\\.)*\"//g")

# restack_key <words after gs>: prints the command as group:verb, such as
# b:o for branch onto, from the long names, their aliases or a shorthand.
restack_key() {
  local g v # mutant-ok delete: the names only stay local, and no caller reads them
  case "$1" in
    branch|b) g=b ;; upstack|us) g=us ;; downstack|ds) g=ds ;; stack|s) g=s ;; repo|r) g=r ;;
    bc) echo b:c; return ;; bon) echo b:o; return ;; br) echo b:r; return ;;
    uso) echo us:o; return ;; usr) echo us:r; return ;; dsr) echo ds:r; return ;;
    sr) echo s:r; return ;; rr) echo r:r; return ;; rs) echo r:s; return ;;
    *) return ;;
  esac
  case "${2:-}" in
    create|c) v=c ;; onto|on|o) v=o ;; restack|r) v=r ;; sync|s) v=s ;; *) return ;;
  esac
  echo "$g:$v"
}

synced="" dir="" fetched=""
while IFS= read -r segment; do
  read -ra words <<<"$segment"
  [ ${#words[@]} -gt 0 ] || continue
  # A leading cd moves every later segment, as the shell would.
  if [ "${words[0]}" = cd ] && [ ${#words[@]} -gt 1 ]; then
    t=${words[1]/#\~\//$HOME/}; cd "$t" 2>/dev/null || exit 0; continue
  fi
  if [ "${words[0]}" = git ]; then
    # A fetch into trunk, or trunk reset to origin's, syncs it before a later gs.
    [[ "$segment" =~ git[[:space:]]+fetch[[:space:]]+origin[[:space:]]+([^[:space:]:]+):([^[:space:]]+) ]] && [ "${BASH_REMATCH[1]}" = "${BASH_REMATCH[2]}" ] && synced=yes
    [[ "$segment" =~ git[[:space:]]+branch[[:space:]]+(-f|--force)[[:space:]]+([^[:space:]]+)[[:space:]]+origin/([^[:space:]]+) ]] && [ "${BASH_REMATCH[2]}" = "${BASH_REMATCH[3]}" ] && synced=yes
  fi
  [ "${words[0]}" = gs ] || continue
  rest=("${words[@]:1}") dir=.
  # gs takes global flags before its command; -C names the repository.
  while [ ${#rest[@]} -gt 0 ] && [[ ${rest[0]} == -* ]]; do
    case "${rest[0]}" in -C|--dir) dir=${rest[1]:-.}; rest=("${rest[@]:2}") ;; --dir=*) dir=${rest[0]#--dir=}; rest=("${rest[@]:1}") ;; *) rest=("${rest[@]:1}") ;; esac
  done
  key=$(restack_key "${rest[@]}")
  [ "$key" = r:s ] && { synced=yes; continue; }
  case "$key" in b:c|b:o|b:r|us:o|us:r|ds:r|s:r|r:r) ;; *) continue ;; esac
  [ -n "$synced" ] && continue
  trunk=$(git -C "$dir" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
  trunk=${trunk#origin/}
  for name in main master; do
    [ -z "$trunk" ] && git -C "$dir" rev-parse -q --verify "refs/remotes/origin/$name" >/dev/null && trunk=$name
  done
  git -C "$dir" rev-parse -q --verify "refs/heads/$trunk" >/dev/null || continue
  if [ -z "$fetched" ]; then
    GIT_TERMINAL_PROMPT=0 timeout 10 git -C "$dir" fetch -q origin "$trunk" >/dev/null 2>&1 && fetched=yes || fetched=no
  fi
  if [ "$fetched" = no ]; then
    echo "restack-origin-guard: could not fetch origin/$trunk, so the restack is not checked against it." >&2
    continue
  fi
  [ "$(git -C "$dir" rev-parse "refs/heads/$trunk")" = "$(git -C "$dir" rev-parse "refs/remotes/origin/$trunk")" ] && continue
  printf '%s\n' "restack-origin-guard: local $trunk is not origin/$trunk, and git-spice rebases onto the local one." \
    "Bring $trunk to origin's first, then rerun the restack:" \
    "  gs repo sync" \
    "or, when $trunk is not checked out anywhere:" \
    "  git fetch origin $trunk:$trunk" \
    "A local $trunk ahead of origin holds commits of its own: move them to a branch first." \
    "Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2
  exit 2
done < <(sed -E 's/&&|\|\||[;&|]/\n/g' <<<"$code")
exit 0 # mutant-ok delete: the loop above ends with status 0 on every path
