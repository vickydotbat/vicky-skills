#!/usr/bin/env bash
# approved-spec: a stack and a rebase build on origin's trunk, never a stale
# local one. Each check is named after its example, and pins the skill text
# that drives the agent; restack-origin-guard.test.sh proves the hook.
set -u
p="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
sb="$p/skills/building/stacked-branches/SKILL.md"
hm="$p/skills/shipping/history-monks/SKILL.md"
step4() { awk '/^4\. /{on=1} /^5\. /{on=0} on' "$hm"; }
check "given a Gitea stack whose parent merged, when the agent restacks, then it syncs trunk to origin first and the guard refuses a restack onto a stale local trunk" \
  'grep -q "restack-origin-guard" "$sb" && grep -qF "never \`gs branch onto <trunk>\` alone" "$sb"'
check "given a stacked branch whose parent was squash-merged, when history-monks rebases it, then it moves only the branch's own commits onto origin's base" \
  'step4 | grep -qF "git rebase --onto origin/<base> <old parent tip> <branch>"'
check "given the hook, then it is registered and has its option, its README row and its CI step" \
  'grep -q "restack-origin-guard.sh" "$p/hooks/hooks.json" && jq -e ".userConfig.guard_restack_origin.default == true" "$p/.claude-plugin/plugin.json" >/dev/null && grep -q "restack-origin-guard" "$p/../../README.md" && grep -q "tests/restack-origin-guard.test.sh" "$p/../../.github/workflows/ci.yml"'
exit $fail
