#!/usr/bin/env bash
# UserPromptSubmit hook: a prompt that holds the path of an image (a bare path
# or a file:// link, png, jpg, jpeg or webp) gets one line of context: start
# the screenshot-intake skill before forming a theory. The user shows a problem
# in screenshots, and an agent that reads one and says nothing about it forgets
# it by the next turn. A prompt with no image path gets nothing, and bad input
# exits 0 with nothing.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
prompt=$(jq -r '.prompt // ""' 2>/dev/null)
n=$(grep -oEi '[^[:space:]"'"'"'<>]*/[^[:space:]"'"'"'<>]*\.(png|jpe?g|webp)\b' <<<"$prompt" | sort -u | wc -l)
[ "$n" -gt 0 ] || exit 0
noun="image path"; [ "$n" -gt 1 ] && noun="image paths"
hint="The prompt holds $n $noun from the user: start the screenshot-intake skill now (read each image, say what it shows and which part the user points at, record it, compare it with the journals) before you form a theory."
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$h}}'
