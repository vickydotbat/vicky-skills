#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses to open one issue or pull request without its
# comments. A comment often narrows the body, corrects it, or drops the plan,
# so a body-only read acts on a stale plan. Lists, creates, edits, `gh api`,
# --web and a --json view of fields without thread text all pass. Off unless
# the plugin option guard_issue_threads is true. Needs jq; without it, it says
# so and stays off.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_ISSUE_THREADS:-}" in true | 1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || { echo "issue-guard: jq is missing, guard is off" >&2; exit 0; } # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
command="$(jq -r '.tool_input.command // ""' 2>/dev/null)"

# Only the two forge CLIs are in scope.
grep -Eq '(^|[^[:alnum:]_-])(gh|tea)([[:space:]]|$)' <<<"$command" || exit 0 # mutant-ok delete: a fast path: the checks below find nothing to refuse in such a command

refuse() {
  echo "issue-guard: refused, $1 An issue is a thread: the body plus every comment. Re-run with --comments." >&2
  exit 2
}

# One command per segment, so a chain is judged piece by piece.
while IFS= read -r segment; do
  grep -Eq '(^|[[:space:]])(--comments|-c)([[:space:]]|=|$)' <<<"$segment" && continue
  grep -Eq -- '--json[[:space:]=][^[:space:]]*comments' <<<"$segment" && continue
  grep -Eq '(^|[[:space:]])--web([[:space:]]|$)' <<<"$segment" && continue

  # A field list without thread text is not a thread read.
  if [[ $segment =~ --json[[:space:]=]+([^[:space:]]+) ]]; then
    case ",${BASH_REMATCH[1]}," in
      *,body,* | *,reviews,* | *,latestReviews,*) ;;
      *) continue ;;
    esac
  fi

  if grep -Eq '(^|[^[:alnum:]_-])gh[[:space:]]+(issue|pr)[[:space:]]+view([[:space:]]|$)' <<<"$segment"; then
    refuse "reading an issue without its comments."
  fi
  # tea has no view verb: an index alone opens the thread.
  if grep -Eq '(^|[^[:alnum:]_-])tea[[:space:]]+(issues?|i|pulls?|pr)[[:space:]]+[0-9]+([[:space:]]|$)' <<<"$segment"; then
    refuse "reading an issue without its comments."
  fi
done < <(tr ';&|\n' '\n' <<<"$command")
exit 0 # mutant-ok delete: the line above leaves status 0, so the script ends the same way
