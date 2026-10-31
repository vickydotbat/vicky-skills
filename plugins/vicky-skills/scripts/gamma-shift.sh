#!/usr/bin/env bash
# SessionStart hook (startup only): asks the agent for a gamma shift. With the
# plugin option gamma_shift at remind, the agent counts the tickets waiting on
# the user and says so in one line. At engage, it runs the shift. Off by
# default. The tracker query lives in the gamma-shift skill, since the hook
# can't know the repo's tracker.
set -u
case "${CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT:-off}" in
  remind)
    echo "gamma_shift is remind: before your first reply, run the gamma-shift skill in remind mode. It adds at most one line to that reply."
    ;;
  engage)
    echo "gamma_shift is engage: run the gamma-shift skill in engage mode now, with its builds in background subagents, so the user's first request is served alongside it."
    ;;
esac
exit 0 # mutant-ok delete: the case above leaves status 0
