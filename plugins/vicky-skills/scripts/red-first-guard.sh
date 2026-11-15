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
# What the commit would hold: the index, plus what the call stages itself.
changes=$(git diff --cached --name-status --no-renames)
everything() { git status --porcelain --untracked-files=all | awk '{s=substr($0,1,2); sub(/^.. /,""); print (s ~ /\?|A/ ? "A" : "M") "\t" $0}'; }
# Two commits in one call split the changes in a way no read of the tree can
# tell, so a call that holds a new approved test makes one commit.
if [ "$(grep -oE 'git[[:space:]]+([^;&|]*[[:space:]])?commit([[:space:]]|$)' <<<"$code" | wc -l)" -gt 1 ]; then
  tree=$(everything)
  awk -F '\t' '$1 == "A" && tolower($2) ~ /approved_?examples/' <<<"$tree" | grep -q . || exit 0
  awk -F '\t' 'NF && tolower($2) !~ /approved_?examples/' <<<"$tree" | grep -q . || exit 0
  refuse "$GUARD: this call makes more than one commit while the tree holds a new approved test." \
    "Make one commit per call: commit the approved tests on their own, red, then the code in the next call."
fi
# `commit -a` also takes every tracked change, never an untracked file.
grep -Eq 'commit[^;&|]*[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)' <<<"$code" &&
  changes=$(git diff HEAD --name-status --no-renames)
# Git itself says what each `git add` would stage: --dry-run resolves its
# files, folders, globs and flags the way the real add will. The paths a
# `git commit <paths>` names count the same way. A quoted word with no space
# in it is a path and keeps its letters; any other quoted text, such as a
# commit message, is cut first. `code` can't serve: it cuts every quoted word.
words=$(awk -f "$(dirname "$0")/heredoc-strip.awk" <<<"$command" | sed -E "s/'([^' ]*)'/\1/g; s/\"([^\" ]*)\"/\1/g; s/'[^']*'//g; s/\"([^\"\\\\]|\\\\.)*\"//g")
git_opts='git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+'
adds=$(grep -oE "${git_opts}add[[:space:]][^;&|]*" <<<"$words" | sed -E "s/^${git_opts}add//")
# A commit's own paths: its words after the flags and the value of -m, -F, -C or -c.
paths=$(grep -oE "${git_opts}commit([[:space:]][^;&|]*)?" <<<"$words" | sed -E "s/^${git_opts}commit//" |
  awk '{for (i = 1; i <= NF; i++) if ($i ~ /^-[mFCc]$/) i++; else if ($i !~ /^-/) printf " %s", $i; print ""}' | grep -v '^$')
if grep -Eq "${git_opts}add[[:space:]][^;&|]*([\"'][^\"']* [^\"']*[\"'])" <<<"$command"; then
  # A quoted path with a space in it can't be told from a message: count every change.
  changes=$(everything)
elif [ -n "$adds$paths" ]; then
  staged=$(while IFS= read -r a; do
    # shellcheck disable=SC2086 # the add's own words, split as the shell will
    git add --dry-run --ignore-errors $a 2>/dev/null
  done <<<"$(printf '%s\n%s\n' "$adds" "$paths" | grep -v '^$')" | sed -nE "s/^(add|remove) '(.*)'$/\2/p")
  changes=$(printf '%s\n%s\n' "$changes" "$(everything | awk -F '\t' 'NR == FNR {want[$0]; next} $2 in want' <(printf '%s\n' "$staged") -)")
fi
# A backup copy (.new, .bak, .orig, a trailing ~) is no approved test, the same list approved-spec.sh keeps: change both.
new_tests=$(awk -F '\t' '$1 == "A" && tolower($2) ~ /approved_?examples/ && $2 !~ /\.(new|bak|orig)$|~$/ {print $2}' <<<"$changes")
[ -n "$new_tests" ] || exit 0
others=$(awk -F '\t' 'NF && tolower($2) !~ /approved_?examples/ {print $2}' <<<"$changes")
[ -n "$others" ] || exit 0
refuse "$GUARD: this commit adds approved tests together with other changes:" \
  "  $(tr '\n' ' ' <<<"$new_tests")" \
  "Commit the approved tests on their own first, red, then the code: git restore --staged <the other files>."
