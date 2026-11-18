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

# An Esc interrupt fires no hook: the owner lives on, but an idle mark drops out.
sleep 30 & idler=$!
KEEP_AWAKE_IDLE=1 KEEP_AWAKE_OWNER=$idler send UserPromptSubmit idle
held; touch -d '-2 min' "$fx/state/idle"
check "a mark idle past the cap releases the lock while its owner lives" 'free && [ ! -e "$fx/state/idle" ] && kill -0 $idler'
KEEP_AWAKE_IDLE=soon KEEP_AWAKE_OWNER=$idler send UserPromptSubmit idle
held; touch -d '-31 min' "$fx/state/idle"
check "a cap that is not a number means 30 minutes" 'free'
KEEP_AWAKE_OWNER=$idler send UserPromptSubmit fresh
check "a fresh mark under the cap keeps the lock" 'held && sleep 0.4 && [ -f "$fx/lock" ]'
rm -f "$fx/state/fresh"; free; kill $idler; wait $idler 2>/dev/null

# A subagent is an agent at work: it holds the lock past its session's turn end.
sub() { jq -nc --arg e "$1" --arg s "$2" --arg a "$3" '{hook_event_name:$e,session_id:$s,agent_id:$a}' | PATH="$fx/bin:$PATH" bash "$hook"; }
sleep 30 & sess=$!; trap 'kill $sess 2>/dev/null; rm -rf "$KEEP_AWAKE_DIR"; sleep 0.3; rm -rf "$fx"' EXIT; export KEEP_AWAKE_OWNER=$sess
send UserPromptSubmit main; sub SubagentStart main bg1; send Stop main
check "a background subagent holds the lock after its session's turn ends" 'held && sleep 0.4 && [ -f "$fx/lock" ] && [ -f "$fx/state/main.bg1" ] && [ ! -e "$fx/state/main" ]'
touch -d '-10 min' "$fx/state/main.bg1"; sub PostToolUse main bg1
check "a subagent's tool call refreshes its own mark and makes no session mark" '[ -n "$(find "$fx/state/main.bg1" -mmin -1)" ] && [ ! -e "$fx/state/main" ]'
sub SubagentStop main bg1
check "the subagent's stop releases the lock" 'free && [ ! -e "$fx/state/main.bg1" ]'
send UserPromptSubmit main; sub SubagentStart main fg1; sub SubagentStop main fg1
check "a subagent's stop leaves its session's turn holding" 'sleep 0.4 && [ -f "$fx/lock" ] && [ -f "$fx/state/main" ]'
sub SubagentStart main bg2; send SessionEnd main
check "closing the session releases its subagents too" 'free && [ -z "$(ls -A "$fx/state")" ]'
sub SubagentStart main .x; c1=$?; sub SubagentStart main a/b; c2=$?
check "a bad agent id marks nothing and exits 0" '[ -z "$(ls -A "$fx/state")" ] && [ $c1 = 0 ] && [ $c2 = 0 ]'
kill $sess; wait $sess 2>/dev/null; unset KEEP_AWAKE_OWNER

# A stand-in named claude runs the hook through a shell, the way Claude Code does.
cp "$(command -v bash)" "$fx/claude"
jq -nc '{hook_event_name:"UserPromptSubmit",session_id:"walk"}' > "$fx/in"
"$fx/claude" -c 'echo $$ > "'"$fx/pid"'"; PATH="'"$fx/bin"':$PATH" sh -c "bash \"'"$hook"'\"; true" < "'"$fx/in"'"; true'
check "the mark names the claude process above the hook" '[ "$(cat "$fx/state/walk" 2>/dev/null)" = "$(cat "$fx/pid")" ]'
free
exit $fail
