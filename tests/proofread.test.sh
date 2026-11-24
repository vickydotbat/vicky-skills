#!/usr/bin/env bash
# Edges of human-voice's proofread script past its approved examples: a server
# that needs no key, a bad key variable name, a missing tool, an empty answer,
# and bad usage. A stub curl on PATH stands in for the network.
# shellcheck disable=SC2016 # check evals its condition later, so single quotes keep it unexpanded
# shellcheck disable=SC2034 # the variables run sets are read inside check's eval
set -u
here="$(cd "$(dirname "$0")" && pwd)"
pr="$here/../plugins/vicky-skills/skills/writing/human-voice/scripts/proofread.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/bin"
cat > "$dir/bin/curl" <<'STUB'
#!/usr/bin/env bash
: > "$STUB_DIR/sent"
for a in "$@"; do case "$a" in @*) [ -f "${a#@}" ] && { cat "${a#@}"; echo; } >> "$STUB_DIR/sent" ;; esac; done
cat >> "$STUB_DIR/sent"
case "${STUB_MODE:-ok}" in
  ok) echo '{"choices":[{"message":{"content":"no changes"}}]}' ;;
  empty) echo '{"choices":[]}' ;;
  busy) echo 'curl: (22) The requested URL returned error: 503' >&2
    echo '[{"error": {"code": 503, "message": "This model is currently experiencing high demand."}}]'; exit 22 ;;
  refused) echo '{"error": {"message": "API key not valid."}}'; exit 22 ;;
  quota) echo '{"error": "quota exceeded"}'; exit 22 ;;
  plain) echo 'upstream refused the request'; exit 22 ;;
  two) echo '{"error": {"message": "outer"}, "x": {"error": "inner"}}'; exit 22 ;;
  blank) echo '{"error": {"message": ""}, "x": {"error": "deep"}}'; exit 22 ;;
  html) echo 'curl: (22) The requested URL returned error: 502' >&2; printf '<html>\n<body>Bad Gateway</body>\n</html>\n'; exit 22 ;;
esac
STUB
chmod +x "$dir/bin/curl"
echo 'A draft.' > "$dir/draft.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { rm -f "$dir/sent"; out=$(env -u GEMINI_API_KEY PATH="$dir/bin:$PATH" STUB_DIR="$dir" "$@" bash "$pr" "$dir/draft.md" 2>&1); rc=$?; }

run PROOFREAD_KEY_ENV=none PROOFREAD_MODEL=llama3 PROOFREAD_ENDPOINT=http://localhost:11434/v1
check "a server that needs no key gets no Authorization header" '[ $rc -eq 0 ] && grep -q "^proofread: llama3" <<<"$out" && [ -e "$dir/sent" ] && ! grep -q Authorization "$dir/sent"'

run PROOFREAD_KEY_ENV='a b' 'a b=x'
check "a key variable name that is no name falls back" '[ $rc -eq 0 ] && [ ! -e "$dir/sent" ] && grep -q "^proofread: session model, because the key variable name" <<<"$out"'

run GEMINI_API_KEY=k STUB_MODE=empty
check "an answer with no notes falls back" '[ $rc -eq 0 ] && grep -q "^proofread: session model" <<<"$out"'

# Gemini wraps an error in an array, and curl adds its own line on stderr.
run GEMINI_API_KEY=k STUB_MODE=busy
check "an error inside an array gives its message" '[ $rc -eq 0 ] && grep -q "^proofread: session model, because .*failed: This model is currently experiencing high demand.$" <<<"$out"'
run GEMINI_API_KEY=k STUB_MODE=refused
check "an error object gives its message" '[ $rc -eq 0 ] && grep -q "failed: API key not valid.$" <<<"$out"'
run GEMINI_API_KEY=k STUB_MODE=quota
check "an error given as a string gives that string" '[ $rc -eq 0 ] && grep -q "failed: quota exceeded$" <<<"$out"'
run GEMINI_API_KEY=k STUB_MODE=plain
check "a body that is no JSON, with no curl line, gives its last line" '[ $rc -eq 0 ] && grep -q "failed: upstream refused the request$" <<<"$out"'
run GEMINI_API_KEY=k STUB_MODE=two
check "the first error in the body wins" '[ $rc -eq 0 ] && grep -q "failed: outer$" <<<"$out"'
run GEMINI_API_KEY=k STUB_MODE=blank
check "an empty error message gives way to the next one" '[ $rc -eq 0 ] && grep -q "failed: deep$" <<<"$out"'
run GEMINI_API_KEY=k STUB_MODE=html
check "a body that is no JSON gives curl's own line" '[ $rc -eq 0 ] && grep -q "failed: curl: (22) The requested URL returned error: 502$" <<<"$out"'

mkdir -p "$dir/nojq"; for t in bash awk mktemp chmod rm tail cat env; do ln -sf "$(command -v $t)" "$dir/nojq/$t"; done; ln -sf "$dir/bin/curl" "$dir/nojq/curl"
out=$(env -i PATH="$dir/nojq" GEMINI_API_KEY=k STUB_DIR="$dir" "$dir/nojq/bash" "$pr" "$dir/draft.md" 2>&1); rc=$?
check "a missing jq falls back" '[ $rc -eq 0 ] && grep -q "curl or jq is missing" <<<"$out"'

# A key set for Gemini never travels to another provider by default.
run GEMINI_API_KEY=k-gem PROOFREAD_MODEL=llama3 PROOFREAD_ENDPOINT=http://third-party.example/v1 PROOFREAD_KEY_ENV=
check "a custom endpoint with no key variable sends nothing" '[ $rc -eq 0 ] && [ ! -e "$dir/sent" ] && grep -q "^proofread: session model, because .*key variable" <<<"$out"'
run GEMINI_API_KEY=k-gem OTHER=k PROOFREAD_MODEL= PROOFREAD_ENDPOINT=http://third-party.example/v1 PROOFREAD_KEY_ENV=OTHER
check "a custom endpoint with no model sends nothing" '[ $rc -eq 0 ] && [ ! -e "$dir/sent" ] && grep -q "^proofread: session model, because .*model" <<<"$out"'

# A session that never filled in the plugin settings passes their placeholders.
run GEMINI_API_KEY=k-gem PROOFREAD_MODEL='${user_config.proofread_model}' PROOFREAD_ENDPOINT='${user_config.proofread_endpoint}' PROOFREAD_KEY_ENV='${user_config.proofread_key_env}'
check "unfilled setting placeholders mean the defaults" '[ $rc -eq 0 ] && grep -q "^proofread: gemini-4-hydrogen" <<<"$out" && grep -q "gemini-4-hydrogen" "$dir/sent"'

# A draft too big for a command-line argument still reaches the model whole.
cp "$dir/draft.md" "$dir/small.md"; awk 'BEGIN { for (i = 0; i < 4000; i++) print "A long draft line of about sixty characters, padded out here." }' > "$dir/draft.md"
run GEMINI_API_KEY=k
check "a draft over 200 KB is sent whole" '[ $rc -eq 0 ] && grep -q "^proofread: " <<<"$out" && grep -q "4000: A long draft" "$dir/sent"'
cp "$dir/small.md" "$dir/draft.md"

out=$(bash "$pr" "$dir/nothing-here.md" 2>&1); rc=$?
check "a missing draft file is bad usage" '[ $rc -eq 2 ] && grep -q usage <<<"$out"'

exit $fail
