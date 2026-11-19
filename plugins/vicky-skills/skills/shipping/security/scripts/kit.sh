# shellcheck shell=bash
# Sourced by the security kit's scripts, run from inside a repo.
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "security: run this inside the repo it is about."; exit 1; }
# line <name>: the value of the repo's first "<name>:" line in docs/agents/.
line() { sed -nE "s/^(- )?$1:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\2/p" "$top"/docs/agents/*.md 2>/dev/null | head -n1; }
# fp_installed: whether Claude Code has the fp-check plugin installed.
fp_installed() { jq -e '.plugins | keys | any(startswith("fp-check@"))' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json" >/dev/null 2>&1; }
remote=$(git -C "$top" config remote.origin.url 2>/dev/null || true)
# forge_slug <host>: owner/repo when origin is on <host>, else nothing.
forge_slug() { local s; s=$(sed -nE "s#^(https://|git@|ssh://git@)$1[:/]([^/]+/[^/]+)/?\$#\\2#p" <<<"$remote"); echo "${s%.git}"; }
