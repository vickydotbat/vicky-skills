#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git push when shellcheck finds a problem in
# a shell file the branch adds or changes since it left origin's default
# branch, so CI's shellcheck step never goes red on it. A shell file is one
# named *.sh or *.bash, or one whose first line names sh or bash. shellcheck
# reads the repo's own .shellcheckrc, as CI's run does. A repo opts out with
# "Shellcheck: off" in AGENTS.md or a docs/agents file. Without shellcheck,
# or without origin's default branch, the push runs.
# On unless the plugin option guard_shellcheck is false or 0.
GUARD=shellcheck-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_SHELLCHECK:-true}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"

grep -Eq "git[[:space:]].*push([[:space:]]|\$)" <<<"$code" || exit 0
grep -Eq -- 'push[^;&|]*(--delete|[[:space:]]-d)([[:space:]]|$)' <<<"$code" && exit 0
# git diff names files from the top of the repository, and the opt-out lives there too.
cd "$(git rev-parse --show-toplevel)" || exit 0command -v shellcheck >/dev/null || exit 0 # mutant-ok delete: without shellcheck the run below fails with 127, which refuses nothing
cat AGENTS.md docs/agents/*.md 2>/dev/null | grep -qix 'Shellcheck:[[:space:]]*off' && exit 0
base=$(git merge-base "$(default_ref_of origin)" HEAD 2>/dev/null) || exit 0
# shortcut: this reads the working tree, not the pushed commit; a dirty tree can differ from what goes up.
files=()
while IFS= read -r f; do
  [ -f "$f" ] || continue # mutant-ok delete: shellcheck exits 2 on a missing file, which refuses nothing
  case "$f" in
    *.sh | *.bash) files+=("$f") ;;
    *) head -1 -- "$f" | grep -Eq '^#!.*([/ ]|env )(ba)?sh([[:space:]]|$)' && files+=("$f") ;;
  esac
done < <(git diff --name-only --diff-filter=AMR "$base" HEAD)
[ ${#files[@]} -gt 0 ] || exit 0 # mutant-ok delete: shellcheck with no files exits 3, which refuses nothing
out=$(timeout 15 shellcheck -f gcc -- "${files[@]}" 2>&1)
[ $? = 1 ] || exit 0
refuse "shellcheck-guard: shellcheck finds problems in shell files this branch changes:" \
  "$(head -20 <<<"$out")" \
  "Fix each one, or add a disable comment that names one rule and why, then commit and push again."
