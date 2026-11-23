#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit and Bash; guard_approved_test_lock,
# on by default): an approved test changes only with its change record. A test
# is approved when approved-spec.sh says so, and both the default branch and
# the branch's fork point hold it. An Edit or Write that keeps every Given,
# When and Then comment line of the fork point's copy goes through, as examples' CHANGING.md says. A shell
# command whose words name an approved test as a write target is refused
# before it runs, and on PostToolUse each approved test a command left without
# one of its step lines is put back from the fork point. A change record
# is a file on the branch, not on the default branch, holding the line
# "<test path>:<line or new>" with "- [x] approve" under it: red-pen's
# section for the changed example. Hooks fire for each call inside a REPL
# script too, so a script's Write meets the same check.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_APPROVED_TEST_LOCK:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq the reads below are empty and no path matches
# shellcheck source=approved-spec.sh
. "$(dirname "$0")/approved-spec.sh"
payload=$(cat)
get() { jq -r "$1 // \"\"" <<<"$payload" 2>/dev/null; }
tool=$(get .tool_name); cwd=$(get .cwd)
cd "${cwd:-.}" 2>/dev/null || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
base=origin/main; git rev-parse -q --verify "$base" >/dev/null || base=main
# A test main gained after the branch forked is not the branch's to guard.
fork=$(git merge-base "$base" HEAD 2>/dev/null) || fork=$base
steps() { grep -E '^[[:space:]]*#[[:space:]]*(Given|When|Then|And)[[:space:]]' ; }
record() { # record <repo path>: a ticked change record on the branch
  local f # mutant-ok delete: f only leaks to the caller, which never reads it
  while IFS= read -r f; do
    [ -n "$f" ] || continue # mutant-ok delete: an empty name reads the repo folder, which awk fails on, so it continues anyway
    # Each ticked record line in the branch's copy that the default branch's copy lacks.
    while IFS= read -r r; do
      git show "$base:$f" 2>/dev/null | grep -qxF -- "$r" || return 0
    done < <(awk -v p="$1:" 'index($0, p) == 1 { hit = NR; line = $0 } hit && NR == hit + 1 && /^- \[x\] approve/ { print line }' "$root/$f")
  done < <(git -C "$root" grep -lF -- "$1:" 2>/dev/null)
  return 1
}
refuse() {
  echo "approved-test-lock: $1 holds approved examples, and this changes their Given, When or Then lines." >&2
  echo "A change to an approved example goes through examples' CHANGING.md: open its red-pen section with the new wording, and once it comes back ticked the record lets this edit through." >&2
  echo "Nothing in this command ran." >&2
  exit 2
}
locked() { # locked <absolute path>: prints its repo path when it is locked
  local rel=${1#"$root"/}
  approved "$1" || return 1
  git cat-file -e "$base:$rel" 2>/dev/null || return 1
  git cat-file -e "$fork:$rel" 2>/dev/null || return 1
  record "$rel" && return 1
  echo "$rel"
}
event=$(get .hook_event_name)
if [ "$tool" = Bash ] && [ "$event" = PostToolUse ]; then
  # After the command: each locked test that lost a step line is put back from the
  # fork point. This holds for any write a command can make, read or not.
  hit=""
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue # mutant-ok delete: an empty name is the repo folder, which is never approved
    p="$root/$rel"
    if [ ! -f "$p" ]; then # a deleted test: judge the fork point's copy under its own name
      git cat-file -e "$base:$rel" 2>/dev/null || continue
      tmp=$(mktemp -d); git show "$fork:$rel" >"$tmp/${rel##*/}" 2>/dev/null
      approved "$tmp/${rel##*/}" || { rm -rf "$tmp"; continue; }
      rm -rf "$tmp" # mutant-ok delete: the scratch copy only leaves a file in the temp folder
      record "$rel" && continue
    else
      locked "$p" >/dev/null || continue
    fi
    lost=0
    while IFS= read -r l; do
      [ -n "$l" ] || continue # mutant-ok delete: steps prints no empty line
      [ -f "$p" ] && grep -qxF -- "$l" "$p" || lost=1
    done < <(git show "$fork:$rel" | steps)
    [ "$lost" = 1 ] || continue
    mkdir -p "$(dirname "$p")"; git show "$fork:$rel" >"$p"
    hit="$hit $rel"
  done < <(git diff --name-only "$fork" 2>/dev/null)
  [ -n "$hit" ] || exit 0
  echo "approved-test-lock: the command changed the Given, When or Then lines of$hit, so the copy the branch forked with is back." >&2
  echo "A change to an approved example goes through examples' CHANGING.md: open its red-pen section with the new wording, and once it comes back ticked the record lets this edit through." >&2
  exit 2
fi
case "$tool" in
  Edit | Write | MultiEdit)
    path=$(get .tool_input.file_path)
    case "$path" in /*) ;; *) path="$PWD/$path" ;; esac
    path=$(realpath -m -- "$path") # a .., a double slash or a symlinked folder names the same file
    rel=$(locked "$path") || exit 0
    old=$(git show "$fork:$rel" | steps)
    swap() { if [ "$3" = true ]; then new=${new//"$1"/"$2"}; else new=${new/"$1"/"$2"}; fi; }
    if [ "$tool" = Write ]; then
      new=$(get .tool_input.content)
    else
      new=$(cat "$path")
      while IFS= read -r e; do
        swap "$(jq -r .old_string <<<"$e")" "$(jq -r .new_string <<<"$e")" "$(jq -r '.replace_all // false' <<<"$e")"
      done < <(jq -c 'if .tool_input.edits then .tool_input.edits[] else .tool_input end' <<<"$payload")
    fi
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      grep -qxF -- "$l" <<<"$new" || refuse "$rel"
    done <<<"$old"
    exit 0 ;; # mutant-ok delete: the case ends here and the script exits 0 after it
  Bash)
    cmd=$(get .tool_input.command)
    # Before the command: refuse a write its words name plainly, a redirect target or
    # an operand of rm, mv, tee, truncate, cp, git rm or sed -i. Every other write
    # meets the PostToolUse check above, which puts the test back.
    targets() {
      grep -oE '>>?[[:space:]]*[^[:space:]&;|<>]+' <<<"$cmd" | sed -E 's/^>>?[[:space:]]*//'
      while IFS= read -r seg; do
        read -ra ws <<<"$seg"
        [ "${ws[0]:-}" = git ] && [ "${ws[1]:-}" = rm ] && ws=("${ws[@]:1}")
        case "${ws[0]:-}" in
          rm | mv | tee | truncate | cp) printf '%s\n' "${ws[@]:1}" ;;
          sed) case " ${ws[*]} " in *" -i"* | *" --in-place"*) printf '%s\n' "${ws[@]:1}" ;; esac ;;
        esac
      done < <(tr ';&|' '\n' <<<"$cmd")
    }
    while IFS= read -r w; do
      w=${w//[\"\']/}
      [ -n "$w" ] || continue # mutant-ok delete: an empty word names the folder, which is never an approved test
      while IFS= read -r p; do
        [ -f "$p" ] || continue # mutant-ok delete: a folder or a missing name fails approved too
        case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
        rel=$(locked "$(realpath -m -- "$p")") && refuse "$rel"
      done < <(compgen -G "$w")
    done < <(targets)
    exit 0 ;; # mutant-ok delete: the case ends here and the script exits 0 after it
esac
exit 0 # mutant-ok delete: the last command before it, the case, exits 0
