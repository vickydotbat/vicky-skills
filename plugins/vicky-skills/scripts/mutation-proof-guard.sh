#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git commit while the repo's mutation proof
# is out of date. The repo opts in with two lines in docs/agents/testing.md:
# "Mutation proof check: <command>", which exits non-zero when the proof is
# stale, and "Mutation proof refresh: <command>", which the refusal names. A
# repo without the check line is never refused. Off unless the plugin option
# guard_mutation_proof is true.
GUARD=mutation-proof-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_MUTATION_PROOF:-}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"

grep -Eq 'git[[:space:]].*commit([[:space:]]|$)' <<<"$code" || exit 0
top=$(git rev-parse --show-toplevel)
doc="$top/docs/agents/testing.md"
check=$(sed -n 's/^Mutation proof check: //p' "$doc" 2>/dev/null | head -1)
[ -n "$check" ] || exit 0 # mutant-ok delete: an empty check runs as bash -c "", which passes, so nothing is refused the same way
refresh=$(sed -n 's/^Mutation proof refresh: //p' "$doc" | head -1)
# The files this commit takes: those staged now, those a `git add` in the same
# command stages, and every change for `commit -a` or `add -A`. A commit of
# approved tests alone is red-first's own step, and the proof can't be
# recorded while they fail, so it comes with the code commit instead.
taken=$(cd "$top" && {
  git diff --cached --name-only
  grep -Eq 'commit[^;&|]*[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)' <<<"$code" && git diff --name-only
  grep -oE 'git[[:space:]]+add([[:space:]]+[^;&|[:space:]]+)+' <<<"$code" | while read -r -a words; do
    for w in "${words[@]:2}"; do
      case "$w" in -A | --all | . | -u | --update) git status --porcelain | cut -c4- ;; -*) ;; *) echo "$w" ;; esac
    done
  done
})
if [ -n "$taken" ] && [ "$(grep -ciE '(^|/)[^/]*approved_?examples[^/]*$' <<<"$taken")" = "$(wc -l <<<"$taken")" ]; then
  exit 0
fi
# The check runs from the repo root, and must answer fast: it compares, never mutates.
if ! out=$(cd "$top" && timeout 60 bash -c "$check" 2>&1); then
  refuse "$GUARD: the mutation proof is out of date:" "$out" \
    "Refresh it with: ${refresh:-the command docs/agents/testing.md names}, then commit the proof with the change." \
    "When the stale change is not part of this commit, copy it to a folder outside the repo, git restore it, commit, then copy it back."
fi
exit 0 # mutant-ok delete: the if above leaves status 0
