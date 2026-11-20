#!/usr/bin/env bash
# Stop hook: cerebro builds every proposal it would pick, and asks first only
# when a wrong guess is expensive to undo. A new pull request is never that:
# a revert undoes it. When the reply since the user's last message holds a
# Cerebro block whose ask ("Waits on you", "Want it?") gives a new pull
# request as its reason, this sends the reply back to build it now. On unless
# the plugin option guard_cerebro_ask is false or 0.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_CEREBRO_ASK:-}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: stop-reply.sh reads with jq, and without it the reply reads empty and the hook exits 0
. "$(dirname "$0")/stop-reply.sh"
words=$(prose)
# Each proposal is a "- C<n>:" line and the lines under it. It asks when its
# own text, or a later "Waiting on you" line naming its code, asks.
ask=$(awk '
  /Cerebro/ {on=1; next}
  !on {next}
  match($0, /^- (C[0-9]+):/) {code=substr($0, 3, RLENGTH - 3); text[code]=$0; next}
  /^[[:space:]]+/ && code != "" {text[code]=text[code] " " $0; next}
  {code=""; tail=tail " " $0}
  END {
    for (c in text) {
      t = tolower(text[c])
      if (t !~ /new (pull request|pr)([^a-z]|$)/) continue
      if (t ~ /waits on you|want it\?/ || (tolower(tail) ~ /waiting on you|want it\?/ && tail ~ ("(^|[^A-Za-z0-9])" c "([^0-9]|$)"))) {print text[c]; exit}
    }
  }' <<<"$words")
[ -n "$ask" ] || exit 0
jq -nc --arg a "$ask" '{decision:"block", reason:("Your Cerebro block asks before a change because it needs a new pull request (\"" + $a + "\"). A revert undoes a pull request, so it is never too expensive to guess: build it now, on a fresh branch, and report it with its proof. Ask only when a wrong guess deletes, publishes or changes a setting another person relies on.")}'
