#!/usr/bin/env bash
# PreToolUse hook (Bash): data a project keeps outside git (pulls, downloads,
# caches, extracted archives) is slow and costly to fetch again, so it belongs
# in one lasting place every checkout of the project shares. When a command
# fetches or unpacks into /tmp, adds a line of context steering it to that
# place. It never refuses. On unless the plugin option fetch_place_hint is false.
case "${CLAUDE_PLUGIN_OPTION_FETCH_PLACE_HINT:-true}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
code=$(jq -r '.tool_input.command // empty' 2>/dev/null)
fetch='(^|[;&|(][[:space:]]*)(curl|wget|aria2c|rsync|scp|unzip|7z|git[[:space:]]+(clone|lfs[[:space:]]+(pull|fetch))|(aws|gsutil|rclone)[[:space:]]+[^|;&]*(cp|sync|copy)|make[[:space:]]+[^|;&]*pull|tar[[:space:]]+(-?[a-zA-Z]*x[a-zA-Z]*|--extract))([[:space:]]|$)'
grep -qE "$fetch" <<<"$code" || exit 0
grep -qE '(^|[[:space:]=:"'"'"'])/tmp/' <<<"$code" || exit 0
jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: "This command fetches or unpacks into /tmp, which does not last. Data the project keeps outside git (pulls, downloads, caches, extracted archives) goes in one lasting place every checkout and worktree of the project shares: the folder its docs or scripts name, such as an ignored workspace in the main checkout, or else a folder under ~/.cache named after the project. Look there before you fetch. Keep /tmp for files only this session needs."}}'
