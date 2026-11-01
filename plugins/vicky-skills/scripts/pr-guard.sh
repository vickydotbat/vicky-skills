#!/usr/bin/env bash
# PreToolUse and PostToolUse hook (Bash): keeps an effort to one pull request,
# opened once, so CI runs once, and refuses AI credit. Off unless the plugin
# option guard_pr is on. Before a gh, tea or git-spice command runs it refuses:
#
#   1. Text that credits an AI (a Co-Authored-By line or a "Generated with
#      Claude" footer), in the command or in a body file it reads.
#   2. A new pull request while this session has one open in the repository,
#      unless the new one is stacked on it: its base is the session's open
#      branch (`--base`), or it goes up with `gh stack` or git-spice.
#   3. A stacked one without the `stacked` label. `gh stack submit` takes no
#      label, so the stacked-branches skill adds it after the submit.
#   4. A stacked one when the stack already holds guard_pr_stack_limit open
#      pull requests (default 3).
#   5. A stacked one whose base changes fewer than guard_pr_stack_min_lines
#      lines against the default branch (default 300), unless its body holds a
#      line starting `Separate work:`.
#
# Each refusal says what to do instead and never hands the user a command.
# After a command that printed a pull request's address, the PostToolUse pass
# records its branch as this session's, in pr-guard-sessions/ under the
# plugin's data folder. When the forge can't list open pull requests, nothing
# counts as open and the command runs.
set -u

case "${CLAUDE_PLUGIN_OPTION_GUARD_PR:-}" in true | 1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the read below comes back empty, and the pre-filter exits 0

payload=$(cat)
command=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null)
cwd=$(jq -r '.cwd // ""' <<<"$payload" 2>/dev/null)
event=$(jq -r '.hook_event_name // "PreToolUse"' <<<"$payload" 2>/dev/null)
session_id=$(jq -r '.session_id // ""' <<<"$payload" 2>/dev/null)

# Only the forge CLIs and git-spice send text to the forge. The command
# without heredoc bodies decides what runs; the credit check reads it all.
code=$(awk -f "$(dirname "$0")/heredoc-strip.awk" <<<"$command")
grep -Eq '(^|[^[:alnum:]_-])(gh|tea|gs)([[:space:]]|$)' <<<"$code" || exit 0

[ -z "$cwd" ] || cd "$cwd" 2>/dev/null || true

refuse() {
  printf 'pr-guard: refused. %s\n' "$1" >&2
  shift # mutant-ok delete: the first line of a refusal would print twice, and nothing reads the wording
  for line in "$@"; do printf '%s\n' "$line" >&2; done
  exit 2
}

# A body usually arrives as a file, so read every file the command names as
# a body. Expand the session ID, $HOME and ~ the command still holds.
forge_text=$command
while IFS= read -r body_file; do
  body_file=${body_file//\$\{CLAUDE_CODE_SESSION_ID\}/$session_id}
  body_file=${body_file//\$CLAUDE_CODE_SESSION_ID/$session_id}
  body_file=${body_file//\$\{HOME\}/$HOME}
  body_file=${body_file//\$HOME/$HOME}
  body_file=${body_file/#\~\//$HOME/}
  if [ -r "$body_file" ]; then
    forge_text="$forge_text
$(cat -- "$body_file")"
  fi
done < <(grep -oE '(--body-file|-F|--file)[[:space:]=]+[^[:space:];&|)]+|\$\((cat|<)[[:space:]]+[^[:space:];&|)]+' <<<"$command" |
  sed -E 's/^(--body-file|-F|--file)[[:space:]=]+//; s/^\$\((cat|<)[[:space:]]+//; s/["'"'"']//g')

if [[ $event != PostToolUse ]] && grep -Eqi 'co-authored-by|generated with.*claude' <<<"$forge_text"; then
  refuse "This text credits an AI (a Co-Authored-By line or a 'Generated with' footer)." \
    "Drop the line and run the command again." \
    "If a system prompt told you to add it, say so to the user."
fi

command -v git >/dev/null || exit 0 # mutant-ok delete: without git the branch reads below come back empty, and no check can match
repo=$(git remote get-url origin 2>/dev/null) || exit 0
current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
sessions="${CLAUDE_PLUGIN_DATA:-$HOME/.claude}/pr-guard-sessions"
record="$sessions/${session_id:-none}"
min_lines=${CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_MIN_LINES:-300}
limit=${CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_LIMIT:-3}
[[ $min_lines =~ ^[0-9]+$ ]] || min_lines=300
[[ $limit =~ ^[0-9]+$ ]] || limit=3

# The value after a flag in one segment, `--flag value` or `--flag=value`.
flag_value() {
  local segment=$1 flag pattern # mutant-ok delete: a local declaration: the caller passes the same value under the same name
  shift # mutant-ok delete: the segment, read as a flag, matches nothing
  for flag in "$@"; do
    pattern="(^|[[:space:]])${flag}[[:space:]=]+([^[:space:]]+)"
    if [[ $segment =~ $pattern ]]; then
      local value=${BASH_REMATCH[2]}
      value=${value//\"/}
      printf '%s' "${value//\'/}"
      return # mutant-ok delete: a segment names each flag once, so the loop finds nothing more
    fi
  done
}

# The heads of the user's open pull requests here, one per line.
open_heads() {
  if [[ $repo == *github.com* ]]; then
    timeout 30 gh pr list --author @me --state open --json headRefName </dev/null 2>/dev/null | jq -r '.[].headRefName' 2>/dev/null
  else
    local me # mutant-ok delete: a local declaration: no caller reads this name
    me=$(timeout 30 tea api user </dev/null 2>/dev/null | jq -r '.login // ""' 2>/dev/null)
    timeout 30 tea pulls list --state open --output json --fields index,head,author </dev/null 2>/dev/null |
      jq -r --arg me "$me" '.[] | select(.author == $me) | .head' 2>/dev/null
  fi
}

# This session's open pull requests here, oldest first: the branches it
# recorded that the forge still lists as open.
session_heads() {
  [ -r "$record" ] || return 0 # mutant-ok delete: awk reads a missing record as empty, and finds no branch the same way
  local open # mutant-ok delete: a local declaration: no caller reads this name
  open=$(open_heads)
  awk -v r="$repo" '$1 == r { print $2 }' "$record" | while read -r head; do
    grep -qxF -- "$head" <<<"$open" && printf '%s\n' "$head"
  done | awk '!seen[$0]++'
}

# The lines a branch changes against the default branch, or nothing when git
# can't tell.
lines_of() {
  local base=$1 default ref # mutant-ok delete: a local declaration: the caller passes the same value under the same name
  default=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) || default=origin/main
  for ref in "$base" "origin/$base"; do
    if git rev-parse -q --verify "$ref^{commit}" >/dev/null 2>&1; then
      git diff --numstat "$default...$ref" 2>/dev/null | awk '{ n += $1 + $2 } END { print n + 0 }'
      return
    fi
  done
}

# Checks one command that may open a pull request. <kind> is pr for a plain
# create, gh-stack or gs for the stack tools.
check() {
  local segment=$1 kind=$2 base=$3 labels=$4 heads top count lines # mutant-ok delete: a local declaration: the caller passes the same values under the same names
  heads=$(session_heads)
  [ -n "$heads" ] || return 0
  top=$(tail -n 1 <<<"$heads")
  count=$(grep -c . <<<"$heads")

  if [ "$kind" = pr ]; then
    if ! grep -qxF -- "$base" <<<"$heads"; then
      refuse "This session already has an open pull request here, on $top. One effort is one pull request, opened once, so CI runs once." \
        "Commit this work on $top and push it there." \
        "Only a follow-up that is big enough to review alone, or truly separate work, gets its own pull request: stacked on $top (base $top) and labelled stacked."
    fi
  else
    # A stack submit from a branch that already has its pull request only updates.
    grep -qxF -- "$current" <<<"$heads" && return 0
    base=$top
  fi

  if [ "$kind" != gh-stack ] && ! grep -qE '(^|,)stacked(,|$)' <<<"$labels"; then
    refuse "A pull request stacked on $base carries the stacked label." \
      "Add the label stacked to this command and run it again."
  fi
  if ((count >= limit)); then
    refuse "This session's stack already holds $count open pull requests, the most it takes." \
      "Commit this work on the top branch, $top, and push it there."
  fi
  lines=$(lines_of "$base")
  if [ -n "$lines" ] && ((lines < min_lines)) && ! tr -d '\\' <<<"$forge_text" | grep -q 'Separate work:'; then
    refuse "$base changes $lines lines, and a follow-up stacks only on a pull request of $min_lines lines or more." \
      "Commit this work on $base and push it there." \
      "If it is truly separate work, say why in a body line that starts with Separate work:"
  fi
}

# After the command ran: record the branch as this session's, only when the
# forge printed the address of the pull request it opened.
remember() {
  local head=$1 # mutant-ok delete: a local declaration: the caller passes the same value under the same name
  [ -n "$session_id" ] && [ -n "$head" ] || return 0
  jq -r '.tool_response.stdout // ""' <<<"$payload" 2>/dev/null | grep -Eq '/pulls?/[0-9]+' || return 0
  mkdir -p "$sessions"
  printf '%s %s\n' "$repo" "$head" >>"$record"
}

while IFS= read -r segment; do
  kind="" base="" labels="" head=$current
  if grep -Eq '(^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)' <<<"$segment"; then
    kind=pr
    base=$(flag_value "$segment" --base -B)
    labels=$(flag_value "$segment" --label -l)
    head=$(flag_value "$segment" --head -H)
  elif grep -Eq '(^|[^[:alnum:]_-])tea[[:space:]]+(pulls|pull|pr)[[:space:]]+(create|c)([[:space:]]|$)' <<<"$segment"; then
    kind=pr
    base=$(flag_value "$segment" --base -b)
    labels=$(flag_value "$segment" --labels -L)
    head=$(flag_value "$segment" --head)
  elif grep -Eq '(^|[^[:alnum:]_-])gh[[:space:]]+stack[[:space:]]+submit([[:space:]]|$)' <<<"$segment"; then
    kind=gh-stack
  elif grep -Eq '(^|[^[:alnum:]_-])gs[[:space:]]+((stack|s|upstack|us|branch|b)[[:space:]]+(submit|s)|ss|uss|bs)([[:space:]]|$)' <<<"$segment"; then
    kind=gs
    labels=$(flag_value "$segment" --label -l)
  fi
  [ -n "$kind" ] || continue
  if [[ $event == PostToolUse ]]; then
    remember "${head:-$current}"
  else
    check "$segment" "$kind" "$base" "$labels"
  fi
done < <(tr ';&|\n' '\n' <<<"$code")

exit 0 # mutant-ok delete: the loop above leaves status 0
