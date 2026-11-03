# shellcheck shell=bash
# Sourced by a script an agent runs from its own shell (summit, lesson-ledger).
# Hooks get CLAUDE_PLUGIN_DATA and the agent's shell does not. An installed copy
# sits at <plugins>/cache/<marketplace>/<plugin>/<version>/scripts, and its data
# folder is <plugins>/data/<plugin>-<marketplace>. Leaves CLAUDE_PLUGIN_DATA
# empty when neither says where.
if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
  here=$(cd "$(dirname "$0")" && pwd)
  if [[ "$here" =~ ^(.*)/cache/([^/]+)/([^/]+)/[^/]+/scripts$ ]]; then
    CLAUDE_PLUGIN_DATA="${BASH_REMATCH[1]}/data/${BASH_REMATCH[3]}-${BASH_REMATCH[2]}"
  fi
fi
