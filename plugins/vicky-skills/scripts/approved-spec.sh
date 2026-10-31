# shellcheck shell=bash
# Sourced by approved-spec-guard.sh and interactive-page's open-draft.sh: whether a file holds approved examples.
# A file named for approved examples, or one holding a marked test, is the
# contract. A file that does not exist yet holds no approved text.
# The mark is a test framework's tag, never a mention in prose: a comment
# "# approved-spec:", a quoted "approved-spec", or @approved-spec.
approved() {
  [ -f "$1" ] || return 1
  # A file outside every git checkout, such as a session log quoting a test,
  # is no contract: approved tests are in a repo.
  git -C "$(dirname -- "$1")" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  basename -- "$1" | grep -qiE 'approved_?examples' ||
    { grep -qE '(#|//|--|;)[[:space:]]*approved-spec:|["'"'"']approved-spec["'"'"']|@approved-spec([^a-z-]|$)' "$1"; }
}
