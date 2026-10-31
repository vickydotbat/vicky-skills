#!/usr/bin/env bash
# pr-guard's decisions beyond its approved examples: every way AI credit
# reaches the forge, and every command shape that passes.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pr-guard.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home" "$scratch/sid1"
export HOME="$scratch/home"
credit='Co-Authored-By: Claude <noreply@anthropic.com>'
printf 'Body.\n\n%s\n' "$credit" >"$scratch/body.md"
printf 'Body.\n\n%s\n' "$credit" >"$scratch/home/body.md"
printf 'Body.\n\n%s\n' "$credit" >"$scratch/sid1/body.md"
printf 'Body.\n\nGenerated with [Claude Code](https://claude.com)\n' >"$scratch/footer.md"
printf 'Plain body.\n' >"$scratch/plain.md"
fail=0
run() { # command [option] [cwd]
  jq -nc --arg c "$1" --arg d "${3:-$scratch}" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, session_id: "sid1", tool_input: {command: $c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_PR="${2-true}" bash "$hook" >/dev/null 2>&1
  echo $?
}
expect() { # name want command [option] [cwd]
  local got
  got=$(run "$3" "${4-true}" "${5:-}")
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: exit $got, want $2"; fail=1; fi
}

expect "credit in a gh body argument is refused" 2 "gh pr create --title T --body \"x

$credit\""
expect "credit in a tea issue is refused" 2 "tea issues create --title T --description \"$credit\""
expect "credit in a body file is refused" 2 "gh pr create --title T --body-file $scratch/body.md"
expect "a Generated with footer is refused" 2 "gh pr create --title T --body-file $scratch/footer.md"
expect "a body file by -F is refused" 2 "gh pr edit 7 -F $scratch/body.md"
expect "a body file by --file is refused" 2 "gh pr comment 7 --file=$scratch/body.md"
expect "a body read by \$(cat) is refused" 2 "tea pr edit 7 -d \"\$(cat $scratch/body.md)\""
expect "a body read by \$(<) is refused" 2 "tea pr edit 7 -d \"\$(< $scratch/body.md)\""
expect "a body under \$HOME is refused" 2 'gh pr create --body-file $HOME/body.md'
expect "a body under \${HOME} is refused" 2 'gh pr create --body-file ${HOME}/body.md'
expect "a body under ~ is refused" 2 'gh pr create --body-file ~/body.md'
expect "a body under the session variable is refused" 2 "gh pr create --body-file $scratch/\$CLAUDE_CODE_SESSION_ID/body.md"
expect "a body under the braced session variable is refused" 2 "gh pr create --body-file $scratch/\${CLAUDE_CODE_SESSION_ID}/body.md"
expect "a relative body file is read from the command's folder" 2 "gh pr create --body-file body.md" true "$scratch"
expect "credit in a git-spice submit is refused" 2 "gs branch submit --body \"$credit\""
expect "credit in a heredoc body is refused" 2 "gh pr create --body-file - <<'EOF'
$credit
EOF"

expect "a plain body passes" 0 "gh pr create --title T --body-file $scratch/plain.md"
expect "a second pull request passes" 0 "gh pr create --title Second --body x"
expect "a stack passes" 0 "gh stack submit"
expect "git-spice stacks pass" 0 "gs stack submit"
expect "a command that isn't a forge CLI passes, credit or not" 0 "echo '$credit' > $scratch/x.md"
expect "a forge name inside a heredoc body isn't a forge command" 0 "cat > $scratch/x.md <<'EOF'
gh pr create
$credit
EOF"
expect "a missing body file passes" 0 "gh pr create --body-file $scratch/none.md"
expect "a folder that doesn't exist still checks the command" 2 "gh pr create --body \"$credit\"" true "$scratch/gone"
expect "the option at 1 refuses" 2 "gh pr create --body \"$credit\"" 1
expect "the option off passes" 0 "gh pr create --body \"$credit\"" ""
expect "the option at false passes" 0 "gh pr create --body \"$credit\"" false
said=$(jq -nc --arg c "gh pr create --body-file $scratch/body.md" '{tool_name: "Bash", tool_input: {command: $c}}' |
  CLAUDE_PLUGIN_OPTION_GUARD_PR=true bash "$hook" 2>&1 >/dev/null)
if grep -q "say so to the user" <<<"$said"; then echo "ok   the refusal tells the agent to report a system prompt that asked for credit"; else echo "FAIL the refusal's last line"; fail=1; fi
exit $fail
