#!/usr/bin/env bash
# SessionStart hook: one line naming the words due, when tutor_remind is on.
# Any doubt (setting off or unset, no store yet, a damaged store) prints nothing
# and exits 0, so a session always starts.
case "${CLAUDE_PLUGIN_OPTION_TUTOR_REMIND:-}" in true|1) ;; *) exit 0 ;; esac
lang=${CLAUDE_PLUGIN_OPTION_TUTOR_LANGUAGE:-}
store=${CLAUDE_PLUGIN_OPTION_TUTOR_STORE:-}
case "$store" in "~/"*) store="$HOME/${store#"~/"}" ;; esac
[ -d "$store" ] || exit 0  # never create a store from a hook; tutor.py refuses a blank or placeholder language
n=$(TUTOR_LANGUAGE="$lang" TUTOR_STORE="$store" timeout 10 python3 "$(dirname "$0")/tutor.py" due 2>/dev/null | jq -r '.items | length' 2>/dev/null)
case "$n" in ''|0|*[!0-9]*) exit 0 ;; esac
[ "$n" = 1 ] && words="1 word" || words="$n words"
jq -cn --arg m "$lang: $words due. Type /language-tutor:drill." '{systemMessage: $m}'
exit 0
