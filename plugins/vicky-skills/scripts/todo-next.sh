#!/usr/bin/env bash
# Stop hook (guard_todo_next, on by default): a reply that names what comes
# next (a "Next:" line, "my pick for next", "still want ...?") must leave that
# item in the repo's .todo the same turn, so it outlives the session. .todo
# work goes through standing-orders only: when it has not started since the
# user's last message, the stop is blocked once with a steer to standing-orders.
# A "Next: nothing" or "Next: none" line names no item. Code in backticks is
# dropped first. Silent where docs/agents says "Todo file: off", and where
# .gitignore does not ignore .todo, as springboard.sh rules.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_TODO_NEXT:-true}" in true|1) ;; *) exit 0 ;; esac
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
grep -qs '^Todo file: off' docs/agents/*.md && exit 0
git check-ignore -q .todo 2>/dev/null || exit 0 # standing orders live only where .gitignore keeps .todo out of git
line=$(prose | grep -iE '(^|[^[:alnum:]])(next|my pick for next|still want)([^[:alnum:]]|$)' | grep -iE '(^|[*_[:space:]-])next[*_]*:|my pick for next|still want' | grep -viE 'next[*_]*:[*_[:space:]]*(nothing|none)\b' | head -1)
[ -n "$line" ] || exit 0
# shellcheck source=since-user.sh
. "$(dirname "$0")/since-user.sh"
skill_since_user "$transcript" standing-orders && exit 0
jq -n --arg l "$line" '{decision:"block",reason:("todo-next: this reply names what comes next, and standing-orders has not run this turn: \"" + $l + "\". Run the standing-orders skill to jot it in .todo now, so the next session finds it, then send the reply again. A next that only the user can take (a merge, an approval) is still jotted, as standing-orders says.")}'
