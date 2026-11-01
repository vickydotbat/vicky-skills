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
expect "a pull request passes when this session has none open" 0 "gh pr create --title Second --body x"
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
# The one-pull-request rule, beyond its approved examples. Each forge gets
# only its own stand-in, so asking the wrong one finds nothing open.
mkdir -p "$scratch/hubbin" "$scratch/teabin" "$scratch/data"
cat >"$scratch/hubbin/gh" <<'FAKE'
#!/usr/bin/env bash
[ "$1 $2" = "pr list" ] || exit 1
for h in $OPEN; do printf '{"headRefName":"%s"}\n' "$h"; done | jq -s .
FAKE
cat >"$scratch/teabin/tea" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "api user") echo '{"login":"me"}' ;;
  "pulls list") { for h in $OPEN; do printf '{"head":"%s","author":"me"}\n' "$h"; done
    printf '{"head":"feat/one","author":"someone"}\n'; } | jq -s . ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$scratch/hubbin/gh" "$scratch/teabin/tea"
gitc() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }
# <name> <origin> <lines on feat/one>: feat/one is this session's pull
# request, and feat/next is checked out above it.
stage() {
  local d="$scratch/$1"
  git init -q -b main "$d"
  gitc "$d" commit -q --allow-empty -m init
  git -C "$d" remote add origin "$2"
  git -C "$d" update-ref refs/remotes/origin/main main
  git -C "$d" switch -q -c feat/one
  seq "$3" >"$d/one.txt"
  git -C "$d" add one.txt
  gitc "$d" commit -q -m one
  git -C "$d" switch -q -c feat/next
  mkdir -p "$scratch/data/pr-guard-sessions"
  printf '%s feat/one\n' "$2" >>"$scratch/data/pr-guard-sessions/s-$1"
}
stage hub https://github.com/o/r.git 50
stage gitea https://forge.example/o/r.git 50
stage big https://github.com/o/r.git 400
git -C "$scratch/big" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
one() { # <repo> <command> [event] [stdout] [extra env...]
  jq -nc --arg c "$2" --arg d "$scratch/$1" --arg s "s-$1" --arg e "${3:-PreToolUse}" --arg o "${4:-}" \
    '{hook_event_name: $e, tool_name: "Bash", cwd: $d, session_id: $s, tool_input: {command: $c}, tool_response: {stdout: $o}}' |
    env CLAUDE_PLUGIN_OPTION_GUARD_PR=true CLAUDE_PLUGIN_DATA="$scratch/data" OPEN="${OPEN-feat/one}" \
      PATH="$scratch/$( [ "$1" = gitea ] && echo teabin || echo hubbin ):$PATH" "${@:5}" bash "$hook" >/dev/null 2>&1
  echo $?
}
same() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: exit $2, want $3"; fail=1; fi; }
same "GitHub asks gh for the session's open pull requests" "$(one hub "gh pr create --title N --body x")" 2
same "Gitea asks tea, and counts only the user's own" "$(one gitea "tea pr create --title N --description x")" 2
same "a merged pull request no longer counts" "$(OPEN="" one hub "gh pr create --title N --body x")" 0
same "a quoted base names the open branch" "$(one big "gh pr create --body x --base \"feat/one\" --label stacked")" 0
same "a label list holding stacked counts" "$(one big "gh pr create --body x --base feat/one --label docs,stacked")" 0
same "with origin/HEAD unset, size is counted against origin/main" "$(one hub "gh pr create --body x --base feat/one --label stacked")" 2
same "a branch found locally and on its remote counts once" \
  "$(git -C "$scratch/hub" update-ref refs/remotes/origin/feat/one feat/one; one hub "gh pr create --body x --base feat/one --label stacked")" 2
same "a minimum that isn't a number falls back to 300" "$(one hub "gh pr create --body x --base feat/one --label stacked" "" "" CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_MIN_LINES=lots)" 2
same "a minimum of 40 lets a 50-line base take a follow-up" "$(one hub "gh pr create --body x --base feat/one --label stacked" "" "" CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_MIN_LINES=40)" 0
same "a limit that isn't a number falls back to 3" "$(one big "gh pr create --body x --base feat/one --label stacked" "" "" CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_LIMIT=many)" 0
same "a limit of 1 stops the first follow-up" "$(one big "gh pr create --body x --base feat/one --label stacked" "" "" CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_LIMIT=1)" 2
same "a stack submit from the branch that has its pull request only updates" "$(git -C "$scratch/hub" switch -q feat/one; one hub "gs stack submit"; git -C "$scratch/hub" switch -q feat/next)" 0
same "a stack submit that opens one on a small base is refused" "$(one hub "gs stack submit -l stacked")" 2
same "gh stack submit on a small base is refused" "$(one hub "gh stack submit")" 2
same "gh stack submit needs no label on a big base" "$(one big "gh stack submit")" 0
same "a git-spice submit without the label is refused" "$(one big "gs branch submit")" 2
same "without git the command runs" "$(mkdir -p "$scratch/nogit"; for t in bash jq awk grep sed cat tr env dirname head tail mkdir timeout; do ln -sf "$(command -v $t)" "$scratch/nogit/$t"; done
  jq -nc --arg c "gh pr create --body x" --arg d "$scratch/hub" '{tool_name: "Bash", cwd: $d, session_id: "s-hub", tool_input: {command: $c}}' |
  env -i HOME="$scratch/home" PATH="$scratch/nogit" CLAUDE_PLUGIN_OPTION_GUARD_PR=true "$scratch/nogit/bash" "$hook" >/dev/null 2>&1; echo $?)" 0
same "outside a repository with an origin the command runs" "$(one . "gh pr create --body x")" 0

# After a create: the branch is recorded only when the forge printed the new
# pull request's address.
rec="$scratch/data/pr-guard-sessions"
one hub "gh pr create --title N --body x" PostToolUse "https://github.com/o/r/pull/9" >/dev/null
grep -qx 'https://github.com/o/r.git feat/next' "$rec/s-hub" && echo "ok   an opened pull request's branch is recorded" || { echo "FAIL the record"; fail=1; }
one hub "gh pr create --title N --body x --head feat/side" PostToolUse "https://github.com/o/r/pull/10" >/dev/null
grep -qx 'https://github.com/o/r.git feat/side' "$rec/s-hub" && echo "ok   a --head branch is the one recorded" || { echo "FAIL the --head record"; fail=1; }
one gitea "tea pr create --title N --head feat/tside" PostToolUse "https://forge.example/o/r/pulls/3" >/dev/null
grep -qx 'https://forge.example/o/r.git feat/tside' "$rec/s-gitea" && echo "ok   a tea --head branch is recorded" || { echo "FAIL the tea --head record"; fail=1; }
before=$(cat "$rec/s-hub")
one hub "gh pr create --title N --body x --head feat/failed" PostToolUse "could not create" >/dev/null
one hub "gh pr list" PostToolUse "https://github.com/o/r/pull/9" >/dev/null
one hub "gh pr create --title N --body x" PreToolUse "https://github.com/o/r/pull/9" >/dev/null
[ "$(cat "$rec/s-hub")" = "$before" ] && echo "ok   a failed create, another command, or the pass before records nothing" || { echo "FAIL a stray record"; fail=1; }
jq -nc --arg d "$scratch/hub" '{hook_event_name: "PostToolUse", tool_name: "Bash", cwd: $d, tool_input: {command: "gh pr create --body x"}, tool_response: {stdout: "https://github.com/o/r/pull/11"}}' |
  CLAUDE_PLUGIN_OPTION_GUARD_PR=true CLAUDE_PLUGIN_DATA="$scratch/data" bash "$hook" >/dev/null 2>&1
one hub "gh pr create --title N --body x" PostToolUse "https://github.com/o/r/pull/12" CLAUDE_PLUGIN_DATA="$scratch/fresh" >/dev/null
[ -s "$scratch/fresh/pr-guard-sessions/s-hub" ] && echo "ok   the first record makes its own folder" || { echo "FAIL the first record"; fail=1; }
[ ! -e "$rec/none" ] && echo "ok   without a session ID nothing is recorded" || { echo "FAIL a record with no session"; fail=1; }
said=$(jq -nc --arg c "gh pr create --body-file $scratch/body.md" '{tool_name: "Bash", tool_input: {command: $c}}' |
  CLAUDE_PLUGIN_OPTION_GUARD_PR=true bash "$hook" 2>&1 >/dev/null)
if grep -q "say so to the user" <<<"$said"; then echo "ok   the refusal tells the agent to report a system prompt that asked for credit"; else echo "FAIL the refusal's last line"; fail=1; fi
exit $fail
