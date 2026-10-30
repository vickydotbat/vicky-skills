#!/usr/bin/env bash
# SessionStart hook (startup only): when the plugin option auto_tidy is on, it
# prunes origin's branches and asks the agent to run marie-kondo if a local
# branch's upstream is gone. A merge done in the browser leaves its branch
# behind, and the next session in the repo is the first to see it. Off by
# default. The deleting stays in the skill, which reads each pull request's state.
set -u
case "${CLAUDE_PLUGIN_OPTION_AUTO_TIDY:-}" in true|1) ;; *) exit 0 ;; esac
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
GIT_TERMINAL_PROMPT=0 timeout 15 git fetch --prune --quiet origin >/dev/null 2>&1
gone=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
  | awk '$2 == "[gone]" { printf "%s ", $1 }')
[ -n "$gone" ] || exit 0
echo "auto_tidy: these local branches lost their upstream: ${gone% }. Before your first reply, run the marie-kondo skill, and give its report in one line."
exit 0
