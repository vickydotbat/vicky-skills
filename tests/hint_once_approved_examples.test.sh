#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for the hook audit, E11.
# A hint fires once, and only on what it is about.
set -u
scripts="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a session on an older plugin copy
# When the user sends a second prompt
# Then stale-copy-hint says nothing more
mkdir -p "$dir/cfg/plugins" "$dir/cache/old" "$dir/cache/new" "$dir/data"
jq -n --arg n "$dir/cache/new" '{plugins:{"vicky-skills@vicky-skills":[{installPath:$n,lastUpdated:"2026-11-06"}]}}' > "$dir/cfg/plugins/installed_plugins.json"
stale() { echo '{"session_id":"s1","prompt":"hi"}' | CLAUDE_CONFIG_DIR="$dir/cfg" CLAUDE_PLUGIN_ROOT="$dir/cache/old" CLAUDE_PLUGIN_DATA="$dir/data" bash "$scripts/stale-copy-hint.sh"; }
first=$(stale); second=$(stale)
check "E11 stale-copy-hint speaks on the first prompt only" '[ -n "$first" ] && [ -z "$second" ]'

# Given a skill expansion or a message from another session that holds the word lesson
# When lesson-hint sees it
# Then it says nothing
lesson() { jq -nc --arg p "$1" '{prompt:$p}' | CLAUDE_PLUGIN_OPTION_LESSON_HINT=true bash "$scripts/lesson-hint.sh"; }
check "E11 a skill expansion holding lesson is quiet" \
  '[ -z "$(lesson "<command-message>vicky-skills:robot-voice</command-message>
Write the lessons down")" ] && [ -z "$(lesson "Base directory for this skill: x
lessons")" ]'
check "E11 a message from another session holding lesson is quiet" \
  '[ -z "$(lesson "Another Claude session sent a message: engrave the lesson")" ]'
check "E11 the user typing lesson still gets the hint" '[ -n "$(lesson "codify this lesson")" ]'

# Given a push from a branch with no open pull request
# When after-push runs
# Then it says nothing
mkdir "$dir/bin"; printf '#!/bin/sh\nexit 1\n' > "$dir/bin/gh"; printf '#!/bin/sh\nexit 1\n' > "$dir/bin/tea"; chmod +x "$dir/bin/"*
git init -q -b feat "$dir/r"; git -C "$dir/r" remote add origin https://github.com/o/r.git
check "E11 a push with no open pull request is quiet" \
  '[ -z "$(jq -nc --arg d "$dir/r" "{tool_input:{command:\"git push -u origin feat\"},cwd:\$d}" | PATH="$dir/bin:$PATH" bash "$scripts/after-push.sh")" ]'
exit $fail
