#!/usr/bin/env bash
# No session transcript ships in the repo. A transcript line carries keys no
# hand-written file uses (parentUuid, sandbox_instructions, a user message
# with a sessionId), and eval cases are where one would land when a case is
# built from a real session. The scan is proven on a planted fixture first.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
shaped='"parentUuid"[[:space:]]*:|"sandbox_instructions"|"sessionId"[[:space:]]*:[^,]*,[^}]*"type"[[:space:]]*:[[:space:]]*"user"'
scan() { grep -rlE "$shaped" "$@" 2>/dev/null; }
plant=$(mktemp -d); trap 'rm -rf "$plant"' EXIT
mkdir -p "$plant/evals/do/case"
echo '{"parentUuid":"a1","type":"user","message":{"content":"hi"}}' >"$plant/evals/do/case/prompt.jsonl"
echo '{"note":"a made-up stand-in for a session"}' >"$plant/evals/do/case/fixture.json"
check "a planted transcript line is found" '[ "$(scan "$plant")" = "$plant/evals/do/case/prompt.jsonl" ]'
check "a made-up fixture is not" '! scan "$plant/evals/do/case/fixture.json" >/dev/null'
found=$(cd "$root" && git ls-files -z | xargs -0 grep -lE "$shaped" -- 2>/dev/null | grep -v '^tests/no-transcripts.test.sh$')
check "no tracked file holds a transcript line${found:+: $found}" '[ -z "$found" ]'
exit $fail
