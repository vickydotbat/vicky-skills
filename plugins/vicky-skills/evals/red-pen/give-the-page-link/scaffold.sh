#!/usr/bin/env bash
set -eu
git init -q -b main .
printf '<button title="Save">Save</button>\n' > outfit.html
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
