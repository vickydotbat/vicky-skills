#!/usr/bin/env bash
set -eu
# The plugin settings, as tutor.py reads them when both are blank.
printf '%s\n' '{"tutor_language": "Italian", "tutor_store": "store"}' > .language-tutor.json
mkdir -p store/italian
printf '%s\n' '[{"id":"c1","front":"il gatto","back":"the cat","due":"2026-01-01T00:00:00Z","state":"new","stability":null,"difficulty":null,"reps":0,"lapses":0,"last_review":null},{"id":"c2","front":"la finestra","back":"the window","due":"2026-01-01T00:00:00Z","state":"new","stability":null,"difficulty":null,"reps":0,"lapses":0,"last_review":null},{"id":"c3","front":"il cucchiaio","back":"the spoon","due":"2026-01-01T00:00:00Z","state":"new","stability":null,"difficulty":null,"reps":0,"lapses":0,"last_review":null}]' > store/italian/cards.json
printf '%s\n' '{"level":"A2","placed":"2026-11-01","lines":["Can communicate in simple and routine tasks requiring a simple and direct exchange of information on familiar and routine matters."]}' > store/italian/profile.json
