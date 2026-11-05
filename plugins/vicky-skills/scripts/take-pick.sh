#!/usr/bin/env bash
# Stop hook (guard_take_pick, off by default): a question the agent asks in
# chat with its own pick attached, and no gate behind it, waits forever when
# the user says nothing. When the agent's last reply gives a pick ("my pick",
# "I recommend", "Pick:") and asks a question, the stop is blocked once with a
# steer: take the pick now and say "Going with", or gate it with a
# "🚪 Waiting on you" ask and a watch. A reply that already says "Going with"
# or opens a gate goes through, but a "Going with" covers only the text above it, unless the gate carries its pick and asks a
# question (in chat, a question mark, or options such as O1) with no page link. A gate that links its page but also leaves
# "yes or no" or "A yes is enough" in chat goes back too. It steers once per turn: with
# stop_hook_active set, the reply goes through, so a misjudged one never loops.
# After a sup that found a handoff, a reply asking for go is sent back to start it.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_TAKE_PICK:-}" in true|1) ;; *) exit 0 ;; esac
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
council_sits "$transcript" && exit 0 # a council's picks and Frodo's Next are its own, for the user to argue
# A sup that found a handoff starts its work unasked (sup step 4), so a "say go" after one goes back.
if skill_since_user "$transcript" sup && grep -qi "handoff" <<<"$said" && grep -qiE "\b(say|reply|type)[[:space:]]+[*_]*go\b|shall i start|want me to start" <<<"$said"; then
  jq -n '{decision:"block", reason:"sup found a handoff, and sup step 4 starts its work unasked: start do, or warp when the handoff names a run of stars, in this turn, without asking for go."}'
  exit 0
fi
# A "Going with" takes the pick above it, never a pick asked below it: weigh
# only what follows the last line that says it.
going=$(grep -niE "going with" <<<"$said" | tail -n 1 | cut -d: -f1)
[ -z "$going" ] || said=$(tail -n "+$((going + 1))" <<<"$said")
# A gate whose answer comes in chat waits unseen while the user works in
# another window, so a gated pick asked in chat, with no page link, goes back.
if grep -qiE "🚪 (still )?waiting on you" <<<"$said"; then
  # Steps the user must carry out, numbered in chat, belong on an over-to-you
  # checklist page, where each one is ticked and its command sits beside it.
  if [ "$(grep -cE '^[[:space:]]*[0-9]+[.)][[:space:]]' <<<"$said")" -ge 2 ] && ! grep -qE "https?://" <<<"$said"; then
    jq -n '{decision:"block", reason:"You gated numbered steps for the user to carry out in chat. Live checks only the user can do go through the over-to-you skill: a checklist page with each step, its exact command, and what to load or open. Start over-to-you and send the page link."}'
    exit 0
  fi
  # A yes or no question left in chat beside the page waits unseen too, and it is
  # usually cheap: the agent takes it, or moves it onto the page.
  if grep -qE "https?://" <<<"$said" && grep -qiE '\byes or no\b|\ba yes is enough\b' <<<"$(prose)"; then
    jq -n '{decision:"block", reason:"You left a yes or no question in chat beside a page. The user watches the browser, so it waits unseen. When it is cheap to undo, or the rules on record already answer it, take it: write \"Going with <pick>\" and act on it. Otherwise put the question on the page with the interactive-page skill."}'
    exit 0 # mutant-ok delete: falling through, the next line sees the page link and exits 0 the same way
  fi
  grep -qiE "my pick|i recommend|\bpick:" <<<"$(prose)" && grep -qiE 'in chat|answer with|reply with|\?|\bO[0-9]+\b' <<<"$(prose)" && ! grep -qE "https?://" <<<"$said" || exit 0
  jq -n '{decision:"block", reason:"You gated your own pick and asked for the answer in chat. The user watches the browser, not the chat, so this waits unseen. When the pick is cheap to undo, take it: write \"Going with <pick>\" and act on it. When only the user can answer, put the question on a page with the interactive-page skill and send its link."}'
  exit 0
fi
grep -qiE "my pick|i recommend|\bpick:" <<<"$(prose)" || exit 0
asks=$(printf '%s\n' "$said" | tr '\n' ' ' | sed 's/\([.?!]\) /\1\n/g' | grep -E '\?[[:space:]]*$|\?$|[Aa]nswer (with|in)|[Rr]eply with')
[ -n "$asks" ] || exit 0
jq -n --arg q "$asks" '{decision:"block", reason:("You asked with a pick but nothing takes it if the user stays silent. When the pick is cheap to undo, take it now: write \"Going with <pick>\" and act on it. When it is costly to undo, gate it: open it with \"🚪 Waiting on you: <the one thing>\" and wait at it as skills/GATES.md in this plugin says. The question:\n" + $q)}'
