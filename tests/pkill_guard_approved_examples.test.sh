#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for the hook audit, E7.
# Memory is capped by the OS around Claude Code, so a heavy command runs as
# typed. pkill -f still kills the shell that runs it, so it stays refused.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pkill-guard.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { jq -nc --arg c "$1" '{tool_input:{command:$c}}' | bash "$guard" 2>"${2:-/dev/null}" >/dev/null; echo $?; }

# Given an image or build command with no systemd-run cap
# When the agent runs it
# Then it runs, since Claude Code's own scope caps its memory
check "E7 an uncapped heavy command runs" \
  '[ -f "$guard" ] && [ "$(run "nix shell nixpkgs#ffmpeg -c ffprobe a.mp4")" = 0 ] && [ "$(run "blender -b x.blend -P r.py")" = 0 ]'

# Given pkill -f <pattern>
# When the agent runs it
# Then it is refused with a steer to kill by the saved process id
err=$(mktemp)
check "E7 pkill -f is refused with a pid steer" \
  '[ "$(run "pkill -f mutate-hooks" "$err")" = 2 ] && grep -q "process id" "$err"'
rm -f "$err"
exit $fail
