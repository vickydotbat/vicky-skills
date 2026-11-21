#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034,SC2329 # each check is a string check() evals: it reads code, told and silent there
# merged-branch-guard tells the agent at session start, and on its first
# command in a checkout, that the checkout stands on a merged branch, and names
# the heads of the user's open pull requests there. The commit and push
# refusal names them too.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/merged-branch-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
export CLAUDE_PLUGIN_DATA="$scratch/data"
# The machine's own git config could rewrite the forge URL below to a real forge.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; sed 's/^/     /' "$scratch/out" "$scratch/err" 2>/dev/null; fail=1; fi; }
gi() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }
# A fake gh and tea: the user's open pull requests have the heads in $scratch/heads.
mkdir "$scratch/bin"
cat > "$scratch/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2" = "pr list" ] || exit 1
jq -Rn '[inputs | select(length > 0) | {headRefName: .}]' < "$HEADS"
EOF
cat > "$scratch/bin/tea" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2" = "api user" ] && { echo '{"login":"me"}'; exit 0; }
[ "$1 $2" = "pulls list" ] || exit 1
jq -Rn '[inputs | select(length > 0) | {head: ., author: "me"}] + [{head: "someone-elses", author: "you"}]' < "$TEA_HEADS"
EOF
chmod +x "$scratch/bin/gh" "$scratch/bin/tea"
export HEADS="$scratch/heads" TEA_HEADS="$scratch/tea-heads"; printf 'warp/next-effort\n' > "$HEADS"; printf 'tea-only\n' > "$TEA_HEADS"
export PATH="$scratch/bin:$PATH"
# session <cwd> [session id]: the hook at session start; stdout lands in $scratch/out.
n=0
session() { n=$((n + 1)); jq -n --arg d "$1" --arg s "${2:-start$n}" '{hook_event_name:"SessionStart",source:"startup",session_id:$s,cwd:$d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_MERGED_BRANCH=${opt:-true} "$hook" >"$scratch/out" 2>"$scratch/err"; }
# first <cwd> <command> [session id]: the hook before a Bash command.
first() { jq -n --arg d "$1" --arg c "$2" --arg s "${3:-s1}" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:$s,cwd:$d,tool_input:{command:$c}}' |
  CLAUDE_PLUGIN_OPTION_GUARD_MERGED_BRANCH=${opt:-true} "$hook" >"$scratch/out" 2>"$scratch/err"; }
told() { jq -e --arg w "$1" '.hookSpecificOutput.additionalContext | contains($w)' "$scratch/out" >/dev/null 2>&1; }
silent() { [ ! -s "$scratch/out" ]; }

# A remote whose forge is GitHub by its URL, and a clone on topic, pushed.
rem="$scratch/rem"; seed="$scratch/seed"; w="$scratch/work"
git init -q --bare -b main "$rem"
git clone -q "$rem" "$seed" 2>/dev/null; gi "$seed" commit -q --allow-empty -m one; gi "$seed" push -q origin main
git clone -q "$rem" "$w" 2>/dev/null
gi "$w" config remote.origin.url https://github.com/owner/repo
gi "$w" config url."$rem".insteadOf https://github.com/owner/repo
gi "$w" checkout -q -b topic; echo a > "$w/a"; gi "$w" add a; gi "$w" commit -q -m topic-a
gi "$w" push -q -u origin topic 2>/dev/null

session "$w"; code=$?
check "a live branch at session start: nothing is said" '[ $code = 0 ] && silent'

# Squash-merge topic and delete its remote branch, as the forge does.
gi "$seed" fetch -q origin topic; gi "$seed" merge -q --squash FETCH_HEAD >/dev/null
gi "$seed" commit -q -m "topic (#1)"; gi "$seed" push -q origin main; gi "$seed" push -q origin --delete topic 2>/dev/null

session "$w"; code=$?
check "the snag: a session starts on a merged branch while its open pull request has another head, and the agent is told both" \
  '[ $code = 0 ] && told "topic" && told "merged" && told "warp/next-effort" && told "git switch warp/next-effort"'
check "the hint is a SessionStart hint" 'jq -e ".hookSpecificOutput.hookEventName == \"SessionStart\"" "$scratch/out" >/dev/null'
check "the hint gives the fresh-branch move too" 'told "git fetch --prune && git switch -c <new-branch> origin/main"'
check "on GitHub gh answers, not tea" '! told "tea-only"'
check "the hint says nothing needs moving after a squash" 'told "nothing needs moving"'
printf 'warp/next-effort\nwarp/next-effort\n\nwarp/other\ntopic\n' > "$HEADS"
session "$w"
check "two open heads are each named once, and the merged branch is not" 'told "heads: warp/next-effort, warp/other. " && ! told "topic,"'
: > "$HEADS"
session "$w"
check "no open pull request: the hint says so" 'told "No pull request of yours is open here"'
printf 'warp/next-effort\n' > "$HEADS"
PATH="${PATH#"$scratch/bin:"}" session "$w"
check "with no gh the hint says how to look, and claims no answer" 'told "gh pr list --author @me --state open" && ! told "No pull request"'

# The first command in a checkout, once per session.
first "$w" 'ls'; code=$?
check "the first command in a merged checkout tells the agent, and the command runs" '[ $code = 0 ] && told "warp/next-effort" && jq -e ".hookSpecificOutput.hookEventName == \"PreToolUse\"" "$scratch/out" >/dev/null'
first "$w" 'ls'
check "the second command in it is not told again" 'silent'
first "$w" 'ls' s2
check "another session's first command is told" 'told "warp/next-effort"'
session "$w" s3; first "$w" 'ls' s3
check "a session told at start is not told again on its first command" 'silent'
first "$scratch" "cd $w && ls" s20
check "a first command that cds into a merged checkout from elsewhere is told" 'told "warp/next-effort"'
first "$scratch" "git -C $w status" s21
check "a first git -C at a merged checkout from elsewhere is told" 'told "warp/next-effort"'

# The commit and push refusal names the open heads too.
first "$w" 'git commit -m x' s4; code=$?
check "a commit on the merged branch is refused and names the open head" '[ $code = 2 ] && grep -q "warp/next-effort" "$scratch/err"'

# Gitea: tea lists the user's own open pull requests.
gi "$w" config remote.origin.url https://forge.example/owner/repo
gi "$w" config --unset url."$rem".insteadOf; gi "$w" config url."$rem".insteadOf https://forge.example/owner/repo
printf 'warp/next-effort\n' > "$TEA_HEADS"
session "$w" s5
check "on another forge tea names the user's open heads, not someone else's" 'told "warp/next-effort" && ! told "someone-elses"'

# A master default with no recorded origin/HEAD is found by its name.
gi "$seed" push -q origin main:master 2>/dev/null; gi "$w" fetch -q origin master 2>/dev/null
gi "$w" update-ref -d refs/remotes/origin/main; gi "$w" remote set-head origin -d 2>/dev/null
session "$w" s10
check "a master default is named in the move" 'told "git switch -c <new-branch> origin/master"'
gi "$w" fetch -q origin main

# Passes.
gi "$w" checkout -q --detach
session "$w" s6; code=$?; check "a detached HEAD: nothing is said" '[ $code = 0 ] && silent'
gi "$w" checkout -q -b fresh origin/main
session "$w" s6; check "a branch never pushed: nothing is said" 'silent'
gi "$w" checkout -q topic
opt=false session "$w" s7; check "option off: nothing is said" 'silent'
opt=false first "$w" 'ls' s7; check "option off: the first command hears nothing" 'silent'
session "$scratch" s8; check "outside a repository: nothing is said" 'silent'
echo 'not json' | CLAUDE_PLUGIN_OPTION_GUARD_MERGED_BRANCH=true "$hook" >"$scratch/out" 2>&1; code=$?
check "bad input passes" '[ $code = 0 ]'
exit $fail
