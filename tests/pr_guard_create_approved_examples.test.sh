#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for the hook audit, E6.
# pr-guard judges a pull request when one is created, and leaves AI credit
# in commits to git-guard.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pr-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
git init -q -b feat "$dir/r"; git -C "$dir/r" remote add origin https://example.invalid/o/r.git
mkdir -p "$dir/data/pr-guard-sessions" "$dir/bin"
echo feat > "$dir/data/pr-guard-sessions/s1"
# The forge lists this branch's pull request as open.
printf '#!/bin/sh\necho feat\n' > "$dir/bin/gh"; chmod +x "$dir/bin/gh"
run() { jq -nc --arg c "$1" --arg d "$dir/r" '{tool_input:{command:$c},cwd:$d,session_id:"s1",hook_event_name:"PreToolUse"}' |
  env PATH="$dir/bin:$PATH" CLAUDE_PLUGIN_DATA="$dir/data" bash "$guard" >/dev/null 2>&1; echo $?; }

# Given a branch whose own pull request is open
# When the agent runs any command other than pr create
# Then pr-guard lets it through
check "E6 a command other than pr create goes through" \
  '[ "$(run "gh pr view 5 --comments")" = 0 ] && [ "$(run "gh pr merge 5 --squash")" = 0 ] && [ "$(run "cd /tmp && gh pr checks 5")" = 0 ]'

# Given a commit message holding Co-Authored-By
# When pr-guard sees the commit
# Then it says nothing, since git-guard owns AI credit
check "E6 a commit with Co-Authored-By is left to git-guard" \
  '[ "$(run "git commit -m \"x

Co-Authored-By: Claude <noreply@anthropic.com>\" && gh pr view 5")" = 0 ]'
exit $fail
