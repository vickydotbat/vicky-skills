#!/usr/bin/env bash
# Edges of human-voice's proofread script past its approved examples: a server
# that needs no key, a bad key variable name, a missing tool, an empty answer,
# and bad usage. A stub curl on PATH stands in for the network.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
pr="$here/../plugins/vicky-skills/skills/writing/human-voice/scripts/proofread.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/bin"
cat > "$dir/bin/curl" <<'STUB'
#!/usr/bin/env bash
: > "$STUB_DIR/sent"
for a in "$@"; do case "$a" in @*) [ -f "${a#@}" ] && { cat "${a#@}"; echo; } >> "$STUB_DIR/sent" ;; esac; done
cat > /dev/null
case "${STUB_MODE:-ok}" in
  ok) echo '{"choices":[{"message":{"content":"no changes"}}]}' ;;
  empty) echo '{"choices":[]}' ;;
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

mkdir -p "$dir/nojq"; for t in bash awk mktemp chmod rm tail cat env; do ln -sf "$(command -v $t)" "$dir/nojq/$t"; done; ln -sf "$dir/bin/curl" "$dir/nojq/curl"
out=$(env -i PATH="$dir/nojq" GEMINI_API_KEY=k STUB_DIR="$dir" "$dir/nojq/bash" "$pr" "$dir/draft.md" 2>&1); rc=$?
check "a missing jq falls back" '[ $rc -eq 0 ] && grep -q "curl or jq is missing" <<<"$out"'

out=$(bash "$pr" "$dir/nothing-here.md" 2>&1); rc=$?
check "a missing draft file is bad usage" '[ $rc -eq 2 ] && grep -q usage <<<"$out"'

exit $fail
