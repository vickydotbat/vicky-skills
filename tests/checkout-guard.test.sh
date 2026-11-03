#!/usr/bin/env bash
# The checkout guard's decisions the approved examples leave out: a session
# switching its own checkout, "git checkout -", a checkout of a path, and
# which git subcommands count as history writes.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/checkout-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"; data="$dir/data"
git init -q -b warp-b "$repo"
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
git -C "$repo" branch fix-x; printf 'readme\n' > "$repo/README.md"
fail=0
hook() { # session event command -> exit code; OWNER sets the session's process
  jq -n --arg s "$1" --arg e "$2" --arg c "$3" --arg d "$repo" \
    '{session_id: $s, hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
    CHECKOUT_GUARD_OWNER_PID=${OWNER:-} CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true CLAUDE_PLUGIN_DATA="$data" bash "$guard" >/dev/null 2>&1
}
expect() { # name want session command
  hook "$3" PreToolUse "$4"; got=$?
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: exit $got, want $2"; fail=1; fi
}
hook A PostToolUse "git commit -m x"
expect "a session switching a checkout only it works in runs" 0 A "git switch fix-x"
expect "another session's git checkout - is refused" 2 B "git checkout -"
expect "another session's checkout of a path runs" 0 B "git checkout README.md"
expect "another session's checkout naming a path before a branch runs" 0 B "git checkout README.md fix-x"
expect "another session's switch is refused" 2 B "git switch fix-x"
expect "another session's checkout of a name that is neither a branch nor a path runs" 0 B "git checkout nosuchthing"
expect "another session's git stash list runs" 0 B "git stash list"
expect "another session's git stash show runs" 0 B "git stash show -p"
expect "another session's git log naming a write in its search runs" 0 B "git log --grep reset"
expect "another session's git merge-base runs" 0 B "git merge-base --is-ancestor HEAD fix-x"
expect "another session's bare git stash is refused" 2 B "git stash"
expect "another session's git stash pop is refused" 2 B "git stash pop"
expect "another session's git -C <dir> commit is refused" 2 B "git -C . commit -m x"
expect "another session's git -c <key> rebase is refused" 2 B "git -c core.editor=true rebase fix-x"
expect "another session's commit after a read in one command is refused" 2 B "git status && git commit -m x"
expect "another session's git pull --ff-only is refused" 2 B "git pull --ff-only"
# Only a command that writes history or moves HEAD claims the checkout. A
# read (ls-files, status, log) or a worktree add leaves no record behind.
rm -rf "$data"
for c in "git ls-files" "git status" "git log -1" "git worktree add -b w .claude/worktrees/w origin/main"; do hook R PostToolUse "$c"; done
if [ -e "$data/checkouts/R" ]; then echo "FAIL a session's reads leave no record"; fail=1; else echo "ok   a session's reads leave no record"; fi
expect "another session's commit runs past a session that only read" 0 X "git commit --allow-empty -m x"
for c in "git switch fix-x" "git checkout -b y" "git rebase fix-x" "git reset --hard" "git merge fix-x"; do
  rm -rf "$data"; hook R PostToolUse "$c"
  expect "a session's $c claims the checkout" 2 X "git commit --allow-empty -m x"
done
rm -rf "$data"
hook A PostToolUse "git commit -m x"
# A session closed without SessionEnd (its terminal closed) leaves its record.
# The record names its process, so a record whose process is gone is dropped.
rm -rf "$data"
sleep 300 & gone=$!
OWNER=$gone hook C PostToolUse "git commit -m x"
kill "$gone"; wait "$gone" 2>/dev/null
expect "a closed session's record no longer refuses a commit" 0 D "git commit --allow-empty -m x"
if [ -e "$data/checkouts/C" ]; then echo "FAIL a closed session's record is deleted"; fail=1; else echo "ok   a closed session's record is deleted"; fi
sleep 300 & live=$!
OWNER=$live hook E PostToolUse "git commit -m x"
expect "a live session's record still refuses a commit" 2 F "git commit --allow-empty -m x"
kill "$live"; wait "$live" 2>/dev/null
OWNER=$$ hook G PostToolUse "git commit -m x"
printf '%s 1\n' "$$" > "$data/checkouts/G.pid"
expect "a record whose process id was reused by a newer process no longer refuses" 0 H "git commit --allow-empty -m x"
hook K SessionEnd ""
OWNER=$$ hook K PostToolUse "git commit -m x"; hook K SessionEnd ""
if [ -e "$data/checkouts/K.pid" ]; then echo "FAIL SessionEnd deletes the process record"; fail=1; else echo "ok   SessionEnd deletes the process record"; fi
# With no process given, the guard finds the session's own process: its
# nearest ancestor named claude. Once that process ends, the record goes.
cp "$(command -v bash)" "$dir/claude"
rm -rf "$data"
jq -n --arg d "$repo" '{session_id: "P", hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: "git commit -m x"}, cwd: $d}' > "$dir/p.json"
"$dir/claude" -c "CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true CLAUDE_PLUGIN_DATA='$data' bash '$guard' < '$dir/p.json'"
if [ -s "$data/checkouts/P.pid" ]; then echo "ok   the guard finds the session's process by its name"; else echo "FAIL the guard finds the session's process by its name"; fail=1; fi
expect "the record of a session whose found process ended no longer refuses" 0 Q "git commit --allow-empty -m x"
rm -rf "$data"
"$dir/claude" -c "bash -c \"CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true CLAUDE_PLUGIN_DATA='$data' bash '$guard' < '$dir/p.json'; true\"; true"
read -r found _ < "$data/checkouts/P.pid" 2>/dev/null
if [ -n "${found:-}" ] && [ "$(cat "/proc/$found/comm" 2>/dev/null)" != claude ] && ! kill -0 "$found" 2>/dev/null; then echo "ok   the guard walks past a shell to the process named claude"; else echo "FAIL the guard walks past a shell to the process named claude: found ${found:-nothing}"; fail=1; fi
rm -rf "$data"
OWNER=999999999 hook R PostToolUse "git commit -m x"
if [ -e "$data/checkouts/R.pid" ]; then echo "FAIL a process with no start time writes no process record"; fail=1; else echo "ok   a process with no start time writes no process record"; fi
expect "a record with no process record still refuses" 2 S "git commit --allow-empty -m x"

# The session that came to a checkout first keeps committing there. A
# newcomer that only reads blocks nothing, and its own write is refused.
rm -rf "$data"
hook T PostToolUse "git commit -m x"
sed -i "s/\t[0-9]*\$/\t$(( $(date +%s) - 600 ))/" "$data/checkouts/T.first"
hook U PostToolUse "git log -1"
expect "the first session's commit runs past a newcomer that only read" 0 T "git commit --allow-empty -m x"
expect "the newcomer's commit is refused" 2 U "git commit --allow-empty -m x"
expect "the first session's branch switch runs past a newcomer that only read" 0 T "git switch fix-x"
expect "the newcomer's worktree on a branch of its own runs" 0 U "git worktree add -b inv-1 .claude/worktrees/inv-1 HEAD"
hook U4 PostToolUse "git commit -m x"
expect "the first session's commit runs past a newcomer that also committed" 0 T "git commit --allow-empty -m x"
expect "that newcomer's own commit is refused" 2 U4 "git commit --allow-empty -m x"
hook U2 PostToolUse "git commit -m x"
expect "the first session's branch switch is still refused" 2 T "git switch fix-x"
cp "$data/checkouts/U2.first" "$data/checkouts/U3.first"; cp "$data/checkouts/U2" "$data/checkouts/U3"
expect "of two sessions that came in the same second, a commit is refused" 2 U2 "git commit --allow-empty -m x"
rm -f "$data/checkouts/U.first" "$data/checkouts/U2.first" "$data/checkouts/U3.first"
expect "a record from before first times were kept still refuses the first session" 2 T "git commit --allow-empty -m x"
hook T SessionEnd ""
if [ -e "$data/checkouts/T.first" ]; then echo "FAIL SessionEnd deletes the first-time record"; fail=1; else echo "ok   SessionEnd deletes the first-time record"; fi

# A payload with no session id writes no record.
rm -rf "$data"; hook "" PostToolUse "git commit -m x"
if [ -n "$(ls -A "$data/checkouts" 2>/dev/null)" ]; then echo "FAIL a commit with no session id writes no record"; fail=1; else echo "ok   a commit with no session id writes no record"; fi

# A session that starts conn hands the checkout on until its user speaks again.
prompt() { # session prompt; the hook exits 0 and prints nothing
  out=$(jq -n --arg s "$1" --arg p "$2" --arg d "$repo" '{session_id: $s, hook_event_name: "UserPromptSubmit", prompt: $p, cwd: $d}' |
    CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true CLAUDE_PLUGIN_DATA="$data" bash "$guard" 2>&1); got=$?
  [ "$got$out" = 0 ] || { echo "FAIL a prompt to the guard exits 0 quietly: exit $got, said: $out"; fail=1; }
}
rm -rf "$data"
hook L PostToolUse "git commit -m x"
prompt L "/vicky-skills:conn finish the colour panel"
hook L PostToolUse "git push"
expect "a session that started conn no longer refuses the next session's commit" 0 M "git commit --allow-empty -m x"
prompt L "/conn"
expect "a bare /conn hands off too" 0 M "git commit --allow-empty -m x"
prompt L "one more thing before you go"
expect "the user's next prompt to the handed-off session takes the checkout back" 2 M "git commit --allow-empty -m x"
prompt L "please run conn now"
expect "a prompt that only mentions conn keeps the claim" 2 M "git commit --allow-empty -m x"
prompt L "/connect the dots"
expect "a command that only starts with conn keeps the claim" 2 M "git commit --allow-empty -m x"
rm -rf "$data"; sleep 300 & ended=$!
OWNER=$ended hook V PostToolUse "git commit -m x"; prompt V "/conn"
kill "$ended"; wait "$ended" 2>/dev/null
hook W PreToolUse "git commit --allow-empty -m x"
if ls "$data/checkouts/V"* >/dev/null 2>&1; then echo "FAIL a handed-off session whose process ended leaves no files"; fail=1; else echo "ok   a handed-off session whose process ended leaves no files"; fi
prompt L "/conn"; hook L SessionEnd ""
if [ -e "$data/checkouts/L.handoff" ]; then echo "FAIL SessionEnd deletes the handoff mark"; fail=1; else echo "ok   SessionEnd deletes the handoff mark"; fi
# A trunk repo (AGENTS.md says "Trunk: on") takes every commit on main, so two
# sessions committing there is the way of working. A switch still moves files.
rm -rf "$data"; git -C "$repo" switch -q -c main
printf 'Trunk: on\n' > "$repo/AGENTS.md"
hook T PostToolUse "git commit -m x"
expect "in a trunk repo, another session's commit on main runs" 0 U "git commit --allow-empty -m x"
expect "in a trunk repo, another session's switch is still refused" 2 U "git switch fix-x"
rm -f "$repo/AGENTS.md"
expect "with no trunk line, another session's commit on main is refused" 2 U "git commit --allow-empty -m x"
git -C "$repo" switch -q warp-b
# The refusal names the session that holds the checkout, so the agent can check it.
rm -rf "$data"; hook HOLDER1 PostToolUse "git commit -m x"
msg=$(jq -n --arg d "$repo" '{session_id: "Y", hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: "git commit -m y"}, cwd: $d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true CLAUDE_PLUGIN_DATA="$data" bash "$guard" 2>&1 >/dev/null)
if grep -q 'session HOLDER1' <<<"$msg"; then echo "ok   the refusal names the holding session"; else echo "FAIL the refusal names the holding session: $msg"; fail=1; fi
exit $fail
