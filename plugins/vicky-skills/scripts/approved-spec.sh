# shellcheck shell=bash
# Sourced by approved-spec-guard.sh and interactive-page's open-draft.sh: whether a file holds approved examples.
# A file named for approved examples, or one holding a marked test, is the
# contract. A file that does not exist yet holds no approved text.
# The mark is a test framework's tag, never a mention in prose: a comment
# line that opens with the name and a colon, the name quoted as an argument
# (a Category attribute), or the name after an at sign. A prose file
# (Markdown, reStructuredText, AsciiDoc, plain text) holds no tests, so a doc
# that shows the mark is never locked by it.
approved() {
  [ -f "$1" ] || return 1
  # A file outside every git checkout, such as a session log quoting a test,
  # is no contract: approved tests are in a repo.
  git -C "$(dirname -- "$1")" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  basename -- "$1" | grep -qiE 'approved_?examples' ||
    { case "$1" in *.md | *.markdown | *.rst | *.adoc | *.txt) return 1 ;; esac
      grep -qE '^[[:space:]]*(#|//|--|;)[[:space:]]*approved-spec:|[(,][[:space:]]*["'"'"']approved-spec["'"'"']|@approved-spec([^a-z-]|$)' "$1"; }
}
