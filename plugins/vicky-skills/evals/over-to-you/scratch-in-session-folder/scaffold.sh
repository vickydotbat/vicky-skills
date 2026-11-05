#!/usr/bin/env bash
set -eu
git init -q -b main .
printf '<img src="logo.png" alt="Logo">\n' > login.html
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
