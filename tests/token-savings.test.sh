#!/usr/bin/env bash
# The examples Vicky approved on 2026-11-02 for the token-savings changes.
# Each behaviour already held when they were approved, so these are plain
# regression tests, not approved-spec ones: an approved test must go red
# where it lands. The hooks run as a session runs them.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a message from another of your sessions that says for the future
# When it reaches this session
# Then the agent is not sent to engrave
peer='<cross-session-message from="uds:/s.sock" from-name="peer">for the future, codify this</cross-session-message>'
mine='for the future, codify this'
hint() { jq -nc --arg p "$1" '{prompt:$p}' | CLAUDE_PLUGIN_OPTION_LESSON_HINT=true bash "$plugin/scripts/lesson-hint.sh"; }
check "a peer session's message teaches no lesson" \
  '[ -z "$(hint "$peer")" ] && hint "$mine" | grep -q engrave'

exit $fail
