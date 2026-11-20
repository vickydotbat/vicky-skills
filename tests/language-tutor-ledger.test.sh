#!/usr/bin/env bash
# Found by the mutation pass: ledger top <n> returns at most n types.
set -u
tutor="$(cd "$(dirname "$0")/.." && pwd)/plugins/language-tutor/scripts/tutor.py"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
t() { TUTOR_LANGUAGE=Italian TUTOR_STORE="$work" timeout 20 python3 "$tutor" "$@"; }
for ty in article gender tense spelling; do t ledger add "$ty" a b >/dev/null; done
n=$(t ledger top 3 | jq length)
# Found by the evals: a setting never saved reaches the script as its literal placeholder.
out=$(TUTOR_LANGUAGE='${user_config.tutor_language}' TUTOR_STORE="$work" timeout 20 python3 "$tutor" due 2>&1)
if echo "$out" | grep -qi "no language is set"; then echo "ok   an unsubstituted setting counts as blank"; else echo "FAIL an unsubstituted setting counts as blank"; exit 1; fi
if [ "$n" = 3 ]; then echo "ok   ledger top 3 caps four types at three"; else echo "FAIL ledger top 3 caps four types at three (got $n)"; exit 1; fi
