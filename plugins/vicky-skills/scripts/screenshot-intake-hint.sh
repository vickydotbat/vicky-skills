#!/usr/bin/env bash
# UserPromptSubmit hook: a prompt holding an image path (png, jpg, jpeg, webp; a
# bare path or a file:// link) starts screenshot-intake before any theory. A path
# with a raw space splits at the space, so only its percent-encoded form matches.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
prompt=$(jq -r '.prompt // ""' 2>/dev/null)
n=$(grep -oEi '[^[:space:]"'"'"'<>]*/[^[:space:]"'"'"'<>]*\.(png|jpe?g|webp)\b' <<<"$prompt" | sort -u | wc -l)
[ "$n" -gt 0 ] || exit 0
noun="image path"; [ "$n" -gt 1 ] && noun="image paths"
hint="The prompt holds $n $noun from the user: start the screenshot-intake skill now (read each image, say what it shows and which part the user points at, record it, compare it with the journals) before you form a theory."
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$h}}'
