#!/usr/bin/env bash
# The page has a light and a dark theme, and shots/ holds the light one only.
set -eu
git init -q -b main .
c() { git -c user.name=eval -c user.email=eval@example.invalid commit -q "$@"; }
mkdir -p src shots
printf '<!doctype html>\n<link rel="stylesheet" href="theme-light.css">\n<link rel="stylesheet" href="theme-dark.css" media="(prefers-color-scheme: dark)">\n<button class="save">Save</button>\n' > src/index.html
printf '.save { background: #888; color: #000; }\n' > src/theme-light.css
printf '.save { background: #444; color: #fff; }\n' > src/theme-dark.css
git add -A && c -m start
git switch -q -c green-save
printf '.save { background: #2a7; color: #000; }\n' > src/theme-light.css
printf '.save { background: #185; color: #fff; }\n' > src/theme-dark.css
echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' | base64 -d > shots/save-button-light.png
git add -A && c -m "Make the Save button green"
