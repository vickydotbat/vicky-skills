#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit): when an edit to a CI workflow adds
# a patch tell (a retry, a sleep, continue-on-error, a step or job switched
# off, a skipped test, or a raised timeout-minutes), adds one line of context:
# machine-spirit step 7 says a patch never lands as the fix. Each tell has
# honest uses, so it never refuses. A first timeout is a crash guard, so only
# a raised one counts. It reads the workflow file only, never the scripts it
# calls. On unless the plugin option patch_tell_hint is false or 0, or the
# repo writes "Patch-tell hint: off" in AGENTS.md or a docs/agents/ file.
case "${CLAUDE_PLUGIN_OPTION_PATCH_TELL_HINT:-true}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
tool=$(jq -r '.tool_name // ""' <<<"$payload" 2>/dev/null) || exit 0
path=$(jq -r '.tool_input.file_path // ""' <<<"$payload")
[[ "$path" =~ (^|/)\.(github|gitea|forgejo)/workflows/[^/]+\.ya?ml$ ]] || exit 0
top=$(git -C "$(dirname "$path")" rev-parse --show-toplevel 2>/dev/null)
[ -n "$top" ] && grep -qsix 'Patch-tell hint:[[:space:]]*off' "$top/AGENTS.md" "$top"/docs/agents/*.md && exit 0
case "$tool" in
  Write) new=$(jq -r '.tool_input.content // ""' <<<"$payload"); old=$(cat "$path" 2>/dev/null) ;;
  Edit) new=$(jq -r '.tool_input.new_string // ""' <<<"$payload"); old=$(jq -r '.tool_input.old_string // ""' <<<"$payload") ;;
  MultiEdit) new=$(jq -r '[.tool_input.edits[]?.new_string] | join("\n")' <<<"$payload"); old=$(jq -r '[.tool_input.edits[]?.old_string] | join("\n")' <<<"$payload") ;;
  *) exit 0 ;;
esac
# The lines the edit adds: in the new text and not in the old.
added=$(grep -vxF -f <(printf '%s\n' "$old") <<<"$new")
tells=()
grep -qiE '\bretr(y|ies)\b|--reruns|for [a-z_]+ in [^;]*;[[:space:]]*do[^;]*&&[[:space:]]*break' <<<"$added" && tells+=("a retry")
grep -qE '(^|[^a-z_-])sleep[[:space:]]+[0-9]' <<<"$added" && tells+=("a sleep")
grep -qE 'continue-on-error:[[:space:]]*(true|\$\{\{)' <<<"$added" && tells+=("continue-on-error")
grep -qE 'if:[[:space:]]*(false|\$\{\{[[:space:]]*false[[:space:]]*\}\})[[:space:]]*$' <<<"$added" && tells+=("a step or job switched off")
grep -qE '(^|[[:space:]])(-skip|--skip|--deselect|-k[[:space:]]+["'\'']?not)([[:space:]=]|$)' <<<"$added" && tells+=("a skipped test")
# A timeout is raised when the new text's largest value tops the old one's.
most() { grep -oE 'timeout-minutes:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' | sort -n | tail -1; }
was=$(most <<<"$old"); now=$(most <<<"$new")
[ -n "$was" ] && [ -n "$now" ] && [ "$now" -gt "$was" ] && tells+=("a raised timeout")
[ ${#tells[@]} -gt 0 ] || exit 0
list=$(printf '%s, ' "${tells[@]}"); list=${list%, }
jq -n --arg l "$list" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: ("This workflow edit adds " + $l + ". machine-spirit step 7: a patch never lands as the fix. Name the cause from the runner log first, and fix it in the layer that owns it (step 2). When this must hold the line while the fix lands, the PR body names the cause and the ticket that removes it. This hint reads the workflow file, not the scripts it calls. A repo switches it off with `Patch-tell hint: off` in docs/agents/domain.md.")}}'
