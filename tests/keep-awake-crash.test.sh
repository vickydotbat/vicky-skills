#!/usr/bin/env bash
# keep-awake: a session that dies without Stop or SessionEnd drops out, so
# its mark can't hold the sleep lock forever. Also checks the mark finds the
# Claude Code process above the hook.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/keep-awake.sh"
fx=$(mktemp -d); fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
mkdir -p "$fx/bin"
cat > "$fx/bin/systemd-inhibit" <<'STUB'
#!/usr/bin/env bash
while [ "${1#--}" != "$1" ]; do shift; done
echo held > "$KEEP_AWAKE_TEST_LOCK"; "$@"; rm -f "$KEEP_AWAKE_TEST_LOCK"
STUB
chmod +x "$fx/bin/systemd-inhibit"
export KEEP_AWAKE_TEST_LOCK="$fx/lock" KEEP_AWAKE_DIR="$fx/state" KEEP_AWAKE_POLL=0.1 CLAUDE_PLUGIN_OPTION_KEEP_AWAKE=1
trap 'rm -rf "$KEEP_AWAKE_DIR"; sleep 0.3; rm -rf "$fx"' EXIT
send() { jq -nc --arg e "$1" --arg s "$2" '{hook_event_name:$e,session_id:$s}' | PATH="$fx/bin:$PATH" bash "$hook"; }
held() { for _ in $(seq 30); do [ -f "$fx/lock" ] && return 0; sleep 0.1; done; return 1; }
free() { for _ in $(seq 30); do [ -f "$fx/lock" ] || return 0; sleep 0.1; done; return 1; }

sleep 30 & alive=$!
KEEP_AWAKE_OWNER=$alive send UserPromptSubmit live
check "a live owner holds the lock" 'held && sleep 0.4 && [ -f "$fx/lock" ] && [ "$(cat "$fx/state/live")" = "$alive" ]'
kill $alive; wait $alive 2>/dev/null
check "the owner's death releases it with no Stop" 'free && [ ! -e "$fx/state/live" ]'

# A stand-in named claude runs the hook through a shell, the way Claude Code does.
cp "$(command -v bash)" "$fx/claude"
jq -nc '{hook_event_name:"UserPromptSubmit",session_id:"walk"}' > "$fx/in"
"$fx/claude" -c 'echo $$ > "'"$fx/pid"'"; PATH="'"$fx/bin"':$PATH" sh -c "bash \"'"$hook"'\"; true" < "'"$fx/in"'"; true'
check "the mark names the claude process above the hook" '[ "$(cat "$fx/state/walk" 2>/dev/null)" = "$(cat "$fx/pid")" ]'
free
exit $fail
