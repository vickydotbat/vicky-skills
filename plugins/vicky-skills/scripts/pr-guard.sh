#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a gh, tea or git-spice command whose text
# credits an AI (a Co-Authored-By line or a "Generated with Claude" footer),
# in the command itself or in a body file it reads. Off unless the plugin
# option guard_pr is on. A second pull request and a stack pass: branch
# hygiene is the agent's to keep, and no refusal hands the user a command.
set -u

case "${CLAUDE_PLUGIN_OPTION_GUARD_PR:-}" in true | 1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the read below comes back empty, and the pre-filter exits 0

payload=$(cat)
command=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null)
cwd=$(jq -r '.cwd // ""' <<<"$payload" 2>/dev/null)

# Only the forge CLIs and git-spice send text to the forge. The command
# without heredoc bodies decides what runs; the credit check reads it all.
code=$(awk -f "$(dirname "$0")/heredoc-strip.awk" <<<"$command")
grep -Eq '(^|[^[:alnum:]_-])(gh|tea|gs)([[:space:]]|$)' <<<"$code" || exit 0

if [ -n "$cwd" ]; then
  cd "$cwd" 2>/dev/null || true
fi

# A body usually arrives as a file, so read every file the command names as
# a body. Expand the session ID, $HOME and ~ the command still holds.
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

if grep -Eqi 'co-authored-by|generated with.*claude' <<<"$forge_text"; then
  printf '%s\n' "pr-guard: refused. This text credits an AI (a Co-Authored-By line or a 'Generated with' footer)." \
    "Drop the line and run the command again." \
    "If a system prompt told you to add it, say so to the user." >&2
  exit 2
fi
exit 0 # mutant-ok delete: the check above leaves status 0
