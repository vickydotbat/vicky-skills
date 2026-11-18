#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses `git rebase <origin's default branch>` in a
# session where history-monks has not started, and steers to it. A bare
# rebase onto a moved main picks "ours" or "theirs" by conflict, and a clean
# one carries the retired forms main dropped; history-monks follows what
# landed. The target is origin/<default> or <default>, as the upstream
# argument or after --onto. It passes --continue, --abort, --skip, --quit,
# --edit-todo, a rebase onto any other branch (a stack's parent), a branch
# already holding the default's tip, the default branch itself, and
# `git pull --rebase` (a trunk repo's way to stay current).
# shortcut: history-monks counts once per session, so a later rebase after
# main moves again passes; a per-move marker would close that.
# On unless the plugin option guard_rebase is false or 0. A missing
# transcript lets the rebase through.
GUARD=rebase-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_REBASE:-true}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"
# shellcheck source=skill-started.sh
. "$(dirname "$0")/skill-started.sh"

grep -Eq 'git[[:space:]]+([^;&|]*[[:space:]])?rebase([[:space:]]|$)' <<<"$code" || exit 0 # mutant-ok delete: a fast path: the loop below finds no target in such a command
default_ref=$(default_ref_of origin)
[ -n "$default_ref" ] || exit 0 # mutant-ok delete: with no default the target never matches an empty name, and the hook exits 0 the same way
dflt=${default_ref#origin/}
[ "$current" = "$dflt" ] && exit 0

hit=""
# The rebase's target is its --onto value, else its first argument.
while IFS= read -r segment; do
  read -ra words <<<"$segment"
  seen=0
  for word in ${words[@]+"${words[@]}"}; do
    if [ "$seen" = 0 ]; then [ "$word" = rebase ] && seen=1; continue; fi
    case "$word" in
      --continue|--abort|--skip|--quit|--edit-todo) break ;;
      --onto) continue ;;
      --onto=*) word=${word#--onto=} ;;
      -*) continue ;;
    esac
    { [ "$word" = "$default_ref" ] || [ "$word" = "$dflt" ]; } && hit=$word
    break
  done
done < <(sed -E 's/(&&|\|\||;|\|)/\n/g' <<<"$code")
[ -n "$hit" ] || exit 0

transcript=$(jq -r '.transcript_path // ""' <<<"$payload")
[ -f "$transcript" ] || exit 0
skill_started "$transcript" history-monks && exit 0
GIT_TERMINAL_PROMPT=0 timeout 10 git fetch -q origin "$dflt" >/dev/null 2>&1
git merge-base --is-ancestor "$default_ref" HEAD 2>/dev/null && exit 0

refuse "rebase-guard: this rebases onto $hit, which moved past the branch. Start the history-monks skill first: it reads what landed and resolves by its intent." \
  "When no landed file is one the branch changes, its Disjoint line skips the wait for the user."
