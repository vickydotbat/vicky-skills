#!/usr/bin/env bash
# keep-awake: the input the approved examples don't reach. Bad input, a
# missing tool and an unrelated event mark nothing and take no lock.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/keep-awake.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
mkdir -p "$fx/bin" "$fx/nojq"
printf '#!/bin/sh\necho called >> "%s/calls"\n' "$fx" > "$fx/bin/systemd-inhibit"; chmod +x "$fx/bin/systemd-inhibit"
for t in jq flock setsid ls sleep sh mkdir touch rm id cat; do ln -s "$(command -v $t)" "$fx/nojq/$t"; done
ln -s "$fx/bin/systemd-inhibit" "$fx/nojq/systemd-inhibit"
export CLAUDE_PLUGIN_OPTION_KEEP_AWAKE=1 KEEP_AWAKE_DIR="$fx/state" KEEP_AWAKE_POLL=0.1
run() { printf '%s' "$1" | PATH="${2:-$fx/bin:$PATH}" "$BASH" "$hook" || echo "$1" >> "$fx/nonzero"; }
calls() { sleep 0.3; [ -f "$fx/calls" ] && wc -l < "$fx/calls" || echo 0; }

run '{"hook_event_name":"UserPromptSubmit"}'
check "no session id marks nothing" '[ ! -d "$fx/state" ] && [ "$(calls)" = 0 ]'
run '{"hook_event_name":"UserPromptSubmit","session_id":"a/b"}'
check "a session id with a slash marks nothing" '[ ! -d "$fx/state" ]'
run '{"hook_event_name":"UserPromptSubmit","session_id":".hidden"}'
check "a dot session id marks nothing" '[ ! -d "$fx/state" ]'
run 'not json'
check "bad json marks nothing" '[ ! -d "$fx/state" ] && [ "$(calls)" = 0 ]'
run '{"hook_event_name":"PreToolUse","session_id":"s"}'
check "another event marks nothing" '[ ! -d "$fx/state" ]'
rm "$fx/nojq/jq"
run '{"hook_event_name":"UserPromptSubmit","session_id":"s"}' "$fx/nojq"
check "no jq marks nothing" '[ ! -d "$fx/state" ] && [ "$(calls)" = 0 ]'
ln -s "$(command -v jq)" "$fx/nojq/jq"; rm "$fx/nojq/systemd-inhibit"
run '{"hook_event_name":"UserPromptSubmit","session_id":"s"}' "$fx/nojq"
check "no systemd-inhibit marks nothing" '[ ! -d "$fx/state" ]'
ln -s "$fx/bin/systemd-inhibit" "$fx/nojq/systemd-inhibit"; rm "$fx/nojq/flock"
run '{"hook_event_name":"UserPromptSubmit","session_id":"s"}' "$fx/nojq"
check "no flock marks nothing" '[ ! -d "$fx/state" ]'
run '{"hook_event_name":"UserPromptSubmit","session_id":"s"}'
check "a good prompt marks its session" '[ -f "$fx/state/s" ] && [ "$(calls)" = 1 ]'
CLAUDE_PLUGIN_OPTION_KEEP_AWAKE=0 run '{"hook_event_name":"Stop","session_id":"s"}'
check "the setting at 0 does nothing" '[ -f "$fx/state/s" ]'
run '{"hook_event_name":"Stop","session_id":"s"}'
check "Stop clears the mark" '[ ! -e "$fx/state/s" ]'
touch "$fx/afile"
KEEP_AWAKE_DIR="$fx/afile/state" run '{"hook_event_name":"UserPromptSubmit","session_id":"s"}' 2>/dev/null
check "an unwritable state folder takes no lock" '[ "$(calls)" = 1 ]'
check "every run exits 0" '[ ! -f "$fx/nonzero" ]'
exit $fail
