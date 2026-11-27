#!/usr/bin/env bash
set -eu
git init -q -b main .
git remote add origin https://example.invalid/acme/widget.git
printf '# Widget\n\nRun the tests with: python3 -m unittest\n' > README.md
# The eval sandbox's PATH holds $HOME/.nix-profile/bin under the eval's own
# HOME. Link the backlog binary there, and never into a real home.
case "$HOME" in */claude-eval-*/home) ;; *) echo "scaffold: HOME is not an eval home" >&2; exit 1 ;; esac
mkdir -p "$HOME/.nix-profile/bin"
ln -sf "$(readlink -f "$(command -v backlog)")" "$HOME/.nix-profile/bin/backlog"
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
