#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit and Bash; guard_approved_test_lock,
# on by default): an approved test changes only with its change record. A test
# is approved when approved-spec.sh says so and the default branch holds it.
# An Edit or Write that keeps every Given, When and Then comment line of the
# default branch's copy goes through, as examples' CHANGING.md says. A shell
# command that deletes or writes an approved test is refused. A change record
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
  record "$rel" && return 1
  echo "$rel"
}
case "$tool" in
  Edit | Write | MultiEdit)
    path=$(get .tool_input.file_path)
    case "$path" in /*) ;; *) path="$root/$path" ;; esac
    rel=$(locked "$path") || exit 0
    old=$(git show "$base:$rel" | steps)
    case "$tool" in
      Write) new=$(get .tool_input.content) ;;
      Edit) o=$(get .tool_input.old_string); n=$(get .tool_input.new_string); new=$(cat "$path"); if [ "$(get .tool_input.replace_all)" = true ]; then new=${new//"$o"/"$n"}; else new=${new/"$o"/"$n"}; fi ;;
      MultiEdit) new=$(cat "$path"); while IFS= read -r e; do o=$(jq -r .old_string <<<"$e"); n=$(jq -r .new_string <<<"$e"); new=${new/"$o"/"$n"}; done < <(jq -c '.tool_input.edits[]?' <<<"$payload") ;;
    esac
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      grep -qxF -- "$l" <<<"$new" || refuse "$rel"
    done <<<"$old"
    exit 0 ;; # mutant-ok delete: the case ends here and the script exits 0 after it
  Bash)
    cmd=$(get .tool_input.command)
    # shortcut: a write is read from the command's words (a redirect, rm, mv, sed -i, tee, truncate, cp onto it); a script file that writes is not read.
    grep -Eq '(>|(^|[[:space:];&|])(rm|mv|tee|truncate|cp|git[[:space:]]+rm)[[:space:]]|sed[[:space:]]+(-[a-zA-Z]*i))' <<<"$cmd" || exit 0
    # Each word is read as a glob, so a pattern or a tagged test named otherwise meets the lock too.
    while IFS= read -r w; do
      [ -n "$w" ] || continue # mutant-ok delete: an empty word names the folder, which is never an approved test
      while IFS= read -r p; do
        [ -f "$p" ] || continue
        case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
        rel=$(locked "$p") && refuse "$rel"
      done < <(compgen -G "$w" || printf '%s\n' "$w")
    done < <(grep -oE '[^[:space:]"'"'"'<>|;&]+' <<<"$cmd")
    exit 0 ;; # mutant-ok delete: the case ends here and the script exits 0 after it
esac
exit 0 # mutant-ok delete: the last command before it, the case, exits 0
