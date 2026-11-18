#!/usr/bin/env bash
# triggers.sh <fixed-point>: names each triggered opponent the diff since the
# fixed point calls for, one per line ("runaway: <file>", "security: <file>"),
# or prints "no trigger in the diff". It reads only added lines, and a
# Markdown file never triggers.
set -u
base=${1:?usage: triggers.sh <fixed-point>}
runaway='(http\.server|listen\(|serve\(|while (true|:)|setInterval|subprocess|Popen|spawn\(|nohup|systemctl|(podman|docker)[[:space:]]+run|daemon)'
security='(app\.(get|post|put|patch|delete)\(|router\.|@app\.route|req\.(body|query|params)|request\.(form|args|json)|innerHTML|eval\(|new Function|SELECT |INSERT |password|secret|token|permissions:|fetch\(|requests\.)'
found=0
while IFS= read -r f; do
  case $f in *.md) continue ;; esac
  added=$(git diff "$base"...HEAD -- "$f" | grep '^+' | grep -v '^+++')
  if grep -Eq "$runaway" <<<"$added"; then echo "runaway: $f"; found=1; fi
  if grep -Eq "$security" <<<"$added"; then echo "security: $f"; found=1; fi
done < <(git diff --name-only "$base"...HEAD)
[ "$found" = 1 ] || echo "no trigger in the diff"
