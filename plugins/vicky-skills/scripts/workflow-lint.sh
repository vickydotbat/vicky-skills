#!/usr/bin/env bash
# PostToolUse hook (Edit, Write, MultiEdit): runs actionlint on each CI
# workflow an agent writes and hands the findings back (exit 2), so a broken
# quote or expression never costs a runner job. A file written through Bash is
# not seen. actionlint doesn't know Gitea's `gitea.*` context, so that finding
# is ignored. On unless the plugin option guard_workflow_lint is false or 0.
case "${CLAUDE_PLUGIN_OPTION_GUARD_WORKFLOW_LINT:-true}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
file=$(jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0
case "$file" in
  */.gitea/workflows/*.yml | */.gitea/workflows/*.yaml) root=${file%/.gitea/workflows/*} ;;
  */.github/workflows/*.yml | */.github/workflows/*.yaml) root=${file%/.github/workflows/*} ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0
command -v actionlint >/dev/null || { echo "workflow-lint: actionlint is missing, so this guard is off. Lint the workflow by hand, as machine-spirit step 4 says." >&2; exit 0; }
command -v shellcheck >/dev/null || echo "workflow-lint: shellcheck is missing, so run: scripts go unchecked." >&2
# Runner labels are judged only when the repository lists its own.
args=(-ignore 'undefined variable "gitea"' -ignore 'label ".+" is unknown')
for c in "$root/.github/actionlint.yaml" "$root/.github/actionlint.yml"; do
  [ -f "$c" ] && args=(-ignore 'undefined variable "gitea"' -config-file "$c") && break
done
out=$(cd "$root" && SHELLCHECK_OPTS=--severity=warning actionlint -no-color "${args[@]}" "$file" 2>&1) && exit 0
printf 'workflow-lint: actionlint refused %s\n%s\n' "$file" "$out" >&2
exit 2
