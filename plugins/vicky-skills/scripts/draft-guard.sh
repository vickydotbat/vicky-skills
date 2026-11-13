#!/usr/bin/env bash
# PreToolUse hook (Bash): a pull request opens as a draft, always, and turns
# ready for review only in a session where make-it-so started, which runs only
# on the user's ask ("make it so", "ship it", "mark it ready", a warp they
# engaged). On unless the plugin option guard_draft is false or 0, or the
# repo's docs/agents/issue-tracker.md says "PR drafts: off". It refuses:
#
#   1. `gh pr create` without --draft (-d), and `tea pr create` without
#      --draft or a title starting `WIP:`, in any session.
#   2. `gh stack submit` without --auto, whose editor opens new pull requests
#      ready; and `gs ... submit` without --draft, unless git config
#      spice.submit.draft is true. After make-it-so starts, both go through.
#   3. Marking one ready before make-it-so starts: `gh pr ready` (not
#      --undo), `tea pr edit --ready`, `tea pr edit -t` with a title that has
#      no `WIP:` and no --draft, `gs ... submit --no-draft`, and
#      `gh stack submit --open`.
#
# make-it-so counts when the session transcript holds a Skill call for it, or
# a user prompt that typed it (`<command-name>/make-it-so`), which arrives as
# a plain string; a tool result never does. A missing transcript lets the
# command through. A --help call goes through.
# shortcut: a raw `gh api` or `tea api` call, a forge MCP tool, and a forge command inside a script file are not read; cover one if an agent ever reaches for it.
set -u

case "${CLAUDE_PLUGIN_OPTION_GUARD_DRAFT:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the read below comes back empty, and the pre-filter exits 0

payload=$(cat)
command=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null)
cwd=$(jq -r '.cwd // ""' <<<"$payload" 2>/dev/null)
transcript=$(jq -r '.transcript_path // ""' <<<"$payload" 2>/dev/null)

code=$(awk -f "$(dirname "$0")/heredoc-strip.awk" <<<"$command")
grep -Eq '(^|[^[:alnum:]_-])(gh|tea|gs)([[:space:]]|$)' <<<"$code" || exit 0 # mutant-ok delete: a fast path: no check below matches a command with no forge CLI
quoted=$(awk -f "$(dirname "$0")/quote-mask.awk" <<<"$code") && [ -n "$quoted" ] || quoted=$code

[ -z "$cwd" ] || cd "$cwd" 2>/dev/null || true
tracker="$(git rev-parse --show-toplevel 2>/dev/null)/docs/agents/issue-tracker.md"
[ -f "$tracker" ] && grep -qix 'PR drafts:[[:space:]]*off' "$tracker" && exit 0

refuse() {
  printf 'draft-guard: refused. %s\n' "$1" >&2
  shift # mutant-ok delete: the first line of a refusal would print twice, and nothing reads the wording
  for line in "$@" "Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own."; do printf '%s\n' "$line" >&2; done
  exit 2
}

ready_steer="Only the user marks a pull request ready, through make-it-so: \"make it so\", \"ship it\", \"mark it ready\", or a warp they engaged. If they asked, start the make-it-so skill and mark it ready from there. If not, leave it a draft and say in your report that it waits on their word."

# shellcheck source=skill-started.sh
. "$(dirname "$0")/skill-started.sh"

# True when make-it-so started in this session, by the agent or typed by the user.
asked() {
  [ -r "$transcript" ] || return 0
  skill_started "$transcript" make-it-so
}

has() { grep -Eq "(^|[[:space:]])($2)([[:space:]=]|\$)" <<<"$1"; }
# A draft flag counts unless it is set false (--draft=false).
drafts() { has "$1" "$2" && ! grep -Eq "(^|[[:space:]])($2)=(false|0)([[:space:]]|\$)" <<<"$1"; }

# The title a segment passes, quotes stripped, or nothing.
title_of() {
  local pattern='(^|[[:space:]])(-t|--title)[[:space:]=]+([^[:space:]]+)' value # mutant-ok delete: a local declaration: no caller reads these names
  [[ $1 =~ $pattern ]] || return 0
  value=${BASH_REMATCH[3]}
  value=${value#\$}
  value=${value#[\"\']}
  printf '%s' "$value"
}

wip() { [[ ${1,,} == wip:* ]]; }

# Flags a forge CLI takes before its subcommand (gh -R <repo> pr create).
pre='([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'

while IFS= read -r masked; do
  # Quoted text handed to a shell, eval, ssh or xargs runs, so it is read whole.
  if grep -Eq '(^|[[:space:]/(])(bash|sh|zsh|dash|eval|ssh|xargs|su|run0)([[:space:]]|$)' <<<"$masked"; then
    masked=$(tr '\001\002\003\004\005' ' ;&|\n' <<<"$masked")
  fi
  has "$masked" '--help|-h' && continue
  if grep -Eq "(^|[^[:alnum:]_-])gh${pre}[[:space:]]+pr[[:space:]]+create([[:space:]]|$)" <<<"$masked"; then
    drafts "$masked" '--draft|-d' || refuse "A pull request opens as a draft, always." \
      "Add --draft to this gh pr create and run it again."
  elif grep -Eq "(^|[^[:alnum:]_-])tea${pre}[[:space:]]+(pulls|pull|pr)[[:space:]]+(create|c)([[:space:]]|$)" <<<"$masked"; then
    drafts "$masked" '--draft' || wip "$(title_of "$masked")" || refuse "A pull request opens as a draft, always: on Gitea its title starts with WIP:." \
      "Add --draft to this tea pr create, or start the title with WIP:, and run it again."
  elif grep -Eq "(^|[^[:alnum:]_-])gh${pre}[[:space:]]+pr[[:space:]]+ready([[:space:]]|$)" <<<"$masked"; then
    drafts "$masked" '--undo' || asked || refuse "gh pr ready marks a pull request ready for review." "$ready_steer"
  elif grep -Eq "(^|[^[:alnum:]_-])tea${pre}[[:space:]]+(pulls|pull|pr)[[:space:]]+edit([[:space:]]|$)" <<<"$masked"; then
    if has "$masked" '--ready'; then
      asked || refuse "tea pr edit --ready marks a pull request ready for review." "$ready_steer"
    elif has "$masked" '-t|--title' && ! drafts "$masked" '--draft' && ! wip "$(title_of "$masked")"; then
      asked || refuse "A title without WIP: marks a Gitea pull request ready for review." \
        "To retitle a draft, start the new title with WIP:, or add --draft." "$ready_steer"
    fi
  elif grep -Eq "(^|[^[:alnum:]_-])gh${pre}[[:space:]]+stack[[:space:]]+submit([[:space:]]|$)" <<<"$masked"; then
    asked && continue
    has "$masked" '--open' && refuse "gh stack submit --open opens its new pull requests ready for review." "$ready_steer"
    has "$masked" '--auto' || refuse "gh stack submit without --auto opens an editor where new pull requests default to ready." \
      "Add --auto, which opens them as drafts, and run it again."
  elif grep -Eq "(^|[^[:alnum:]_-])gs${pre}[[:space:]]+((stack|s|upstack|us|downstack|ds|branch|b)[[:space:]]+(submit|s)|ss|uss|dss|bs)([[:space:]]|$)" <<<"$masked"; then
    asked && continue
    has "$masked" '--no-draft' && refuse "gs submit --no-draft marks its pull requests ready for review." "$ready_steer"
    drafts "$masked" '--draft' || [ "$(git config --get spice.submit.draft 2>/dev/null)" = true ] ||
      refuse "gs submit opens new pull requests ready unless told otherwise." \
        "Run git config spice.submit.draft true once in this repo, which drafts only new pull requests, then run the submit again."
  fi
done < <(tr ';&|\n' '\n' <<<"$quoted")

exit 0 # mutant-ok delete: the loop above leaves status 0
