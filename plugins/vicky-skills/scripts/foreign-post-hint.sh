#!/usr/bin/env bash
# PreToolUse hook (Bash): text posted to someone else's repository reaches an
# audience, so it goes through red-pen first. When a gh command opens, readies,
# edits, reviews or comments on a pull request or issue in a repository the
# user does not administer, adds a line of context steering it there. The
# target is the -R/--repo value, else the checkout's parent when the checkout
# is a fork, else the checkout's own repository. It never refuses. On unless
# the plugin option foreign_post_hint is false or 0.
case "${CLAUDE_PLUGIN_OPTION_FOREIGN_POST_HINT:-true}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the read below comes back empty, and the match exits 0
code=$(jq -r '.tool_input.command // empty' 2>/dev/null)
grep -qE '(^|[;&|(][[:space:]]*)gh[[:space:]]+(pr[[:space:]]+(create|ready|edit|review|comment)|issue[[:space:]]+(create|comment))([[:space:]]|$)' <<<"$code" || exit 0
command -v gh >/dev/null || exit 0 # mutant-ok delete: without gh the view below fails and the hook exits 0 the same way
repo=$(grep -oE '(-R|--repo)[[:space:]=]+[^[:space:]]+' <<<"$code" | head -1 | sed -E 's/^(-R|--repo)[[:space:]=]+//')
view() { gh repo view ${1:+"$1"} --json viewerPermission,isFork,parent 2>/dev/null; }
info=$(view "$repo") || exit 0
if [ -z "$repo" ] && [ "$(jq -r '.isFork' <<<"$info")" = true ]; then
  repo=$(jq -r '.parent.nameWithOwner // empty' <<<"$info")
  info=$(view "$repo") || exit 0
fi
[ "$(jq -r '.viewerPermission // empty' <<<"$info")" = ADMIN ] && exit 0
jq -n --arg r "${repo:-this repository}" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: ("This command posts to " + $r + ", a repository the user does not administer, so a stranger reads the text. Hand its title, body or comment to the user on a red-pen page first and post only the text they approve. A mention or bot command (such as @coderabbitai) on someone else'"'"'s repository posts only when the user asked for it.")}}'
