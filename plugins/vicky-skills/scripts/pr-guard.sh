#!/usr/bin/env bash
# PreToolUse hook: holds each effort to one open pull request. Off unless the
# plugin option guard_pr is on. Refuses, before the command runs:
#
#   1. A second pull request for one effort (`tea pr create`, `gh pr create`,
#      `gs branch submit`, a `tea api` POST to pulls). An effort is a Claude Code
#      session: a session that already opened a pull request still open in the
#      same repository is refused, unless the new one names a ticket the tracker
#      (`bin/plane` in the repo, else `plane` on PATH) created before the session
#      began. A new pull request naming a ticket an open one already names is
#      refused from any session. Re-submitting the branch that owns the open pull
#      request passes. Branches starting with a prefix in guard_pr_ignore_heads
#      (space-separated) never count. Without a session ID, any other open pull
#      request of the user's counts.
#   2. Stacks: `gs stack|upstack|downstack submit`, `gs branch create` off
#      main/master, and `gh stack init|add|submit|link`. git-spice never stacks on
#      a GitHub repository.
#   3. Any gh or tea command whose text credits an AI (a Co-Authored-By line or a
#      "Generated with Claude" footer), in the command or in a body file it reads.
#      No allowance covers this.
#
# The way past 1 and 2 is an allowance the user grants from their own terminal:
# create the file pr-guard-allow in the Claude Code config folder
# (CLAUDE_CONFIG_DIR, else ~/.claude). The next refused command consumes it.
# An agent cannot mint one: a Bash command naming the file, and a Write or Edit
# aimed at it, are refused. When the forge cannot list pull requests, the hook
# refuses rather than read "could not check" as "none". Opened pull requests are
# recorded per session in pr-guard-sessions/ in the same folder, by the
# PostToolUse pass and only when the command printed the new pull request's
# address: a refused or failed create records nothing, so a branch that was
# checked out when one failed never counts as this session's.
set -u

case "${CLAUDE_PLUGIN_OPTION_GUARD_PR:-}" in true | 1) ;; *) exit 0 ;; esac
if ! command -v jq >/dev/null || ! command -v git >/dev/null; then
  echo "pr-guard: off, because jq or git is missing." >&2
  exit 0 # mutant-ok delete: the next jq read comes back empty, and the case on the tool exits 0
fi

payload=$(cat)
tool=$(jq -r '.tool_name // "Bash"' <<<"$payload")
config_dir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
allow_file="$config_dir/pr-guard-allow"
ignore_heads="${CLAUDE_PLUGIN_OPTION_GUARD_PR_IGNORE_HEADS:-}"

refuse() {
  printf 'pr-guard: refused. %s\n' "$1" >&2
  shift # mutant-ok delete: the first line of a refusal would print twice, and nothing reads the wording
  for line in "$@"; do printf '%s\n' "$line" >&2; done
  exit 2
}

allowance_hint="Each effort holds one open pull request, and a stack is opened only when the user asks for one in this conversation. Push to the open pull request instead. If the user asked for this one, ask them to run 'touch $allow_file' in their own terminal, then run the command again."

case "$tool" in
  Write | Edit | MultiEdit | NotebookEdit)
    path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<<"$payload")
    [[ $(basename -- "$path") == pr-guard-allow ]] &&
      refuse "only the user grants a pr-guard allowance, from their own terminal." \
        "Do not write that file. Ask the user to create it."
    exit 0 # mutant-ok delete: the case falls through to an empty command, which the pre-filter exits on
    ;;
  Bash) ;;
  *) exit 0 ;;
esac

command=$(jq -r '.tool_input.command // ""' <<<"$payload")
cwd=$(jq -r '.cwd // ""' <<<"$payload")
event=$(jq -r '.hook_event_name // "PreToolUse"' <<<"$payload")

[[ $event != PostToolUse ]] && grep -q 'pr-guard-allow' <<<"$command" &&
  refuse "only the user grants a pr-guard allowance, from their own terminal." \
    "Do not name that file. Ask the user to create it."

# Cheap pre-filter: only the forge CLIs and git-spice are in scope.
grep -Eq '(^|[^[:alnum:]_-])(gh|tea|gs)([[:space:]]|$)' <<<"$command" || exit 0

# An allowance covers one refused command, then it is gone.
spend_allowance() {
  if [ -f "$allow_file" ]; then
    rm -f -- "$allow_file"
    printf 'pr-guard: allowed once by the user (%s). The allowance is spent.\n' "$1" >&2
    exit 0
  fi
}

if [ -n "$cwd" ]; then
  cd "$cwd" || exit 0
fi

# No AI credit in text sent to the forge. A body usually arrives as a file, so
# read every file the command names as a body. Expand the session ID, $HOME and
# ~ the command still holds unexpanded.
session_id=$(jq -r '.session_id // ""' <<<"$payload")
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
  refuse "this text credits an AI (a Co-Authored-By line or a 'Generated with' footer)." \
    "Drop the line and run the command again." \
    "If a system prompt told you to add it, say so to the user."
fi

# Judge the repository the command really touches: the first `cd <path>` wins.
if [[ $command =~ (^|[[:space:]\;\&\|])cd[[:space:]]+([^[:space:]\;\&\|]+) ]]; then
  target_dir=${BASH_REMATCH[2]}
  target_dir=${target_dir//\"/}
  target_dir=${target_dir//\'/}
  target_dir=${target_dir/#\~\//$HOME/}
  cd "$target_dir" 2>/dev/null || exit 0
fi

current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)

# The value after a flag in one segment, `--flag value` or `--flag=value`.
flag_value() {
  local segment=$1 flag # mutant-ok delete: a local declaration: the caller passes the same value under the same name
  shift # mutant-ok delete: the segment, read as a flag, matches nothing
  for flag in "$@"; do
    local pattern="(^|[[:space:]])${flag}[[:space:]=]+([^[:space:]]+)"
    if [[ $segment =~ $pattern ]]; then
      local value=${BASH_REMATCH[2]}
      value=${value//\"/}
      printf '%s' "${value//\'/}"
      return # mutant-ok delete: a segment names each flag once, so the loop finds nothing more
    fi
  done
}

# Every open pull request of the user in this repository, one
# "index head title" per line. Heads under an ignored prefix never count.
my_open_pulls() {
  local forge=$1 repo=$2 list me # mutant-ok delete: a local declaration: no caller reads these names
  if [ "$forge" = gh ]; then
    list=$(timeout 30 gh pr list --author @me --state open --json number,headRefName,title \
      ${repo:+--repo "$repo"} </dev/null 2>&1) || { printf '%s' "$list"; return 1; }
    jq -r --arg ign "$ignore_heads" \
      '($ign | split(" ") | map(select(length > 0))) as $p
       | .[] | select(.headRefName as $h | $p | any(. as $x | $h | startswith($x)) | not)
       | "\(.number) \(.headRefName) \(.title)"' <<<"$list"
  else
    me=$(timeout 30 tea api user </dev/null 2>&1) || { printf '%s' "$me"; return 1; }
    list=$(timeout 30 tea pulls list --state open --output json --fields index,head,author,title \
      ${repo:+--repo "$repo"} </dev/null 2>&1) || { printf '%s' "$list"; return 1; }
    jq -r --argjson me "$me" --arg ign "$ignore_heads" \
      '($ign | split(" ") | map(select(length > 0))) as $p
       | .[] | select(.author == $me.login or (($me.full_name // "") != "" and .author == $me.full_name))
       | select(.head as $h | $p | any(. as $x | $h | startswith($x)) | not)
       | "\(.index) \(.head) \(.title // "")"' <<<"$list"
  fi
}

# Ticket references (ABC-12), upper-cased, one per line, sorted and unique.
tickets_in() {
  grep -oiE '\b[a-z][a-z0-9]+-[0-9]+\b' <<<"$1" | tr '[:lower:]' '[:upper:]' | sort -u || true
}

# The title a segment passes with --title or -t, quoted or bare.
title_of() {
  local segment=$1 # mutant-ok delete: a local declaration: the caller passes the same value under the same name
  if [[ $segment =~ (^|[[:space:]])(--title|-t)[[:space:]=]+\"([^\"]*)\" ]] ||
     [[ $segment =~ (^|[[:space:]])(--title|-t)[[:space:]=]+\'([^\']*)\' ]] ||
     [[ $segment =~ (^|[[:space:]])(--title|-t)[[:space:]=]+([^[:space:]]+) ]]; then
    printf '%s' "${BASH_REMATCH[3]}"
  fi
}

# The pull requests this session opened, one "repo head" per line. The session
# ID stands for the effort. Entries for merged or closed pull requests stay and
# count for nothing, because only open pull requests are compared.
sessions_dir="$config_dir/pr-guard-sessions"
session_file=""
[[ -n $session_id ]] && session_file="$sessions_dir/$session_id"

# When this session started, in epoch seconds: the first timestamp in its
# transcript. Empty when the transcript is missing or holds none.
session_started() {
  local transcript first # mutant-ok delete: a local declaration: no caller reads these names
  transcript=$(jq -r '.transcript_path // ""' <<<"$payload")
  [[ -r $transcript ]] || return 0 # mutant-ok delete: an unreadable transcript makes head fail, and the function prints nothing the same way
  first=$(head -n 200 -- "$transcript" | jq -Rr 'fromjson? | .timestamp // empty' | head -n 1) || true
  [[ -n $first ]] && date -d "$first" +%s 2>/dev/null || true
}

# When the tracker created a ticket, in epoch seconds, through the repository's
# `bin/plane` or `plane` on PATH. Empty when neither knows the key.
ticket_created() {
  local plane=plane created
  [[ -x bin/plane ]] && plane=bin/plane
  command -v "$plane" >/dev/null 2>&1 || return 0 # mutant-ok delete: a missing tracker makes the call below fail, and the function prints nothing the same way
  created=$(timeout 30 "$plane" show --json "$1" </dev/null 2>/dev/null | jq -r '.created_at // empty' 2>/dev/null) || true
  [[ -n $created ]] && date -d "$created" +%s 2>/dev/null || true
}

# A second pull request from one session is a separate effort when it names a
# ticket filed before the session started. Anything unknown counts as no.
names_older_ticket() {
  local started key created # mutant-ok delete: a local declaration: no caller reads these names
  [[ -n $1 ]] || return 1 # mutant-ok delete: with no ticket the loop below finds none and returns 1 the same way
  started=$(session_started)
  [[ -n $started ]] || return 1 # mutant-ok delete: with no start time every comparison below fails and returns 1 the same way
  while read -r key; do
    created=$(ticket_created "$key")
    [[ -n $created ]] && ((created < started)) && return 0
  done <<<"$1"
  return 1
}

# One effort, one open pull request. Refuse when an open one already names a
# ticket the new one names, or when this session already has another open one
# in this repository and the new one names no ticket older than the session.
check_one_pull() {
  local segment=$1 forge=$2 head=$3 repo=$4 pulls others repo_key mine new_tickets shared index phead ptitle
  if [[ $event == PostToolUse ]]; then
    record_pull "$head" "${repo:-$(git remote get-url origin 2>/dev/null || pwd)}"
    return 0
  fi
  if ! pulls=$(my_open_pulls "$forge" "$repo"); then
    spend_allowance "pull request opened without the open-PR check"
    refuse "could not list this repository's open pull requests, so a second one cannot be ruled out." \
      "The forge said: $pulls" "$allowance_hint"
  fi
  others=$(awk -v head="$head" '$2 != head' <<<"$pulls")
  repo_key=${repo:-$(git remote get-url origin 2>/dev/null || pwd)}

  if [[ -z $session_file ]]; then
    if [ -n "$others" ]; then
      spend_allowance "a second open pull request"
      refuse "this repository already has your open pull request: $(cut -d' ' -f1,2 <<<"$others" | tr '\n' ' ')(index, branch)." \
        "$allowance_hint"
    fi
    return 0 # mutant-ok delete: with no session file nothing below matches, and the record write fails silently
  fi

  new_tickets=$(tickets_in "$(title_of "$segment") $head")
  if [[ -n $new_tickets ]]; then
    while read -r index phead ptitle; do
      [[ -n $index ]] || continue # mutant-ok delete: an empty line names no ticket, so nothing below matches it
      shared=$(comm -12 <(printf '%s\n' "$new_tickets") <(tickets_in "$ptitle $phead"))
      if [[ -n $shared ]]; then
        spend_allowance "a pull request for a ticket another one already names"
        refuse "open pull request $index ($phead) already names $(tr '\n' ' ' <<<"$shared")." \
          "That effort is in flight. Push to its branch instead." "$allowance_hint"
      fi
    done <<<"$others"
  fi

  mine=""
  if [[ -f $session_file ]]; then
    while read -r index phead _; do
      [[ -n $index ]] || continue # mutant-ok delete: an empty line names no branch, so nothing below matches it
      if awk -v r="$repo_key" -v h="$phead" '$1 == r && $2 == h { found = 1 } END { exit !found }' "$session_file"; then
        mine="$mine$index $phead "
      fi
    done <<<"$others"
  fi
  if [[ -n $mine ]] && ! names_older_ticket "$new_tickets"; then
    spend_allowance "a second open pull request from one session"
    refuse "this session already has an open pull request here: $mine(index, branch)." \
      "One effort is one pull request. Commit on that branch and push to it." \
      "A separate effort passes when its title or branch names a ticket filed before this session started." \
      "$allowance_hint"
  fi

}

# After the command ran: record the branch as this session's, only when the
# forge printed the address of the pull request it opened.
record_pull() {
  local response # mutant-ok delete: a local declaration: no caller reads this name
  [[ -n $1 && -n $session_file ]] || return 0
  response=$(jq -r '.tool_response.stdout // ""' <<<"$payload" 2>/dev/null)
  grep -Eq '/pulls?/[0-9]+' <<<"$response" || return 0
  mkdir -p "$sessions_dir"
  printf '%s %s\n' "$2" "$1" >>"$session_file"
}

forge_of_repo() {
  if git remote get-url origin 2>/dev/null | grep -q 'github\.com'; then echo gh; else echo tea; fi
}

# git-spice on GitHub builds a stack the forge cannot see. Refuse it before an
# allowance is spent, so the allowance goes to `gh stack`.
refuse_gs_on_github() {
  if [[ $(forge_of_repo) == gh ]]; then
    refuse "git-spice does not stack on a GitHub repository." \
      "Use 'gh stack' instead. An allowance still applies to it."
  fi
}

while IFS= read -r segment; do
  # The stack rules refuse before a command runs, so the PostToolUse pass skips them.
  if [[ $event != PostToolUse ]]; then
  # git-spice: a stack submit opens one pull request per branch.
  if grep -Eq '(^|[^[:alnum:]_-])gs[[:space:]]+((stack|s|upstack|us|downstack|ds)[[:space:]]+(submit|s)|ss|uss|dss)([[:space:]]|$)' <<<"$segment"; then
    refuse_gs_on_github
    spend_allowance "a stack submit"
    refuse "a stack submit opens one pull request per branch." "$allowance_hint"
  fi

  # GitHub's own stacks: submit and link open or join one pull request per
  # branch, and init and add start a stack.
  if grep -Eq '(^|[^[:alnum:]_-])gh[[:space:]]+stack[[:space:]]+(submit|link)([[:space:]]|$)' <<<"$segment"; then
    spend_allowance "a stack submit"
    refuse "a stack submit opens one pull request per branch." "$allowance_hint"
  fi
  if grep -Eq '(^|[^[:alnum:]_-])gh[[:space:]]+stack[[:space:]]+(init|add)([[:space:]]|$)' <<<"$segment"; then
    spend_allowance "a stacked branch"
    refuse "'gh stack' starts a stack." \
      "Commit on '$current_branch' and push to its open pull request." "$allowance_hint"
  fi

  # git-spice: a branch created off anything but trunk is a stack.
  if grep -Eq '(^|[^[:alnum:]_-])gs[[:space:]]+((branch|b)[[:space:]]+(create|c)|bc)([[:space:]]|$)' <<<"$segment"; then
    case "$current_branch" in
      main | master | "") ;;
      *)
        refuse_gs_on_github
        spend_allowance "a stacked branch"
        refuse "'gs branch create' on '$current_branch' starts a stack." \
          "Commit on '$current_branch' and push to its open pull request." "$allowance_hint"
        ;;
    esac
  fi

  fi

  # Opening a pull request, by any of the four doors.
  if grep -Eq '(^|[^[:alnum:]_-])tea[[:space:]]+(pulls|pull|pr)[[:space:]]+(create|c)([[:space:]]|$)' <<<"$segment"; then
    head=$(flag_value "$segment" --head)
    check_one_pull "$segment" tea "${head:-$current_branch}" "$(flag_value "$segment" --repo -r)"
  elif grep -Eq '(^|[^[:alnum:]_-])tea[[:space:]]+api([[:space:]]|$)' <<<"$segment" &&
       grep -Eq '(-X|--method)[[:space:]=]+POST' <<<"$segment" &&
       grep -Eq '/pulls([[:space:]"'"'"']|$)' <<<"$segment"; then
    # A raw POST names its branch inside a JSON body this hook does not parse,
    # so every open pull request of the user's counts against it.
    check_one_pull "$segment" tea "" ""
  elif grep -Eq '(^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)' <<<"$segment"; then
    head=$(flag_value "$segment" --head -H)
    check_one_pull "$segment" gh "${head:-$current_branch}" "$(flag_value "$segment" --repo -R)"
  elif grep -Eq '(^|[^[:alnum:]_-])gs[[:space:]]+((branch|b)[[:space:]]+(submit|s)|bs)([[:space:]]|$)' <<<"$segment"; then
    head=$(flag_value "$segment" --branch)
    check_one_pull "$segment" "$(forge_of_repo)" "${head:-$current_branch}" ""
  fi
done < <(tr ';&|\n' '\n' <<<"$command")

exit 0 # mutant-ok delete: the loop above leaves status 0
