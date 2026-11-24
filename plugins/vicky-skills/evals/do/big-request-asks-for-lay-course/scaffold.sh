#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p src tests
printf 'export function farewell(name) {\n  return `Bye, ${name}`;\n}\n' > src/greet.js
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
