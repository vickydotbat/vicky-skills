#!/usr/bin/env bash
# Proofread a draft with an outside model on any OpenAI-compatible endpoint, for
# human-voice's proofread step. Settings arrive as environment variables:
#   PROOFREAD_MODEL     the model id, or "session" (default gemini-4-hydrogen)
#   PROOFREAD_ENDPOINT  the API base URL (default Gemini's OpenAI-compatible one)
#   PROOFREAD_KEY_ENV   the variable holding the key, or "none" (default GEMINI_API_KEY)
# Prints "proofread: <model>" and the model's notes, or
# "proofread: session model, because <reason>" when the session's own model
# must proofread instead. Exits 0 either way, and 2 on bad usage.
set -u
file="${1:-}"
[ -f "$file" ] || { echo "usage: proofread.sh <draft file>" >&2; exit 2; }
model="${PROOFREAD_MODEL:-gemini-4-hydrogen}"
endpoint="${PROOFREAD_ENDPOINT:-https://generativelanguage.googleapis.com/v1beta/openai/}"
key_env="${PROOFREAD_KEY_ENV:-GEMINI_API_KEY}"
fallback() { echo "proofread: session model, because $1"; exit 0; }
# A custom endpoint takes no Gemini default, so a Gemini key never leaves for it.
if [ -n "${PROOFREAD_ENDPOINT:-}" ]; then
  [ -n "${PROOFREAD_KEY_ENV:-}" ] || fallback "the endpoint is set but its key variable is blank: name the variable, or none"
  [ -n "${PROOFREAD_MODEL:-}" ] || fallback "the endpoint is set but its model is blank"
fi

[ "$model" = session ] && fallback "the proofread model setting is session"
{ command -v curl && command -v jq; } >/dev/null || fallback "curl or jq is missing"
hdr=$(mktemp); trap 'rm -f "$hdr"' EXIT  # mktemp makes it 0600
# The key goes through a header file, never the command line, where ps shows it.
if [ "$key_env" != none ]; then
  [[ $key_env =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || fallback "the key variable name $key_env is not a variable name"
  key="${!key_env:-}"
  [ -n "$key" ] || fallback "no key in $key_env"
  printf 'Authorization: Bearer %s' "$key" > "$hdr"
fi

prompt='You proofread prose. The draft comes with its line numbers. Report each spelling, grammar, punctuation or unclear-sentence error as "line N: before -> after", one per line. Keep the writer'"'"'s voice, words and structure: suggest no rewrite of style or tone. Print "no changes" when there are none.'
draft=$(awk '{ printf "%d: %s\n", NR, $0 }' "$file")
resp=$(jq -n --arg m "$model" --arg p "$prompt" --arg d "$draft" \
    '{model: $m, messages: [{role: "system", content: $p}, {role: "user", content: $d}]}' |
  curl -sS --fail-with-body --max-time 60 -H "@$hdr" -H 'Content-Type: application/json' \
    --data-binary @- "${endpoint%/}/chat/completions" 2>&1)
notes=$(jq -r '.choices[0].message.content // empty' <<<"$resp" 2>/dev/null)
if [ -z "$notes" ]; then
  err=$(jq -r '.error.message // empty' <<<"$resp" 2>/dev/null)
  [ -n "$err" ] || err=$(tail -n 1 <<<"$resp")
  fallback "$model at $endpoint failed: ${err:-no answer}"
fi
echo "proofread: $model"
echo "$notes"
