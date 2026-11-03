#!/usr/bin/env bash
# PreToolUse hook (mcp__playwright__browser_navigate): refuses the windowed
# Playwright browser for a page on this machine (localhost, a loopback
# address or a file), which opens a window on the user's desktop, and steers
# the agent to the headless server that by-eye names. A sign-in page on a
# real host still opens, since only the windowed browser can show it to the
# user. On unless the plugin option guard_windowed_browser is false.
case "${CLAUDE_PLUGIN_OPTION_GUARD_WINDOWED_BROWSER:-true}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
url=$(jq -r '.tool_input.url // empty' 2>/dev/null)
grep -qiE '^(file:|(https?://)?(localhost|127\.[0-9.]+|\[::1\]|0\.0\.0\.0)([:/]|$))' <<<"$url" || exit 0
jq -n --arg u "$url" '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: ("\($u) is a page on this machine, and this browser opens a window on the user'"'"'s desktop. Use the headless server'"'"'s mcp__playwright-headless__browser_navigate, as by-eye says. With no such tool, say the headless server is missing and leave the look for the user.")
}}'
exit 0 # mutant-ok delete: jq above leaves status 0, so the script ends the same way
