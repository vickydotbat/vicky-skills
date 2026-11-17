#!/usr/bin/env bash
# PostToolUse hook (Edit, Write, MultiEdit): runs actionlint on each CI
# workflow an agent writes, with shellcheck on every `run:` script when it is
# installed, and hands the findings back as feedback (exit 2). A broken quote
# or expression otherwise costs a runner job to find. A file written through
# Bash is not seen. actionlint does not know Gitea's `gitea.*` context, so that
# finding is ignored, and runner labels are judged only when the repository
# lists its own in .github/actionlint.yaml. Without actionlint it says so and
# stays off. On unless the plugin option guard_workflow_lint is false or 0.
case "${CLAUDE_PLUGIN_OPTION_GUARD_WORKFLOW_LINT:-true}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
file=$(jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0
case "$file" in
  */.gitea/workflows/*.yml | */.gitea/workflows/*.yaml) ;;
  */.github/workflows/*.yml | */.github/workflows/*.yaml) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0
command -v actionlint >/dev/null || { echo "workflow-lint: actionlint is missing, so this guard is off. Lint the workflow by hand, as machine-spirit step 4 says." >&2; exit 0; }
root=${file%/.g*/workflows/*}
args=(-ignore 'undefined variable "gitea"')
config="" # mutant-ok delete: the script runs without set -u, so an unset config reads as empty the same way
for c in "$root/.github/actionlint.yaml" "$root/.github/actionlint.yml"; do
  [ -f "$c" ] && config=$c && break
done
if [ -n "$config" ]; then
  args+=(-config-file "$config")
else
  args+=(-ignore 'label ".+" is unknown')
fi
out=$(cd "$root" && SHELLCHECK_OPTS=--severity=warning actionlint -no-color "${args[@]}" "$file" 2>&1) && exit 0
printf 'workflow-lint: actionlint refused %s\n%s\n' "$file" "$out" >&2
exit 2
