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
# Languages whose names differ only in symbols keep separate stores.
C="$work/sym"
TUTOR_LANGUAGE='C++' TUTOR_STORE="$C" timeout 20 python3 "$tutor" add a b >/dev/null 2>&1
got=$(TUTOR_LANGUAGE='C#' TUTOR_STORE="$C" timeout 20 python3 "$tutor" due 2>/dev/null | jq '.items | length' 2>/dev/null)
if [ "$got" = 0 ]; then ok "names that differ only in symbols keep separate stores"; else no "names that differ only in symbols keep separate stores (got $got)"; fi

# Eight adds at once keep eight cards with eight ids.
P="$work/par"
for i in 1 2 3 4 5 6 7 8; do TUTOR_LANGUAGE=Italian TUTOR_STORE="$P" timeout 20 python3 "$tutor" add "w$i" x >/dev/null 2>&1 & done; wait
ids=$(jq -r '.[].id' "$P/italian/cards.json" 2>/dev/null | sort -u | wc -l)
if [ "$ids" = 8 ]; then ok "concurrent adds lose no card"; else no "concurrent adds lose no card (kept $ids)"; fi

# A store file of the wrong shape refuses in one line.
for shape in '[1]' '[{"id":"c1"}]'; do
  mkdir -p "$work/shape/italian"; echo "$shape" > "$work/shape/italian/cards.json"
  out=$(TUTOR_LANGUAGE=Italian TUTOR_STORE="$work/shape" timeout 20 python3 "$tutor" due 2>&1); rc=$?
  if [ $rc = 3 ] && ! echo "$out" | grep -q Traceback; then ok "cards.json holding $shape refuses"; else no "cards.json holding $shape refuses (rc $rc)"; fi
done

# Learner text that starts with a dash is stored as text after --.
t ledger add spelling -- "-ing" "-ando" >/dev/null 2>&1
if t ledger list 2>/dev/null | jq -e 'map(.original) | index("-ing")' >/dev/null 2>&1; then ok "learner text starting with a dash is stored after --"; else no "learner text starting with a dash is stored after --"; fi
out=$(t due --limit abc 2>&1); rc=$?
if [ $rc = 3 ] && [ "$(echo "$out" | wc -l)" = 1 ]; then ok "a non-number limit refuses in one line"; else no "a non-number limit refuses in one line (rc $rc)"; fi

# The FSRS-4.5 schedule: a new card's first grade sets its wait.
F="$work/fsrs"
wait_of() { # wait_of <rating>: seconds from the review to the next due date
  local id; id=$(TUTOR_LANGUAGE=Italian TUTOR_STORE="$F" timeout 20 python3 "$tutor" add "x$1" y | jq -r .id)
  TUTOR_LANGUAGE=Italian TUTOR_STORE="$F" timeout 20 python3 "$tutor" grade "$id" "$1" | jq '((.due | fromdateiso8601) - (.last_review | fromdateiso8601))'
}
for pair in "again 600" "hard 86400" "good 259200" "easy 1296000"; do
  set -- $pair
  got=$(wait_of "$1")
  if [ "$got" = "$2" ]; then ok "a new card graded $1 waits $2 seconds"; else no "a new card graded $1 waits $2 seconds (got $got)"; fi
done
id=$(TUTOR_LANGUAGE=Italian TUTOR_STORE="$F" timeout 20 python3 "$tutor" add lapse y | jq -r .id)
lap=$(TUTOR_LANGUAGE=Italian TUTOR_STORE="$F" timeout 20 python3 "$tutor" grade "$id" again | jq -c '[.lapses, .reps, .difficulty <= 10, .difficulty >= 1]')
if [ "$lap" = '[1,1,true,true]' ]; then ok "a miss counts a lapse and keeps difficulty in 1 to 10"; else no "a miss counts a lapse and keeps difficulty in 1 to 10 (got $lap)"; fi

# The quiz brings back the four latest mistakes and asks half its cards as recall.
Q2="$work/q2"
for i in 1 2 3 4 5 6; do TUTOR_LANGUAGE=Italian TUTOR_STORE="$Q2" timeout 20 python3 "$tutor" ledger add "e$i" a b >/dev/null; done
for i in 1 2 3; do TUTOR_LANGUAGE=Italian TUTOR_STORE="$Q2" timeout 20 python3 "$tutor" add "c$i" y >/dev/null; done
qp=$(TUTOR_LANGUAGE=Italian TUTOR_STORE="$Q2" timeout 20 python3 "$tutor" quiz pick | jq -c '[([.items[] | select(.source=="error") | .type] | sort), ([.items[] | select(.format=="recall")] | length)]')
if [ "$qp" = '[["e3","e4","e5","e6"],2]' ]; then ok "a quiz takes the four latest mistakes and two of three cards as recall"; else no "a quiz takes the four latest mistakes and two of three cards as recall (got $qp)"; fi
# A pass after a miss still waits at least a day; difficulty stays at 10 or below after many misses.
f() { TUTOR_LANGUAGE=Italian TUTOR_STORE="$F" timeout 20 python3 "$tutor" "$@"; }
id=$(f add floor y | jq -r .id); f grade "$id" again >/dev/null
w=$(f grade "$id" hard | jq '((.due | fromdateiso8601) - (.last_review | fromdateiso8601))')
if [ "$w" -ge 86400 ] 2>/dev/null; then ok "a pass right after a miss waits at least a day"; else no "a pass right after a miss waits at least a day (got $w)"; fi
id=$(f add hard-word y | jq -r .id)
for _ in $(seq 1 12); do f grade "$id" again >/dev/null; done
d=$(f card "$id" | jq '.difficulty <= 10')
if [ "$d" = true ]; then ok "difficulty stays at 10 after twelve misses"; else no "difficulty stays at 10 after twelve misses"; fi

# What is due comes oldest first.
O="$work/order"; mkdir -p "$O/italian"
printf '%s\n' '[{"id":"c1","front":"new","back":"x","due":"2026-01-02T00:00:00Z","state":"new","stability":null,"difficulty":null,"reps":0,"lapses":0,"last_review":null},{"id":"c2","front":"old","back":"x","due":"2026-01-01T00:00:00Z","state":"new","stability":null,"difficulty":null,"reps":0,"lapses":0,"last_review":null}]' > "$O/italian/cards.json"
first=$(TUTOR_LANGUAGE=Italian TUTOR_STORE="$O" timeout 20 python3 "$tutor" due | jq -r '.items[0].front')
if [ "$first" = old ]; then ok "what is due comes oldest first"; else no "what is due comes oldest first (got $first)"; fi
# The reminder says "1 word" for a single due word.
O="$work/remind-one"; mkdir -p "$O"
TUTOR_LANGUAGE=Italian TUTOR_STORE="$O" timeout 20 python3 "$tutor" add uno one >/dev/null 2>&1
got=$(CLAUDE_PLUGIN_OPTION_TUTOR_REMIND=1 CLAUDE_PLUGIN_OPTION_TUTOR_LANGUAGE=Italian CLAUDE_PLUGIN_OPTION_TUTOR_STORE="$O" timeout 20 bash "$(dirname "$tutor")/remind.sh" 2>/dev/null | jq -r .systemMessage 2>/dev/null)
if [ "$got" = "Italian: 1 word due. Type /language-tutor:drill." ]; then echo "ok   the reminder says 1 word for one due word"; else echo "FAIL the reminder says 1 word for one due word (got: $got)"; fail=1; fi

exit $fail
