#!/usr/bin/env bash
set -eu
git init -q -b main .
printf 'Lantern shop: players buy and refill lanterns at the market (#12)\n' > CHANGELOG
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m 'Lantern shop: players buy and refill lanterns at the market (#12)'
