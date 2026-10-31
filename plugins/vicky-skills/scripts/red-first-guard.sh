#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a git commit that adds a new approved-
# examples test together with any other change. The tests land red in a
# commit of their own, so CI's red-first check can prove they failed before
# the code existed. Off unless the plugin option guard_red_first is true.
GUARD=red-first-guard
OPTION=${CLAUDE_PLUGIN_OPTION_GUARD_RED_FIRST:-}
# shellcheck source=git-hook-lib.sh
. "$(dirname "$0")/git-hook-lib.sh"

grep -Eq 'git[[:space:]].*commit([[:space:]]|$)' <<<"$code" || exit 0
# What the commit would hold: staged changes, plus every change when the
# command stages them itself (`git add`, `commit -a`).
changes=$(git diff --cached --name-status --no-renames)
everything() { git status --porcelain --untracked-files=all | awk '{s=substr($0,1,2); sub(/^.. /,""); print (s ~ /\?|A/ ? "A" : "M") "\t" $0}'; }
if grep -Eq 'commit[^;&|]*[[:space:]]-[a-zA-Z]*a' <<<"$code"; then
  changes=$(everything)
elif adds=$(grep -oE 'git[[:space:]]+add[[:space:]][^;&|]*' <<<"$code"); then
  # `git add <files>` stages only the files it names. -A, -u, a folder or a
  # glob stages more, so then every change counts.
  paths=$(sed -E 's/^git[[:space:]]+add[[:space:]]+//' <<<"$adds" | tr ' ' '\n' | grep -v '^$')
  files_only=yes
  while IFS= read -r p; do [ -f "$p" ] || files_only=""; done <<<"$paths"
  if [ -z "$files_only" ] || grep -Eq '^-|[*?]' <<<"$paths"; then
    changes=$(everything)
  else
    changes=$(printf '%s\n%s\n' "$changes" "$(everything | awk -F '\t' 'NR == FNR {want[$0]; next} $2 in want' <(printf '%s\n' "$paths") -)")
  fi
fi
new_tests=$(awk -F '\t' '$1 == "A" && tolower($2) ~ /approved_?examples/ {print $2}' <<<"$changes")
[ -n "$new_tests" ] || exit 0
others=$(awk -F '\t' 'NF && tolower($2) !~ /approved_?examples/ {print $2}' <<<"$changes")
[ -n "$others" ] || exit 0
refuse "$GUARD: this commit adds approved tests together with other changes:" \
  "  $(tr '\n' ' ' <<<"$new_tests")" \
  "Commit the approved tests on their own first, red, then the code: git restore --staged <the other files>."
