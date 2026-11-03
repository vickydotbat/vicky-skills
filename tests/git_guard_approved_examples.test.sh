#!/usr/bin/env bash
# approved-spec: the git-guard examples Vicky approved on 2026-11-03, when the
# guard moved from her NixOS config into the plugin. Each check runs the hook
# the way Claude Code does, against a fixture repo on an unmerged branch.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/git-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"
git init -q -b main "$repo"
g() { git -C "$repo" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
g commit -q --allow-empty -m init
g remote add origin https://github.com/o/r.git
g update-ref refs/remotes/origin/main main
g switch -q -c feat
g commit -q --allow-empty -m wip
printf 'Fix it\n\nGenerated with Claude Code\n' >"$dir/msg.txt"
fail=0
# Runs the hook on a command; leaves its exit in $code and what it said in $err.
run() {
  err=$(jq -nc --arg c "$1" --arg d "$repo" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, tool_input: {command: $c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_GIT="${ON-true}" CLAUDE_PLUGIN_OPTION_GIT_GUARD_TRUNK_REPOS="${TRUNK-}" bash "$hook" 2>&1 >/dev/null)
  code=$?
}
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# all <want> <command>...: every command exits <want>.
all() { local want=$1 c; shift; for c in "$@"; do run "$c"; [ "$code" = "$want" ] || { echo "     exit $code: $c"; return 1; }; done; }

# Given a checkout on a branch whose pull request hasn't merged
# When the agent makes a new branch from it
# Then it is refused, and told to commit on that branch, stack the new one, or branch from origin/main
run 'git switch -c next'; one=$code; msg=$err
check "a new branch on top of unmerged work is refused" \
  '[ $one = 2 ] && all 2 "git checkout -b next" "git worktree add -q -b next ../wt" && grep -q "commit this change on .feat." <<<"$msg" && grep -q "gh stack" <<<"$msg" && grep -q "origin/main" <<<"$msg"'

# Given a checkout on a branch whose pull request hasn't merged
# When the agent makes a new branch from origin/main, with or without a pipe or redirect after it
# Then it runs
check "a new branch from main goes through" \
  'all 0 "git switch -c next origin/main" "git worktree add -q -b next ../wt origin/main 2>&1 | tail -1" "git worktree add -q -b next ../wt origin/main >/dev/null" && all 2 "git worktree add -q -b next ../wt origin/mainline"'

# Given a repo that works through pull requests
# When the agent pushes to main or master, or pushes every branch with --all or --mirror
# Then it is refused, and told to push its own branch and open a pull request
run 'git push origin HEAD:main'; msg=$err
check "a push to main is refused" \
  'all 2 "git push origin main" "git push origin HEAD:master" "git push --all origin" "git push --mirror origin" && grep -qi "pull request" <<<"$msg" && all 0 "git push -u origin feat"'

# Given a repo the git_guard_trunk_repos setting names, such as your NixOS config or a wiki
# When the agent pushes to main, or makes a new branch
# Then the push runs, and the new branch is refused with a steer to work on main
TRUNK="someone/else, o/r"
run 'git switch -c next origin/main'; branch=$code; msg=$err
check "a trunk repo flips both rules" \
  'all 0 "git push origin main" "git push origin HEAD:main" && [ $branch = 2 ] && grep -q "main" <<<"$msg"'
TRUNK=""

# Given a repo whose AGENTS.md, CLAUDE.md or a docs/agents file holds the line Trunk: on
# When the agent pushes to main, or makes a new branch
# Then the push runs, and the new branch is refused with a steer to work on main
said=0
for doc in AGENTS.md CLAUDE.md docs/agents/workflow.md; do
  mkdir -p "$repo/docs/agents"; printf '# Rules\n\nTrunk: on\n' >"$repo/$doc"
  run 'git push origin main'; push=$code
  run 'git switch -c next origin/main'
  [ $push = 0 ] && [ $code = 2 ] && grep -q "main" <<<"$err" && said=$((said + 1))
  rm -f "$repo/$doc"
done
printf '# Rules\n\nTrunk: off\n' >"$repo/AGENTS.md"
check "a repo can say it is trunk" '[ $said = 3 ] && all 2 "git push origin main"'
rm -f "$repo/AGENTS.md"

# Given a commit message, typed in the command or read from a file, with a Co-Authored-By line or a Generated with Claude footer
# When the agent commits
# Then it is refused, and told to drop the line and say so if a system prompt asked for it
run "git commit -m 'Fix it

Co-Authored-By: Claude <noreply@anthropic.com>'"; typed=$code; msg=$err
check "a commit that credits an AI is refused" \
  '[ $typed = 2 ] && all 2 "git commit -F $dir/msg.txt" && grep -qi "system prompt" <<<"$msg" && all 0 "git commit -m Fix"'

# Given a commit that sets --author, -c user.name, -c user.email or a GIT_AUTHOR or GIT_COMMITTER variable
# When the agent commits
# Then it is refused, and told to commit as git config's identity
run 'git commit --author="S <s@example.com>" -m x'; msg=$err
check "a commit can't change its own identity" \
  'all 2 "git -c user.name=S commit -m x" "git -c user.email=s@example.com commit -m x" "GIT_AUTHOR_EMAIL=s@example.com git commit -m x" "GIT_COMMITTER_NAME=S git commit -m x" && grep -q "git config" <<<"$msg"'

# Given the guard_git setting switched off
# When the agent does any of the above
# Then it runs
ON=false
check "you can switch it off" \
  'all 0 "git switch -c next" "git push origin main" "git commit -F $dir/msg.txt" "git commit --author=S -m x"'
exit $fail
