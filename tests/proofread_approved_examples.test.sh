#!/usr/bin/env bash
# approved-spec: the examples ticked on the proofread-step drafts page. Each runs
# human-voice's proofread script with a stub curl on PATH, so no request leaves
# the machine, and reads what the script prints and what it sent.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
pr="$here/../plugins/vicky-skills/skills/writing/human-voice/scripts/proofread.sh"
plugin="$here/../plugins/vicky-skills/.claude-plugin/plugin.json"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/bin"
# The stub records its arguments, the headers it was given and the request body,
# then answers as STUB_MODE says: ok, error or timeout.
cat > "$dir/bin/curl" <<'STUB'
#!/usr/bin/env bash
log="$STUB_DIR/sent"; : > "$log"
while [ $# -gt 0 ]; do
  case "$1" in
    -H|--header) h="$2"; shift
      if [ "${h#@}" != "$h" ]; then cat "${h#@}" >> "$log"; echo >> "$log"; else echo "$h" >> "$log"; fi ;;
    -d|--data|--data-binary) d="$2"; shift
      if [ "$d" = @- ]; then cat >> "$log"; else echo "$d" >> "$log"; fi; echo >> "$log" ;;
    *) echo "arg: $1" >> "$log" ;;
  esac; shift
done
case "${STUB_MODE:-ok}" in
  ok) echo '{"choices":[{"message":{"content":"line 2: teh -> the"}}]}' ;;
  error) echo '{"error":{"code":404,"message":"models/gemini-4-hydrogen is not found"}}'; exit 22 ;;
  timeout) echo 'curl: (28) Operation timed out after 60000 milliseconds' >&2; exit 28 ;;
esac
STUB
chmod +x "$dir/bin/curl"
printf 'A draft\nwith teh typo\n' > "$dir/draft.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { rm -f "$dir/sent"; out=$(env -u GEMINI_API_KEY PATH="$dir/bin:$PATH" STUB_DIR="$dir" "$@" bash "$pr" "$dir/draft.md" 2>&1); rc=$?; sent=$(cat "$dir/sent" 2>/dev/null); }

# Given GEMINI_API_KEY holds a working key and the proofread settings are blank
# When human-voice proofreads a draft
# Then the proofread notes come from gemini-4-hydrogen
run GEMINI_API_KEY=k-gem PROOFREAD_MODEL= PROOFREAD_ENDPOINT= PROOFREAD_KEY_ENV=
check "E1 Hydrogen by default" '[ $rc -eq 0 ] && grep -q "teh -> the" <<<"$out" && grep -q "^proofread: gemini-4-hydrogen" <<<"$out" && grep -q "\"model\": *\"gemini-4-hydrogen\"" <<<"$sent" && grep -q "generativelanguage.googleapis.com/v1beta/openai/chat/completions" <<<"$sent" && grep -q "Bearer k-gem" <<<"$sent" && grep -q "with teh typo" <<<"$sent"'

# Given the proofread endpoint, model and key variable name an OpenAI-compatible provider, such as OpenRouter or a local Ollama
# When human-voice proofreads a draft
# Then the proofread notes come from that provider's model
run OTHER_KEY=k-other PROOFREAD_MODEL=llama3 PROOFREAD_ENDPOINT=http://localhost:11434/v1/ PROOFREAD_KEY_ENV=OTHER_KEY
check "E2 Any provider" '[ $rc -eq 0 ] && grep -q "teh -> the" <<<"$out" && grep -q "^proofread: llama3" <<<"$out" && grep -q "\"model\": *\"llama3\"" <<<"$sent" && grep -q "arg: http://localhost:11434/v1/chat/completions" <<<"$sent" && grep -q "Bearer k-other" <<<"$sent" && ! grep -q generativelanguage <<<"$sent"'

# Given the key variable is empty
# When human-voice proofreads a draft
# Then nothing is sent, and the session's own model proofreads the draft
# And the reply says the outside proofread was skipped for want of a key
run PROOFREAD_MODEL= PROOFREAD_KEY_ENV=
check "E3 No key, the session model proofreads" '[ $rc -eq 0 ] && [ ! -e "$dir/sent" ] && grep -q "^proofread: session model" <<<"$out" && grep -q "no key in GEMINI_API_KEY" <<<"$out"'

# Given the provider answers with an error, or gives no answer within 60 seconds
# When human-voice proofreads a draft
# Then the session's own model proofreads the draft
# And the reply names the provider's error
run GEMINI_API_KEY=k-gem STUB_MODE=error
check "E4 Model unavailable, the session model proofreads" '[ $rc -eq 0 ] && grep -q "^proofread: session model" <<<"$out" && grep -q "is not found" <<<"$out"'
run GEMINI_API_KEY=k-gem STUB_MODE=timeout
check "E4 No answer within 60 seconds, the session model proofreads" '[ $rc -eq 0 ] && grep -q "^proofread: session model" <<<"$out" && grep -qi "timed out" <<<"$out" && grep -q "arg: 60" <<<"$sent"'

# Given the proofread model setting is "session"
# When human-voice proofreads a draft
# Then nothing is sent, even with a key set, and the session's own model proofreads
run GEMINI_API_KEY=k-gem PROOFREAD_MODEL=session
check "E5 Switched to the session model on purpose" '[ $rc -eq 0 ] && [ ! -e "$dir/sent" ] && grep -q "^proofread: session model" <<<"$out"'

# Given GEMINI_API_KEY is set and the proofread settings were never touched
# When human-voice proofreads a draft
# Then the draft goes to gemini-4-hydrogen, and the plugin settings page says free-tier prompts may train Google's models
run GEMINI_API_KEY=k-gem
check "E6 A key set for other work" '[ $rc -eq 0 ] && grep -q "\"model\": *\"gemini-4-hydrogen\"" <<<"$sent" && jq -r ".userConfig.proofread_model.description" "$plugin" | grep -qi "train"'

exit $fail
