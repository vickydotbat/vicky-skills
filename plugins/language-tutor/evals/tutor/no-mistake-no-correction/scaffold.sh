#!/usr/bin/env bash
set -eu
# The plugin settings, as tutor.py reads them when both are blank.
printf '%s\n' '{"tutor_language": "Italian", "tutor_store": "store"}' > .language-tutor.json
mkdir -p store/italian
printf '%s\n' '[]' > store/italian/cards.json
printf '%s\n' '{"level":"A2","placed":"2026-11-01","lines":["Can communicate in simple and routine tasks requiring a simple and direct exchange of information on familiar and routine matters."]}' > store/italian/profile.json
