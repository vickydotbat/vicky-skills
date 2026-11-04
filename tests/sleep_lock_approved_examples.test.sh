#!/usr/bin/env bash
# approved-spec: the keep-awake examples, approved 2026-11-04. The hook runs
# on events shaped the way Claude Code sends them, with a stand-in
# systemd-inhibit on PATH that marks a lock file while it holds the lock.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
hook="$root/scripts/keep-awake.sh"
fx=$(mktemp -d)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
mkdir -p "$fx/bin"
cat > "$fx/bin/systemd-inhibit" <<'STUB'
#!/usr/bin/env bash
while [ "${1#--}" != "$1" ]; do shift; done
echo held > "$KEEP_AWAKE_TEST_LOCK"
"$@"
rm -f "$KEEP_AWAKE_TEST_LOCK"
STUB
chmod +x "$fx/bin/systemd-inhibit"
export KEEP_AWAKE_TEST_LOCK="$fx/lock" KEEP_AWAKE_DIR="$fx/state" KEEP_AWAKE_POLL=0.1
export KEEP_AWAKE_OWNER=$$ CLAUDE_PLUGIN_OPTION_KEEP_AWAKE=true
trap 'rm -rf "$KEEP_AWAKE_DIR"; sleep 0.3; rm -rf "$fx"' EXIT
send() { jq -nc --arg e "$1" --arg s "$2" '{hook_event_name:$e,session_id:$s}' | PATH="$fx/bin:$PATH" bash "$hook"; }
held() { for _ in $(seq 30); do [ -f "$fx/lock" ] && return 0; sleep 0.1; done; return 1; }
free() { for _ in $(seq 30); do [ -f "$fx/lock" ] || return 0; sleep 0.1; done; return 1; }

# Given the keep-awake setting is on
# When you send a prompt
# Then systemd-inhibit --list shows a sleep lock held by Claude Code
check "a prompt takes the sleep lock" '[ -f "$hook" ] && send UserPromptSubmit a && held'

# Given the keep-awake setting is on and one session is working
# When its turn ends
# Then systemd-inhibit --list shows no Claude Code sleep lock
check "the turn's end releases it" '[ -f "$hook" ] && send Stop a && free'

# Given two sessions are working
# When the first one's turn ends
# Then the sleep lock stays until the second one's turn ends too
check "two sessions share one lock" '[ -f "$hook" ] && send UserPromptSubmit a && send UserPromptSubmit b && held && send Stop a && sleep 0.5 && [ -f "$fx/lock" ] && send Stop b && free'

# Given a turn ends while a background watch still runs
# When you look at systemd-inhibit --list
# Then it shows no Claude Code sleep lock
( sleep 5 ) & watch=$!
check "a background watch does not hold it" '[ -f "$hook" ] && send UserPromptSubmit a && held && send Stop a && free'
kill $watch 2>/dev/null

# Given the keep-awake setting is off, as it is by default
# When you send a prompt
# Then no sleep lock is taken
check "the setting off takes no lock" '[ -f "$hook" ] && CLAUDE_PLUGIN_OPTION_KEEP_AWAKE= send UserPromptSubmit c && sleep 0.5 && [ ! -f "$fx/lock" ] && [ ! -e "$KEEP_AWAKE_DIR/c" ]'

# Given the keep-awake setting is on and systemd-inhibit is not installed
# When you send a prompt
# Then the prompt runs as usual with no error shown
out=$(jq -nc '{hook_event_name:"UserPromptSubmit",session_id:"d"}' | PATH="/nonexistent" "$BASH" "$hook" 2>&1); code=$?
check "no systemd-inhibit shows no error" '[ -f "$hook" ] && [ $code = 0 ] && [ -z "$out" ]'
rm -f "$KEEP_AWAKE_DIR/d"

# Given a session is working
# When you close that session mid-turn
# Then its share of the sleep lock is released
check "closing a session releases it" '[ -f "$hook" ] && send UserPromptSubmit e && held && send SessionEnd e && free'

# Given you press Esc to stop a turn
# When no other session is working
# Then the sleep lock stays until that session's next turn ends or the session closes
check "an interrupted turn keeps it until the next end" '[ -f "$hook" ] && send UserPromptSubmit f && held && sleep 0.5 && [ -f "$fx/lock" ] && send UserPromptSubmit f && send Stop f && free'

exit $fail
