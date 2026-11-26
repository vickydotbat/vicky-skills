#!/usr/bin/env bash
# kit-guard's decisions: a closed over-to-you sitting whose recorded kits are
# still in place blocks the stop, naming kit.sh clean, at most 3 times in a row;
# an open page, kits recorded after the sitting opened, kits already gone, no
# sitting, the setting off, a missing jq and bad input let the stop through.
# shellcheck disable=SC2016,SC2034,SC2181,SC2329 # check() evals its single-quoted condition later, which uses these
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/kit-guard.sh"
fx=$(mktemp -d); trap 'kill "$page" 2>/dev/null; rm -rf "$fx"' EXIT
export TMPDIR="$fx/tmp"
s="$TMPDIR/s1"; mkdir -p "$s"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
stop() { jq -nc '{hook_event_name:"Stop",session_id:"s1",cwd:"/"}' | bash "$hook" 2>/dev/null; }
blocks() { stop | jq -e '.decision == "block"' >/dev/null 2>&1; }
passes() { local out; out=$(stop); [ $? = 0 ] && ! jq -e '.decision == "block"' >/dev/null 2>&1 <<<"$out"; }
now=$(date +%s)
mkdir -p "$fx/scratch/ot12"; echo k >"$fx/scratch/ot12/paper.lua"
printf '%s\t%s\n' "$((now - 60))" "$fx/scratch/ot12" >"$s/over-to-you-kits"
sleep 300 & page=$!

check "no sitting opened lets the stop through" 'passes'
printf '%s %s %s\n' "$page" "$now" "$s/over-to-you-x.md" >"$s/over-to-you-opened"
check "a page still open lets the stop through" 'passes'
kill "$page"; wait "$page" 2>/dev/null
check "a closed sitting with its kit in place blocks the stop" 'blocks'
check "the refusal names the kit and kit.sh clean, and says never to ask" 'out=$(stop); grep -qF "$fx/scratch/ot12" <<<"$out" && grep -q "kit.sh clean" <<<"$out" && grep -q "never ask" <<<"$out" && [ -f "$(jq -r .reason <<<"$out" | grep -o "bash [^ ]*kit\.sh" | cut -c6-)" ]'
blocks
check "the stop after 3 blocks in a row goes through, naming the kit" 'out=$(stop) && ! jq -e ".decision" <<<"$out" >/dev/null 2>&1 && grep -qF "$fx/scratch/ot12" <<<"$out"'
check "the count starts again after the stop that went through" 'blocks'
printf '%s\t%s\n' "$((now + 60))" "$fx/scratch/ot12" >"$s/over-to-you-kits"
check "a kit recorded after the sitting opened, for the next one, lets the stop through" 'passes'
printf '%s\t%s\n' "$((now - 60))" "$fx/scratch/ot12" >"$s/over-to-you-kits"
rm -rf "$fx/scratch/ot12"
check "kits already gone let the stop through" 'passes'
check "the count is cleared once the kits are gone" '[ ! -e "$s/kit-guard.count" ]'
mkdir -p "$fx/scratch/ot12"
check "the setting off lets the stop through" 'out=$(jq -nc "{session_id:\"s1\"}" | CLAUDE_PLUGIN_OPTION_GUARD_KIT_CLEANUP=false bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "the setting at 0 lets the stop through" 'out=$(jq -nc "{session_id:\"s1\"}" | CLAUDE_PLUGIN_OPTION_GUARD_KIT_CLEANUP=0 bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "the setting on blocks" 'jq -nc "{session_id:\"s1\"}" | CLAUDE_PLUGIN_OPTION_GUARD_KIT_CLEANUP=true bash "$hook" | jq -e ".decision == \"block\"" >/dev/null'
nojq="$fx/nojq"; mkdir -p "$nojq"
for t in bash cat; do ln -s "$(command -v "$t")" "$nojq/$t"; done
check "a missing jq lets the stop through" 'out=$(echo "{\"session_id\":\"s1\"}" | PATH="$nojq" bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "bad input lets the stop through" 'out=$(echo notjson | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "no session id lets the stop through" 'out=$(echo "{}" | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "a session id that climbs out of the temp folder lets the stop through" 'out=$(echo "{\"session_id\":\"../s1\"}" | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
echo "garbage line" >"$s/over-to-you-opened"
check "an unreadable opened marker lets the stop through" 'passes'
printf '%s %s %s\n' "999999999" "$now" "x" >"$s/over-to-you-opened"
rm -f "$s/over-to-you-kits"
check "no kit record lets the stop through" 'passes'
exit "$fail"
