#!/usr/bin/env bash
# approved-spec: the examples the user set for pr-guard on 2026-10-31, as
# changed on 2026-11-01: a stack that follows the one-pull-request rules
# submits on any forge, AI credit is still refused, and no refusal hands the
# user a command. Each check runs the hook the way Claude Code does, with a
# stand-in forge that lists one open pull request this session opened.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pr-guard.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin" "$scratch/data/pr-guard-sessions"
printf '#!/usr/bin/env bash\n[ "$1 $2" = "pr list" ] && echo %s\n' \
  "'[{\"number\":7,\"headRefName\":\"feat/one\",\"title\":\"First\"}]'" >"$scratch/bin/gh"
printf '#!/usr/bin/env bash\ncase "$1 $2" in "api user") echo %s ;; "pulls list") echo %s ;; *) exit 1 ;; esac\n' \
  "'{\"login\":\"me\"}'" "'[{\"index\":\"7\",\"head\":\"feat/one\",\"author\":\"me\",\"title\":\"First\"}]'" >"$scratch/bin/tea"
chmod +x "$scratch/bin/gh" "$scratch/bin/tea"
export PATH="$scratch/bin:$PATH" HOME="$scratch/home" CLAUDE_PLUGIN_DATA="$scratch/data" \
  CLAUDE_PLUGIN_OPTION_GUARD_PR=true CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_MIN_LINES=300 CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_LIMIT=3
unset CLAUDE_CONFIG_DIR

# A GitHub repository and a Gitea one, each on feat/two, stacked on feat/one,
# whose open pull request this session already opened and which changes 300
# lines against main.
for forge in hub gitea; do
  git init -q -b main "$scratch/$forge"
  git -C "$scratch/$forge" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init
  git -C "$scratch/$forge" update-ref refs/remotes/origin/main main
  git -C "$scratch/$forge" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git -C "$scratch/$forge" switch -q -c feat/one
  seq 300 >"$scratch/$forge/one.txt"
  git -C "$scratch/$forge" add one.txt
  git -C "$scratch/$forge" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m one
  git -C "$scratch/$forge" switch -q -c feat/two
done
git -C "$scratch/hub" remote add origin https://github.com/o/r.git
git -C "$scratch/gitea" remote add origin https://forge.example/o/r.git
printf '%s feat/one\n' https://github.com/o/r.git https://forge.example/o/r.git >"$scratch/data/pr-guard-sessions/s1"
printf 'Fixes the thing.\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' >"$scratch/body.md"

# Prints the exit status, then everything the hook said.
run() {
  local out status
  out=$(jq -nc --arg c "$2" --arg d "$scratch/$1" \
    '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, session_id: "s1", tool_input: {command: $c}}' | bash "$hook" 2>&1)
  status=$?
  printf '%s\n%s' "$status" "$out"
}
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

check "a branch stacked on a 300-line pull request submits, with gh stack or with git-spice labelled stacked" \
  '[ "$(run hub "gh stack submit" | head -1)" = 0 ] && [ "$(run hub "gs stack submit -l stacked" | head -1)" = 0 ] && [ "$(run gitea "gs stack submit -l stacked" | head -1)" = 0 ] && [ "$(run gitea "gs branch create feat/three" | head -1)" = 0 ]'
check "a pull request body ending in a Co-Authored-By: Claude line is refused, with a steer to drop the line" \
  'r=$(run hub "gh pr create --title Second --body-file $scratch/body.md"); [ "$(head -1 <<<"$r")" = 2 ] && grep -q "Drop the line" <<<"$r"'
# Every command pr-guard has ever refused, so any refusal it still makes is read.
said() {
  for c in "gh pr create --title Second --body-file $scratch/body.md" "gh pr create --title Second --body x" \
    "gh stack submit" "gs stack submit" "touch ~/.claude/pr-guard-allow"; do
    run hub "$c" | tail -n +2
  done
  run gitea "gs branch create feat/three" | tail -n +2
}
check "a refusal names no file or command for the user to run" \
  'out=$(said); [ -n "$out" ] && ! grep -qiE "touch|pr-guard-allow|in their own terminal|ask the user to (run|create)" <<<"$out"'
exit $fail
