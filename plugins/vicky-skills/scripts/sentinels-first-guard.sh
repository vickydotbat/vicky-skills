#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a mutation-tool command (Stryker, a
# mutate.sh, mutmut, cargo-mutants, PIT, tests/mutate-hooks.sh, or an
# agent-written mutate script) or a hand mutation until the
# session has started the sentinels skill, which scopes the pass to the changed
# lines and the tests that reach them. Quoted text is no command, so a commit
# message or a grep that names a tool passes, but a shell's -c script counts. No exceptions: a missing
# transcript refuses too, since no start can be shown. On by default; the
# plugin option guard_sentinels_first set to false or 0 turns it off.
# A hand mutation is either an in-place edit (sed -i, perl -pi) run in the same
# command as a test, or a backup copy of a file (cp or mv to a .bak, .orig or
# .backup name) taken before breaking it. A restore from the backup passes, so
# a mutated file can always be put back. An Edit-tool mutation is out of reach:
# no single call shows both the edit and the test run.
case "${CLAUDE_PLUGIN_OPTION_GUARD_SENTINELS_FIRST:-}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null)
[ -n "$cmd" ] || exit 0 # mutant-ok delete: an empty command matches no tool below, and the hook exits 0 the same way
# Quoted text is no command, except the script a shell's -c runs.
inner=$(grep -oE -- "-c[[:space:]]+('[^']*'|\"[^\"]*\")" <<<"$cmd" | sed -E "s/^-c[[:space:]]+.//; s/.$//")
bare=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<<"$cmd"; printf '%s\n' "$inner")
grep -qE '(^|[[:space:];&|(/])(dotnet-stryker|stryker|mutate\.sh|mutate-hooks\.(sh|py)|mutmut|cargo-mutants|pitest[[:alnum:]:.-]*)([[:space:];&|)]|$)|(^|[[:space:];&|(])cargo[[:space:]]+mutants([[:space:];&|)]|$)|:pitest-maven|(^|[[:space:];&|(])((python3?|bash|sh|zsh|node|deno|bun|ruby|perl)([[:space:]]+-[^[:space:];&|]+)*([[:space:]]+run)?[[:space:]]+|\.?/)[^[:space:];&|]*mutan?t[[:alnum:]_.-]*\.(py|sh|js|ts|rb|pl)([[:space:];&|)]|$)' <<<"$bare" || {
  grep -qE '(^|[[:space:];&|(])(sed[[:space:]]+(-[^[:space:]]*[[:space:]]+)*-[[:alnum:]]*i|perl[[:space:]]+-[[:alnum:]]*i)' <<<"$bare" &&
    grep -qE '(^|[[:space:];&|(/])((npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?test|pytest|jest|vitest|go[[:space:]]+test|cargo[[:space:]]+test|dotnet[[:space:]]+test|mvn[[:space:]]+test|(make|just)[[:space:]]+test|bats|run-all\.sh|[^[:space:];&|]*\.test\.(sh|js|ts|mjs))([[:space:];&|)]|$)' <<<"$bare" && hand=yes
  grep -qE '(^|[[:space:];&|(])(cp|mv)([[:space:]]+-[^[:space:];&|]+)*[[:space:]]+[^[:space:];&|]+[[:space:]]+[^[:space:];&|]+\.(bak|orig|backup)([[:space:];&|)]|$)' <<<"$bare" && hand=yes
  [ "$hand" = yes ] || exit 0
}
transcript=$(jq -r '.transcript_path // empty' <<<"$payload")
if [ -f "$transcript" ] && jq -r '
  if .type=="assistant" then .message.content[]? | select(.type=="tool_use" and .name=="Skill") | (.input.skill // "" | sub(".*:";""))
  elif .type=="user" then (.message.content | if type=="string" then . else "" end) | select(test("<command-name>/(vicky-skills:)?sentinels</command-name>")) | "sentinels"
  else empty end' "$transcript" 2>/dev/null | grep -qx sentinels; then
  exit 0
fi
jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: "sentinels-first-guard: refused, a mutation pass, by tool or by hand (an in-place edit run with the tests, or a backup copy before breaking a file), runs only after this session has started the sentinels skill, which mutates only the changed lines, picks the tests that reach them and estimates the run first. Nothing in this command ran: start the sentinels skill, then run the pass it plans."
}}'
