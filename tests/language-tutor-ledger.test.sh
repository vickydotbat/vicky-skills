#!/usr/bin/env bash
# Found by the mutation pass: ledger top <n> returns at most n types.
set -u
tutor="$(cd "$(dirname "$0")/.." && pwd)/plugins/language-tutor/scripts/tutor.py"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
t() { TUTOR_LANGUAGE=Italian TUTOR_STORE="$work" timeout 20 python3 "$tutor" "$@"; }
for ty in article gender tense spelling; do t ledger add "$ty" a b >/dev/null; done
n=$(t ledger top 3 | jq length)
if [ "$n" = 3 ]; then echo "ok   ledger top 3 caps four types at three"; else echo "FAIL ledger top 3 caps four types at three (got $n)"; exit 1; fi
