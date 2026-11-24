#!/usr/bin/env bash
# A branch that turns the Save button from grey to green. shots/ holds one
# real screenshot, taken on the branch: there is no picture of main.
set -eu
git init -q -b main .
c() { git -c user.name=eval -c user.email=eval@example.invalid commit -q "$@"; }
mkdir -p src shots
printf '.save { background: #888; }\n' > src/button.css
git add -A && c -m start
git switch -q -c green-save
printf '.save { background: #2a7; }\n' > src/button.css
echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' | base64 -d > shots/save-button.png
git add -A && c -m "Make the Save button green"
