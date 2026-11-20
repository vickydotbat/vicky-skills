#!/usr/bin/env bash
# tutor.py's behaviour beyond the approved examples: the cap on ledger top,
# settings it must read as blank, one store per language whatever its script,
# a refusal instead of a crash on bad input, and the working-directory
# settings file the eval scaffolds use.
set -u
tutor="$(cd "$(dirname "$0")/.." && pwd)/plugins/language-tutor/scripts/tutor.py"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
fail=0
ok() { echo "ok   $1"; }
no() { echo "FAIL $1"; fail=1; }
t() { TUTOR_LANGUAGE=Italian TUTOR_STORE="$work/it" timeout 20 python3 "$tutor" "$@"; }

for ty in article gender tense spelling; do t ledger add "$ty" a b >/dev/null; done
n=$(t ledger top 3 | jq length)
if [ "$n" = 3 ]; then ok "ledger top 3 caps four types at three"; else no "ledger top 3 caps four types at three (got $n)"; fi

out=$(TUTOR_LANGUAGE='${user_config.tutor_language}' TUTOR_STORE="$work/ph" timeout 20 python3 "$tutor" due 2>&1)
if echo "$out" | grep -qi "no language is set"; then ok "an unsubstituted setting counts as blank"; else no "an unsubstituted setting counts as blank"; fi

J="$work/cjk"
TUTOR_LANGUAGE=日本語 TUTOR_STORE="$J" timeout 20 python3 "$tutor" add 犬 dog >/dev/null 2>&1
got=$(TUTOR_LANGUAGE=한국어 TUTOR_STORE="$J" timeout 20 python3 "$tutor" due 2>/dev/null | jq '.items | length' 2>/dev/null)
if [ "$got" = 0 ]; then ok "two non-Latin languages keep separate stores"; else no "two non-Latin languages keep separate stores (Korean sees $got Japanese cards)"; fi

for args in "ledger top x" "due --limit -1" "quiz pick --max 0"; do
  # shellcheck disable=SC2086
  out=$(t $args 2>&1); rc=$?
  if [ $rc = 3 ] && ! echo "$out" | grep -q Traceback && [ "$(echo "$out" | wc -l)" = 1 ]; then ok "'$args' refuses in one line"; else no "'$args' refuses in one line (rc $rc: $(echo "$out" | tail -1))"; fi
done
mkdir -p "$work/bad/italian"; echo '{not json' > "$work/bad/italian/cards.json"
out=$(TUTOR_LANGUAGE=Italian TUTOR_STORE="$work/bad" timeout 20 python3 "$tutor" due 2>&1); rc=$?
if [ $rc = 3 ] && ! echo "$out" | grep -q Traceback; then ok "a damaged cards.json refuses, never crashes"; else no "a damaged cards.json refuses, never crashes (rc $rc)"; fi

W2="$work/cwd"; mkdir -p "$W2"
printf '%s\n' '{"tutor_language": "Italian", "tutor_store": "store"}' > "$W2/.language-tutor.json"
(cd "$W2" && env -u TUTOR_LANGUAGE -u TUTOR_STORE timeout 20 python3 "$tutor" add casa house >/dev/null 2>&1)
if [ -f "$W2/store/italian/cards.json" ]; then ok "with both settings blank, .language-tutor.json names them"; else no "with both settings blank, .language-tutor.json names them"; fi
(cd "$W2" && TUTOR_LANGUAGE=Spanish TUTOR_STORE="$work/env" timeout 20 python3 "$tutor" add casa house >/dev/null 2>&1)
if [ -f "$work/env/spanish/cards.json" ] && [ ! -d "$W2/store/spanish" ]; then ok "a set setting wins over .language-tutor.json"; else no "a set setting wins over .language-tutor.json"; fi
H2="$work/h"; mkdir -p "$H2" "$work/rel"
(cd "$work/rel" && HOME="$H2" TUTOR_LANGUAGE=Italian TUTOR_STORE='~/tutor' timeout 20 python3 "$tutor" add ciao hi >/dev/null 2>&1)
if [ -f "$H2/tutor/italian/cards.json" ] && [ ! -e "$work/rel/~" ]; then ok "a store path starting ~ means the home folder"; else no "a store path starting ~ means the home folder"; fi
out=$(cd "$work/rel" && TUTOR_LANGUAGE=Italian TUTOR_STORE=store timeout 20 python3 "$tutor" add ciao hi 2>&1); rc=$?
if [ $rc = 3 ] && echo "$out" | grep -q tutor_store && [ ! -e "$work/rel/store" ]; then ok "a relative tutor_store is refused"; else no "a relative tutor_store is refused (rc $rc)"; fi
exit $fail
