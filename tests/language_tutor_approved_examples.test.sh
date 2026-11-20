#!/usr/bin/env bash
# approved-spec: the examples the user approved for the Language tutor chart's
# core (LT-1, LT-13, LT-11, LT-2, LT-4, LT-12 and the shared refusal), at the
# seam the skills call: the language-tutor plugin's tutor.py. Examples that only
# show in the agent's reply are eval cases under plugins/language-tutor/evals.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tutor="$root/plugins/language-tutor/scripts/tutor.py"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
fail=0
ok() { echo "ok   $1"; }
no() { echo "FAIL $1"; fail=1; }
# t <language> <store> <args...>: the CLI as a skill calls it.
t() { local l=$1 s=$2; shift 2; TUTOR_LANGUAGE="$l" TUTOR_STORE="$s" timeout 20 python3 "$tutor" "$@"; }
S="$work/store"; mkdir -p "$S"

# LT-1: Given tutor_language is Italian and no store exists yet
# When the agent adds the word "il ramo" meaning "branch"
# Then the Italian store holds that word, due now
t Italian "$S" add "il ramo" "branch" >/dev/null 2>&1
if t Italian "$S" due 2>/dev/null | jq -e '.items | map(.front) | index("il ramo")' >/dev/null 2>&1; then ok "LT-1 a new word is due now"; else no "LT-1 a new word is due now"; fi

# LT-1: Given stores for Italian and Spanish both exist
# When tutor_language is Spanish and the agent asks what is due
# Then only Spanish words come back
t Spanish "$S" add "la rama" "branch" >/dev/null 2>&1
got=$(t Spanish "$S" due 2>/dev/null | jq -r '.items[].front' 2>/dev/null)
if [ "$got" = "la rama" ]; then ok "LT-1 each language keeps its own store"; else no "LT-1 each language keeps its own store (got: $got)"; fi

# LT-1: Given the tutor_store setting names a folder
# When the agent adds a word
# Then the word lands in that folder, not in the plugin's data folder
if grep -rqs "il ramo" "$S"; then ok "LT-1 the word lands in tutor_store"; else no "LT-1 the word lands in tutor_store"; fi

# LT-1: Given a word the user just graded "good"
# When the agent asks what is due straight after
# Then that word is not due
id=$(t Italian "$S" due 2>/dev/null | jq -r '.items[] | select(.front=="il ramo") | .id' 2>/dev/null)
t Italian "$S" grade "$id" good >/dev/null 2>&1
if [ -n "$id" ] && t Italian "$S" due >/dev/null 2>&1 && ! t Italian "$S" due 2>/dev/null | jq -e --arg i "$id" '.items | map(.id) | index($i)' >/dev/null 2>&1; then ok "LT-1 a word graded good is not due"; else no "LT-1 a word graded good is not due"; fi

# LT-1 and the shared rule: Given tutor_language is empty
# When any tutor command runs
# Then it says no language is set and stores nothing
E="$work/empty"; mkdir -p "$E"
for cmd in "add x y" "due" "ledger top" "quiz pick" "profile show"; do
  # shellcheck disable=SC2086
  out=$(t "" "$E" $cmd 2>&1); rc=$?
  if [ $rc -ne 0 ] && echo "$out" | grep -qi "no language is set" && [ -z "$(ls -A "$E")" ]; then ok "shared: '$cmd' refuses with no language"; else no "shared: '$cmd' refuses with no language (rc $rc: $out)"; fi
done

# LT-1 and the shared rule: Given tutor_store is empty
# When the agent adds a word
# Then it stores nothing and says to set tutor_store to a folder the user owns
H="$work/home"; mkdir -p "$H"
for cmd in "add x y" "ledger add agreement a b" "disagree text note"; do
  # shellcheck disable=SC2086
  out=$(HOME="$H" t Italian "" $cmd 2>&1); rc=$?
  if [ $rc -ne 0 ] && echo "$out" | grep -q "tutor_store" && [ -z "$(ls -A "$H")" ]; then ok "shared: '$cmd' refuses with no tutor_store"; else no "shared: '$cmd' refuses with no tutor_store (rc $rc: $out)"; fi
done

# LT-13: Given the tutor corrects an agreement mistake
# When the correction is given
# Then the ledger gains one line with the date, the type "agreement", the original and the fix
L="$work/ledger"; mkdir -p "$L"
t Italian "$L" ledger add agreement "la ragazzi" "i ragazzi" >/dev/null 2>&1
line=$(t Italian "$L" ledger list 2>/dev/null | jq -c '.[0]' 2>/dev/null)
if echo "$line" | jq -e --arg d "$(date -u +%F)" '.date==$d and .type=="agreement" and .original=="la ragazzi" and .fix=="i ragazzi"' >/dev/null 2>&1; then ok "LT-13 a correction adds one ledger line"; else no "LT-13 a correction adds one ledger line (got: $line)"; fi

# LT-13: Given the ledger holds three "agreement" lines and one "tense" line
# When a skill asks for the top three types
# Then it gets agreement 3 and tense 1, nothing padded, ties ordered by name
t Italian "$L" ledger add agreement "x" "y" >/dev/null 2>&1
t Italian "$L" ledger add agreement "x" "y" >/dev/null 2>&1
t Italian "$L" ledger add tense "a" "b" >/dev/null 2>&1
top=$(t Italian "$L" ledger top 3 2>/dev/null | jq -c . 2>/dev/null)
if [ "$top" = '[{"type":"agreement","count":3},{"type":"tense","count":1}]' ]; then ok "LT-13 top types count and order"; else no "LT-13 top types count and order (got: $top)"; fi
T2="$work/ties"; mkdir -p "$T2"
t Italian "$T2" ledger add tense a b >/dev/null 2>&1; t Italian "$T2" ledger add article a b >/dev/null 2>&1
ties=$(t Italian "$T2" ledger top 3 2>/dev/null | jq -r '.[].type' 2>/dev/null | tr '\n' ' ')
if [ "$ties" = "article tense " ]; then ok "LT-13 ties ordered by name"; else no "LT-13 ties ordered by name (got: $ties)"; fi

# LT-13: Given the ledger is empty
# When a skill asks for the top types
# Then it gets an empty list, not an error
Z="$work/zero"; mkdir -p "$Z"
if [ "$(t Italian "$Z" ledger top 3 2>/dev/null)" = "[]" ]; then ok "LT-13 an empty ledger gives an empty list"; else no "LT-13 an empty ledger gives an empty list"; fi

# LT-13: Given Spanish and Italian ledgers both hold lines
# When tutor_language is Italian and a skill asks for the top types
# Then no Spanish line is counted
t Spanish "$L" ledger add gender a b >/dev/null 2>&1
if t Italian "$L" ledger top 9 >/dev/null 2>&1 && ! t Italian "$L" ledger top 9 2>/dev/null | jq -e 'map(.type) | index("gender")' >/dev/null 2>&1; then ok "LT-13 ledgers stay apart per language"; else no "LT-13 ledgers stay apart per language"; fi

# LT-11: Given eight items are due and the error ledger holds two recent errors
# When the user types /quiz
# Then the quiz asks at most ten items, recall and cloze items first and multiple choice last, and includes both errors
Q="$work/quiz"; mkdir -p "$Q"
for i in 1 2 3 4 5 6 7 8; do t Italian "$Q" add "parola$i" "word$i" >/dev/null 2>&1; done
t Italian "$Q" ledger add agreement "la ragazzi" "i ragazzi" >/dev/null 2>&1
t Italian "$Q" ledger add tense "io andato" "io sono andato" >/dev/null 2>&1
pick=$(t Italian "$Q" quiz pick 2>/dev/null)
n=$(echo "$pick" | jq '.items | length' 2>/dev/null)
order=$(echo "$pick" | jq -r '[.items[].format] | map({recall:0,cloze:1,choice:2}[.]) | . == sort' 2>/dev/null)
errs=$(echo "$pick" | jq '[.items[] | select(.source=="error")] | length' 2>/dev/null)
if [ -n "$n" ] && [ "$n" -le 10 ] && [ "$n" -gt 0 ] && [ "$order" = true ] && [ "$errs" = 2 ]; then ok "LT-11 the quiz pick: capped, recall first, errors in"; else no "LT-11 the quiz pick: capped, recall first, errors in (n=$n order=$order errors=$errs)"; fi

# LT-11: Given the quiz ends
# When the agent reports
# Then each missed item comes back sooner in /drill
a=$(echo "$pick" | jq -r '[.items[] | select(.source=="card")][0].id' 2>/dev/null)
b=$(echo "$pick" | jq -r '[.items[] | select(.source=="card")][1].id' 2>/dev/null)
t Italian "$Q" grade "$a" again >/dev/null 2>&1; t Italian "$Q" grade "$b" good >/dev/null 2>&1
da=$(t Italian "$Q" card "$a" 2>/dev/null | jq -r .due 2>/dev/null); db=$(t Italian "$Q" card "$b" 2>/dev/null | jq -r .due 2>/dev/null)
if [ -n "$da" ] && [ -n "$db" ] && [ "$da" != null ] && [[ "$da" < "$db" ]]; then ok "LT-11 a missed item comes back sooner"; else no "LT-11 a missed item comes back sooner ($da vs $db)"; fi

# LT-11: Given nothing is due and the ledger holds no recent errors
# When the user types /quiz
# Then the agent says so in one line and starts no quiz
N="$work/none"; mkdir -p "$N"
out=$(t Italian "$N" quiz pick 2>/dev/null)
if echo "$out" | jq -e '(.items | length) == 0 and (.message | test("nothing"; "i")) and (.message | test("\n") | not)' >/dev/null 2>&1; then ok "LT-11 nothing to quiz says so"; else no "LT-11 nothing to quiz says so (got: $out)"; fi

# LT-2: Given fifteen words are due
# When the user types /drill
# Then the drill stops after ten and says five are left
D="$work/drill"; mkdir -p "$D"
for i in $(seq 1 15); do t Italian "$D" add "w$i" "m$i" >/dev/null 2>&1; done
out=$(t Italian "$D" due --limit 10 2>/dev/null)
if echo "$out" | jq -e '(.items|length)==10 and .left==5' >/dev/null 2>&1; then ok "LT-2 the drill stops at ten and counts the rest"; else no "LT-2 the drill stops at ten and counts the rest"; fi

# LT-2: Given nothing is due
# When the user types /drill
# Then the agent says nothing is due, in one line, and stops
out=$(t Italian "$N" due --limit 10 2>/dev/null)
if echo "$out" | jq -e '(.items|length)==0 and (.message|test("nothing is due";"i")) and (.message|test("\n")|not)' >/dev/null 2>&1; then ok "LT-2 nothing due says so"; else no "LT-2 nothing due says so"; fi

# LT-4: Given placement finished
# When the user opens the profile
# Then it shows a CEFR level, the date, and the can-do lines that set it
P="$work/profile"; mkdir -p "$P"
t Italian "$P" profile set-level A2 --line "Can communicate in simple and routine tasks" >/dev/null 2>&1
prof=$(t Italian "$P" profile show 2>/dev/null)
if echo "$prof" | jq -e --arg d "$(date -u +%F)" '.level=="A2" and .placed==$d and (.lines|index("Can communicate in simple and routine tasks"))' >/dev/null 2>&1; then ok "LT-4 the profile holds level, date and can-do lines"; else no "LT-4 the profile holds level, date and can-do lines (got: $prof)"; fi
if t Italian "$P" profile set-level Z9 >/dev/null 2>&1 || ! t Italian "$P" profile show >/dev/null 2>&1; then no "LT-4 a level outside A1 to C2 is refused"; else ok "LT-4 a level outside A1 to C2 is refused"; fi

# LT-12: Given the user disagrees with a grade
# When they say so
# Then the reply says the disagreement and their text were saved to the tutor_store folder, and no repo file changes
G="$work/grade"; mkdir -p "$G"
before=$(git -C "$root" status --porcelain)
t Italian "$G" disagree "Io sono andata" "B1 is too low" >/dev/null 2>&1
if grep -rqs "B1 is too low" "$G" && grep -rqs "Io sono andata" "$G" && [ "$(git -C "$root" status --porcelain)" = "$before" ]; then ok "LT-12 a disagreement is saved to tutor_store"; else no "LT-12 a disagreement is saved to tutor_store"; fi

exit $fail
