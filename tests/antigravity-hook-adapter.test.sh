#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# Antigravity lifecycle hook adapter decisions: config loading, PreToolUse
# allow/deny (exit 2, permissionDecision deny, decision block), Bash/Edit/Write/
# Agent/Read tool mapping, PostToolUse {}, SessionStart/PreInvocation injectSteps
# (with prompt deduplication), Stop continue/allow, and malformed input.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adapter="$root/plugins/vicky-skills/scripts/antigravity-hook-adapter.py"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0

run_adp() {
  local proot="$1" event="$2" data="$3" payload="$4"
  PLUGIN_ROOT="$proot" PLUGIN_DATA="$data" python3 "$adapter" "$event" <<<"$payload" 2>/dev/null
}

check() {
  local name="$1" cond="$2"
  if eval "$cond"; then echo "ok   $name"; else echo "FAIL $name"; fails=1; fi
}

mkdir -p "$tmp/data" "$tmp/repo" "$tmp/stub/.claude-plugin" "$tmp/stub/scripts"
git init -q -b main "$tmp/repo"
git -C "$tmp/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

# Real vicky-skills hooks: tea-stdin (exit 2), skill-ledger (config.json), todo-reminder, promise-guard
out="$(run_adp "$root/plugins/vicky-skills" PreToolUse "$tmp/data" "{\"conversationId\":\"c1\",\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"tea pr list\"}}}")"
check "PreToolUse denies bare tea via tea-stdin.sh" '[[ "$out" == *'\''"decision": "deny"'\''* && "$out" == *"tea-stdin.sh"* ]]'

echo '{"skill_ledger": true}' > "$tmp/data/config.json"
out="$(run_adp "$root/plugins/vicky-skills" PreToolUse "$tmp/data" "{\"conversationId\":\"c1\",\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"read_file\",\"args\":{\"Path\":\"$root/plugins/vicky-skills/skills/warp/SKILL.md\"}}}")"
check "PreToolUse read_file allows and records skill-ledger from config.json" \
  '[[ "$out" == *'\''"decision": "allow"'\''* ]] && grep -q "warp" "$tmp/data/skill-ledger.tsv"'

# Stub plugin for fast, exhaustive coverage of all adapter branches
cat >"$tmp/stub/.claude-plugin/plugin.json" <<'JSON'
{"userConfig":{"opt_default":{"type":"boolean","default":true},"opt_str":{"type":"string","default":"hi"},"opt_nodef":{"type":"string"}}}
JSON
cat >"$tmp/stub/scripts/log-hook.sh" <<'SH'
#!/usr/bin/env bash
cat > "$CLAUDE_PLUGIN_DATA/last_payload.json"
printf '%s|%s|%s|%s|%s|%s\n' "$CLAUDE_PLUGIN_ROOT" "$CLAUDE_PLUGIN_OPTION_OPT_DEFAULT" "$CLAUDE_PLUGIN_OPTION_OPT_STR" "$CLAUDE_CODE_SESSION_ID" "$VICKY_SESSION_ID" "$CLAUDE_PROJECT_DIR" > "$CLAUDE_PLUGIN_DATA/last_env.txt"
SH
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/approved-test-lock.sh"
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/review-brief-guard.sh"
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/springboard.sh"
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/pkill-guard.sh"
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/eval-tmpdir-guard.sh"
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/opponent-wait-guard.sh"
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/whole-read-guard.sh"
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/outside-text-guard.sh"
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/publish-guard.sh"
cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/advisory-guard.sh"
cat >"$tmp/stub/scripts/adr-scope-hint.sh" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
echo '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"deny-reason"}}'
SH
cat >"$tmp/stub/scripts/patch-tell-hint.sh" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
echo '{"decision":"block","reason":"block-reason"}'
SH
cat >"$tmp/stub/scripts/todo-reminder.sh" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
echo '{"hookSpecificOutput":{"additionalContext":"ctx-from-json"}}'
SH
cat >"$tmp/stub/scripts/lesson-hint.sh" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
echo "plain-context"
SH
cat >"$tmp/stub/scripts/promise-guard.sh" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
echo '{"decision":"block","reason":"stop-block"}'
SH
chmod +x "$tmp/stub/scripts/"*.sh

# Subdir + workspacePaths fallback + env/option loading
mkdir -p "$tmp/repo/sub"
out="$(run_adp "$tmp/stub" PreToolUse "$tmp/data" "{\"conversationId\":\"c2\",\"workspacePaths\":[\"$tmp/repo/sub\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"f.txt\",\"Content\":\"hello\"}}}")"
check "PreToolUse write_file maps args and permissionDecision deny" \
  '[[ "$out" == *'\''"decision": "deny"'\''* && "$out" == *"deny-reason"* ]] && grep -qx "$tmp/stub|true|hi|c2|c2|$tmp/repo" "$tmp/data/last_env.txt" && grep -q "\"content\": \"hello\"" "$tmp/data/last_payload.json"'

# edit_file maps old_string/new_string and decision:block
rm "$tmp/stub/scripts/adr-scope-hint.sh"
out="$(run_adp "$tmp/stub" PreToolUse "$tmp/data" "{\"conversationId\":\"c2\",\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"edit_file\",\"args\":{\"Path\":\"f.txt\",\"Target\":\"a\",\"Replacement\":\"b\"}}}")"
check "PreToolUse edit_file maps args and decision:block" \
  '[[ "$out" == *'\''"decision": "deny"'\''* && "$out" == *"block-reason"* ]] && grep -q "\"old_string\": \"a\"" "$tmp/data/last_payload.json"'

# invoke_subagent maps Agent + Bash keyword rules (pkill, plane, merge, curl, glab, advisory.sh, head)
out="$(run_adp "$tmp/stub" PreToolUse "$tmp/data" "{\"conversationId\":\"c2\",\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"invoke_subagent\",\"args\":{\"TypeName\":\"r\",\"Prompt\":\"p\",\"Role\":\"role\"}}}")"
check "PreToolUse invoke_subagent maps Agent" '[[ "$out" == *'\''"decision": "allow"'\''* ]] && grep -q "\"subagent_type\": \"r\"" "$tmp/data/last_payload.json"'

out="$(run_adp "$tmp/stub" PreToolUse "$tmp/data" "{\"conversationId\":\"c2\",\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"pkill x; plane show 1 | head; curl -X POST u; glab repo view; advisory.sh publish; gh pr merge 1\"}}}")"
check "PreToolUse Bash keyword rules allow when stubs pass" '[[ "$out" == *'\''"decision": "allow"'\''* ]]'

for pair in \
  "outside-text-guard.sh:curl -X POST https://example.invalid" \
  "publish-guard.sh:glab repo create o/r --public" \
  "advisory-guard.sh:advisory.sh cve GHSA-1" \
  "whole-read-guard.sh:read-item.sh 1 | head" \
  "opponent-wait-guard.sh:\$GH pr merge 1" \
  "eval-tmpdir-guard.sh:claude plugin eval p"; do
  s="${pair%%:*}"; cmd="${pair#*:}"
  printf '#!/usr/bin/env bash\necho "hit-%s"; exit 2\n' "$s" > "$tmp/stub/scripts/$s"
  chmod +x "$tmp/stub/scripts/$s"
  out="$(run_adp "$tmp/stub" PreToolUse "$tmp/data" "{\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"$cmd\"}}}")"
  check "PreToolUse routes '$cmd' to $s" '[[ "$out" == *'\''"decision": "deny"'\''* && "$out" == *"hit-$s"* ]]'
  cp "$tmp/stub/scripts/log-hook.sh" "$tmp/stub/scripts/$s"
done

# Unknown tool allows / PostToolUse returns {}
out="$(run_adp "$tmp/stub" PreToolUse "$tmp/data" '{"toolCall":{"name":"unknown_tool"}}')"
check "PreToolUse unknown tool allows" '[[ "$out" == *'\''"decision": "allow"'\''* ]]'

# Null arg values do not crash PreToolUse or PostToolUse
out_null_pre="$(run_adp "$tmp/stub" PreToolUse "$tmp/data" "{\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":null}}}")"
out_null_post="$(run_adp "$tmp/stub" PostToolUse "$tmp/data" "{\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":null}}}")"
check "PreToolUse null CommandLine allows without TypeError" '[[ "$out_null_pre" == *'\''"decision": "allow"'\''* ]]'
check "PostToolUse null CommandLine returns {}" '[[ "$out_null_post" == "{}" ]]'

# Non-git cwd + missing cwd + transcriptPath forwarding + pre-set env option not overwritten
mkdir -p "$tmp/plain"
out="$(CLAUDE_PLUGIN_OPTION_OPT_STR=keep run_adp "$tmp/stub" PreToolUse "$tmp/data" "{\"cwd\":\"$tmp/plain\",\"transcriptPath\":\"/t.jsonl\",\"toolCall\":{\"name\":\"invoke_subagent\",\"args\":{\"TypeName\":\"r\"}}}")"
check "non-git cwd and pre-set env option preserved" 'grep -qx "$tmp/stub|true|keep|||$tmp/plain" "$tmp/data/last_env.txt" && grep -q "\"transcript_path\": \"/t.jsonl\"" "$tmp/data/last_payload.json"'
out="$(run_adp "$tmp/stub" PreToolUse "$tmp/data" "{\"cwd\":\"$tmp/missing\",\"toolCall\":{\"name\":\"invoke_subagent\",\"args\":{\"TypeName\":\"r\"}}}")"
check "missing cwd still runs hook with empty payload cwd" '[[ "$out" == *'\''"decision": "allow"'\''* ]] && grep -q "\"cwd\": \"\"" "$tmp/data/last_payload.json"'

# Exit 2 with stdout only
cat >"$tmp/stub/scripts/exit2stdout.sh" <<'SH'
#!/usr/bin/env bash
echo "stdout-deny"; exit 2
SH
chmod +x "$tmp/stub/scripts/exit2stdout.sh"
cp "$tmp/stub/scripts/exit2stdout.sh" "$tmp/stub/scripts/review-brief-guard.sh"
out="$(run_adp "$tmp/stub" PreToolUse "$tmp/data" '{"toolCall":{"name":"invoke_subagent","args":{"TypeName":"r"}}}')"
check "exit 2 with stdout only denies with stdout message" '[[ "$out" == *'\''"decision": "deny"'\''* && "$out" == *"stdout-deny"* ]]'

# PostToolUse: git command runs pr-guard, non-git skips pr-guard, edit_file runs springboard
cat >"$tmp/stub/scripts/pr-guard.sh" <<'SH'
#!/usr/bin/env bash
touch "$CLAUDE_PLUGIN_DATA/pr_guard_ran"
SH
chmod +x "$tmp/stub/scripts/pr-guard.sh"
rm -f "$tmp/data/pr_guard_ran"
out="$(run_adp "$tmp/stub" PostToolUse "$tmp/data" "{\"cwd\":\"$tmp/repo\",\"error\":\"e1\",\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"git status\"}}}")"
check "PostToolUse git Bash runs pr-guard and forwards error" '[[ "$out" == "{}" ]] && [ -f "$tmp/data/pr_guard_ran" ] && grep -q "\"error\": \"e1\"" "$tmp/data/last_payload.json"'

rm -f "$tmp/data/pr_guard_ran"
out="$(run_adp "$tmp/stub" PostToolUse "$tmp/data" "{\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"ls\"}}}")"
check "PostToolUse non-git Bash skips pr-guard" '[[ "$out" == "{}" ]] && [ ! -f "$tmp/data/pr_guard_ran" ]'

rm -f "$tmp/data/last_payload.json"
out="$(run_adp "$tmp/stub" PostToolUse "$tmp/data" "{\"cwd\":\"$tmp/repo\",\"toolCall\":{\"name\":\"edit_file\",\"args\":{\"Path\":\"a\"}}}")"
check "PostToolUse edit_file runs springboard and returns {}" '[[ "$out" == "{}" ]] && [ -f "$tmp/data/last_payload.json" ]'

out="$(run_adp "$tmp/stub" PostToolUse "$tmp/data" '{"toolCall":{"name":"unknown"}}')"
check "PostToolUse unknown tool returns {}" '[[ "$out" == "{}" ]]'

# SessionStart injects JSON additionalContext, or {} when quiet
out="$(run_adp "$tmp/stub" SessionStart "$tmp/data" "{\"cwd\":\"$tmp/repo\"}")"
check "SessionStart injects additionalContext" '[[ "$out" == *'\''"injectSteps"'\''* && "$out" == *"\"systemMessage\": \"ctx-from-json\""* ]]'
rm "$tmp/stub/scripts/todo-reminder.sh"
out="$(run_adp "$tmp/stub" SessionStart "$tmp/data" "{\"cwd\":\"$tmp/repo\"}")"
check "SessionStart returns {} when quiet" '[[ "$out" == "{}" ]]'

# PreInvocation injects plain text once, deduplicates repeat, skips empty
out1="$(run_adp "$tmp/stub" PreInvocation "$tmp/data" "{\"conversationId\":\"c9\",\"cwd\":\"$tmp/repo\",\"lastUserInput\":\"hi\"}")"
out2="$(run_adp "$tmp/stub" PreInvocation "$tmp/data" "{\"conversationId\":\"c9\",\"cwd\":\"$tmp/repo\",\"lastUserInput\":\"hi\"}")"
out3="$(run_adp "$tmp/stub" PreInvocation "$tmp/data" "{\"conversationId\":\"c9\",\"cwd\":\"$tmp/repo\",\"lastUserInput\":\"\"}")"
check "PreInvocation injects plain-context once" '[[ "$out1" == *'\''"injectSteps"'\''* && "$out1" == *"plain-context"* ]]'
check "PreInvocation deduplicates same prompt" '[[ "$out2" == "{}" ]]'
check "PreInvocation skips empty prompt" '[[ "$out3" == "{}" ]]'

# Stop continues on block, allows on continuationActive, terminationReason!=NO_TOOL_CALL, or clean
out="$(run_adp "$tmp/stub" Stop "$tmp/data" '{"terminationReason":"NO_TOOL_CALL","continuationActive":false}')"
check "Stop returns continue when hook blocks" '[[ "$out" == *'\''"decision": "continue"'\''* && "$out" == *"stop-block"* ]]'
out="$(run_adp "$tmp/stub" Stop "$tmp/data" '{"terminationReason":"NO_TOOL_CALL","continuationActive":true}')"
check "Stop allows when continuationActive is true" '[[ "$out" == *'\''"decision": "allow"'\''* ]]'
out="$(run_adp "$tmp/stub" Stop "$tmp/data" '{"terminationReason":"USER_CANCELED","continuationActive":false}')"
check "Stop allows when terminationReason is not NO_TOOL_CALL" '[[ "$out" == *'\''"decision": "allow"'\''* ]]'
rm "$tmp/stub/scripts/promise-guard.sh"
out="$(run_adp "$tmp/stub" Stop "$tmp/data" '{"terminationReason":"NO_TOOL_CALL"}')"
check "Stop allows when all hooks pass" '[[ "$out" == *'\''"decision": "allow"'\''* ]]'

# Event from payload hookEventName + unknown event + malformed JSON
out="$(run_adp "$tmp/stub" "" "$tmp/data" '{"hookEventName":"Other"}')"
check "unknown event from hookEventName returns {}" '[[ "$out" == "{}" ]]'
out="$(echo 'not json' | PLUGIN_ROOT="$tmp/stub" PLUGIN_DATA="$tmp/data" python3 "$adapter" PreToolUse 2>/dev/null)"
check "malformed JSON on PreToolUse allows" '[[ "$out" == *'\''"decision": "allow"'\''* ]]'
out="$(echo 'not json' | PLUGIN_ROOT="$tmp/stub" PLUGIN_DATA="$tmp/data" python3 "$adapter" PostToolUse 2>/dev/null)"
check "malformed JSON on PostToolUse returns {}" '[[ "$out" == "{}" ]]'

exit "$fails"
