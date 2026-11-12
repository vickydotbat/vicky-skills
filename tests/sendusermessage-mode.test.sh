#!/usr/bin/env bash
# SendUserMessage is a whole mode: in brief mode every word the user reads
# arrives as a SendUserMessage tool call, never as chat text. A hook that
# reads the agent's words must read those messages too, and its test must send
# a case that way. This test finds each registered hook script that reads the
# agent's text (it sources stop-reply.sh, or reads a "text" block) and checks
# both halves.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
readers=0
for name in $(grep -oE 'scripts/[a-z0-9-]+\.sh' "$root/plugins/vicky-skills/hooks/hooks.json" | sed 's#scripts/##; s#\.sh$##' | sort -u); do
  f="$scripts/$name.sh"; [ -f "$f" ] || continue
  grep -qE 'stop-reply\.sh|"text"' "$f" || continue
  readers=$((readers + 1))
  check "$name reads SendUserMessage bodies" 'grep -qE "stop-reply\.sh|SendUserMessage" "$f"'
  check "$name has a test that sends a case through SendUserMessage" '[ -f "$root/tests/$name.test.sh" ] && grep -q SendUserMessage "$root/tests/$name.test.sh"'
done
check "the scan found the hooks that read the agent's words" '[ "$readers" -ge 2 ]'
exit $fail
