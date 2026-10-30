#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Planning pages take
# answers in the browser". Each check is named after its example.
set -u
here="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/lay-course"
script="$here/scripts/answer-page.py"
scratch=$(mktemp -d); trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$scratch"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Starts the page from a spec and sets $url; its answer lands in $scratch/out.
start() {
  printf '%s' "$1" > "$scratch/page.json"
  : > "$scratch/err"
  python3 "$script" "$scratch/page.json" --no-open --timeout "${2:-30}" > "$scratch/out" 2> "$scratch/err" &
  pid=$!
  for _ in $(seq 50); do
    url=$(grep -o 'http://[^ ]*' "$scratch/err") && break
    sleep 0.1
  done
}

wide='<svg width="3000" height="100" xmlns="http://www.w3.org/2000/svg"><rect width="3000" height="100"/></svg>'
course='[{"key": "K-1", "kind": "away team", "title": "Read docs", "needs": "nothing"},
 {"key": "K-2", "kind": "anomaly", "title": "Pick one", "needs": "your answer"},
 {"key": "K-3", "kind": "star", "title": "Build A", "needs": "your approval of its examples"},
 {"key": "K-4", "kind": "star", "title": "Build B", "needs": "nothing"}]'

start "{\"title\": \"Two charts\", \"charts\": [{\"name\": \"Wide\", \"svg\": \"${wide//\"/\\\"}\"}, {\"name\": \"Small\", \"svg\": \"<svg width=\\\"200\\\"></svg>\"}]}"
two=$(curl -s "$url"); kill $pid 2>/dev/null
check "each chart is drawn full width at its natural size, the wide one shrinks to fit the window, a click zooms in, and the page renders correctly" \
  '[ "$(grep -c "<div class=chart onclick=\"zoom(this)\"><svg" <<<"$two")" = 2 ] && grep -qF ".chart svg{max-width:100%;height:auto" <<<"$two" && grep -qF "function zoom(c)" <<<"$two" && grep -qF "c.clientWidth*n" <<<"$two" && grep -qF "width=\"3000\"" <<<"$two" && ! grep -q "body{[^}]*overflow" <<<"$two"'

start "{\"title\": \"Course\", \"charts\": [{\"name\": \"A\", \"svg\": \"<svg></svg>\"}], \"course\": $course}"
page=$(curl -s "$url")
check "a warp's course page shows the chart and a table with each ticket, its kind and what it needs from me, each row kept by default" \
  'grep -q "<svg></svg>" <<<"$page" && [ "$(grep -c "name=keep value=\"K-[1-4]\" checked" <<<"$page")" = 4 ] && grep -qF "<td>anomaly</td><td>your answer</td>" <<<"$page" && grep -qF "Engage</button>" <<<"$page"'

curl -s -d keep=K-1 -d keep=K-2 -d keep=K-4 -d note= "${url}answer" > /dev/null; wait $pid
check "unticking one row and pressing Engage sends that ticket back as trimmed, and the other three as kept" \
  'python3 -c "import json,sys; c=json.load(open(sys.argv[1]))[\"course\"]; sys.exit(c != {\"K-1\": \"kept\", \"K-2\": \"kept\", \"K-3\": \"trimmed\", \"K-4\": \"kept\"})" "$scratch/out"'

question='{"title": "Council", "questions": [{"key": "Q1", "ask": "Which?", "options": ["One", "Two", "Three"], "pick": 1}]}'
start "$question"
asked=$(curl -s "$url")
check "a question with three options and the agent's pick has the pick already selected" \
  'grep -qF "value=\"Two\" checked" <<<"$asked" && ! grep -qF "value=\"One\" checked" <<<"$asked" && ! grep -qF "value=\"Three\" checked" <<<"$asked"'

sent=$(curl -s --data-urlencode q.Q1=other --data-urlencode "note.Q1=Neither, ask me later" "${url}answer"); wait $pid; code=$?
check "choosing Other with a note and pressing Send gives the agent \"other\" with that note" \
  'python3 -c "import json,sys; a=json.load(open(sys.argv[1]))[\"answers\"][\"Q1\"]; sys.exit(a != {\"option\": \"other\", \"note\": \"Neither, ask me later\"})" "$scratch/out"'

check "after Send the page says it was sent, the listener stops, and the agent echoes each answer in chat before going on" \
  'grep -qF "Sent. Back to chat." <<<"$sent" && [ "$code" = 0 ] && ! kill -0 $pid 2>/dev/null && grep -qi "echo each answer in chat" "$here/STAR-CHART.md"'

start "$question" 1; wait $pid; code=$?
check "a page nobody answers for an hour stops its listener, and the agent asks the same questions in chat" \
  '[ "$code" != 0 ] && grep -qF "no answer within" "$scratch/err" && grep -qF "3600.0" "$script" && grep -qi "ask the same questions in chat" "$here/STAR-CHART.md"'

start "$question"
port=${url##*:}; port=${port%/}
bound=$(ss -ltnH "sport = :$port" 2>/dev/null | awk "{print \$4}"); kill $pid 2>/dev/null
check "a waiting page can't be reached from another machine on the network" \
  '[ "$bound" = "127.0.0.1:$port" ]'
exit $fail
