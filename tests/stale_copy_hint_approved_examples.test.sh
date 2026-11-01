#!/usr/bin/env bash
# approved-spec: the examples the user set on 2026-11-01 for the stale-copy
# hint: a session that keeps running an older vicky-skills copy after the
# plugin updated is told so once, with both commits, and that a restart helps.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hint="$root/plugins/vicky-skills/scripts/stale-copy-hint.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/config/plugins" "$dir/data"
cache="$dir/config/plugins/cache/vicky-skills/vicky-skills"
cat >"$dir/config/plugins/installed_plugins.json" <<EOF
{"version": 2, "plugins": {"vicky-skills@vicky-skills": [
  {"scope": "user", "installPath": "$cache/700a045ccf50", "version": "700a045ccf50", "gitCommitSha": "700a045ccf501ac1abcaa249eb26b4b401f1d6cc", "lastUpdated": "2026-11-01T07:38:53.460Z"}
]}}
EOF
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
say() { # say <session's copy> <session id>: what the agent is told when the user sends a message
  jq -n --arg s "$2" '{session_id: $s, prompt: "hello"}' \
    | CLAUDE_PLUGIN_ROOT="$cache/$1" CLAUDE_CONFIG_DIR="$dir/config" CLAUDE_PLUGIN_DATA="$dir/data" bash "$hint" \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

# Given a session that started on one vicky-skills copy, and the plugin since updated to a newer one
# When the user sends a message
# Then the agent is told the session runs an older vicky-skills, both commits by short hash, and that a restart picks up the new one
told=$(say d1e400e24377 one)
check "S1 a session on an older copy is told so, with both short hashes and that a restart picks up the new one" \
  'grep -q "older vicky-skills" <<<"$told" && grep -q "d1e400e" <<<"$told" && grep -q "700a045" <<<"$told" && grep -qi "restart" <<<"$told"'

# Given a session running the copy the plugin has installed
# When the user sends a message
# Then the agent is told nothing
current=$(say 700a045ccf50 two)
check "S2 a session running the installed copy is told nothing" '[ -z "$current" ]'

# Given a session already told it runs an older copy
# When the user sends another message
# Then the agent is told nothing more
again=$(say d1e400e24377 one)
other=$(say d1e400e24377 three)
check "S3 the hint comes once a session, and another stale session still gets its own" '[ -z "$again" ] && [ -n "$other" ]'
exit $fail
