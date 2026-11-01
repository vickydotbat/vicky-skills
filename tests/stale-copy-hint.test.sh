#!/usr/bin/env bash
# The stale-copy hint's decisions beyond the approved examples: it stays
# silent when it can't tell, and it ignores other plugins' installs.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hint="$root/plugins/vicky-skills/scripts/stale-copy-hint.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/config/plugins" "$dir/data"
cache="$dir/config/plugins/cache/vicky-skills/vicky-skills"
cat >"$dir/config/plugins/installed_plugins.json" <<EOF
{"plugins": {"other@other": [{"installPath": "$dir/config/plugins/cache/other/other/aaaa", "lastUpdated": "2026-11-02T00:00:00Z"}],
 "vicky-skills@vicky-skills": [
  {"installPath": "$cache/old0000000000", "lastUpdated": "2026-10-01T00:00:00Z"},
  {"installPath": "$cache/new1111111111", "lastUpdated": "2026-11-01T00:00:00Z"}]}}
EOF
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
say() { # say <copy> <session id> [extra env...]
  local copy=$1 id=$2; shift 2
  jq -n --arg s "$id" '{session_id: $s}' \
    | env CLAUDE_PLUGIN_ROOT="$cache/$copy" CLAUDE_CONFIG_DIR="$dir/config" CLAUDE_PLUGIN_DATA="$dir/data" "$@" bash "$hint" \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
check "names the newest install of this plugin, not another plugin's" yes "$(say stale222222222 a | grep -q '(new1111)' && echo yes)"
check "a session on an older install that is still listed is current" "" "$(say old0000000000 b)"
quiet() { # quiet <copy> <session id> [extra env...]: the hook's exit code and every byte it wrote
  local copy=$1 id=$2; shift 2
  out=$(jq -n --arg s "$id" '{session_id: $s}' \
    | env CLAUDE_PLUGIN_ROOT="$cache/$copy" CLAUDE_CONFIG_DIR="$dir/config" CLAUDE_PLUGIN_DATA="$dir/data" "$@" bash "$hint" 2>&1)
  echo "exit $? [$out]"
}
check "silent and exit 0 with no session id" "exit 0 []" "$(quiet stale222222222 '')"
check "silent and exit 0 with no data folder" "exit 0 []" "$(quiet stale222222222 c CLAUDE_PLUGIN_DATA=)"
check "silent and exit 0 with no plugin root" "exit 0 []" "$(quiet stale222222222 d CLAUDE_PLUGIN_ROOT=)"
check "silent and exit 0 with no installed list" "exit 0 []" "$(quiet stale222222222 e CLAUDE_CONFIG_DIR="$dir/none")"
check "silent and exit 0 on the installed copy" "exit 0 []" "$(quiet new1111111111 f)"
quiet stale222222222 g >/dev/null
check "silent and exit 0 once a session was told" "exit 0 []" "$(quiet stale222222222 g)"
exit $fail
