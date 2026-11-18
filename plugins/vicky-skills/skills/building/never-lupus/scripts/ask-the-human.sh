#!/usr/bin/env bash
# A reproduction loop for steps only a person can do. Copy it, write the steps, run it.
# The person follows the prompts in their terminal. The answers print as KEY=VALUE at the end.
set -euo pipefail

step() { printf '\n>>> %s\n' "$1"; read -r -p "    [Enter when done] " _; }
ask() { printf '\n>>> %s\n' "$2"; read -r -p "    > " "$1"; }

# Write the steps here. Leave signing in as a step: an answer prints in the clear.
step "Open the page that shows the bug."
ask SAW "What did you see?"

printf '\nSAW=%s\n' "$SAW"
