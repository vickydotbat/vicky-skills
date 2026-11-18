#!/usr/bin/env bash
# triggers.sh <fixed-point> [pull request body file]: names the opponents the
# diff since the fixed point reaches, one per line: "fight: <angle>" or
# "out of reach: <angle>" for each core angle, then each triggered one
# ("runaway: <file>", "security: <file>"), or "no trigger in the diff".
# Intent and Standards always fight. Holds and Simplicity fight a diff that
# changes a file other than Markdown. Cause fights when a commit or the body
# claims a fix. Claims fights a body with a Proof section. Triggers read only
# added lines, and a Markdown file never triggers.
set -u
base=${1:?usage: triggers.sh <fixed-point> [body file]}
body=${2:-}
say() { if [ "$2" = 1 ]; then echo "fight: $1"; else echo "out of reach: $1"; fi; }
files=$(git diff --name-only "$base"...HEAD)
code=0
grep -qv '\.md$' <<<"$files" && code=1
fix=0
{ git log --format=%B "$base"..HEAD; [ -n "$body" ] && cat "$body" 2>/dev/null; } | grep -qiE '\b(fix(es|ed)?|bug|regression)\b' && fix=1
proof=0
[ -n "$body" ] && grep -qE '^## Proof' "$body" 2>/dev/null && proof=1
say intent 1
say standards 1
say holds "$code"
say simplicity "$code"
say cause "$fix"
say claims "$proof"
runaway='(http\.server|listen\(|serve\(|while (true|:)|setInterval|subprocess|Popen|spawn\(|nohup|systemctl|(podman|docker)[[:space:]]+run|daemon)'
security='(app\.(get|post|put|patch|delete)\(|router\.|@app\.route|req\.(body|query|params)|request\.(form|args|json)|innerHTML|eval\(|new Function|SELECT |INSERT |password|secret|token|permissions:|fetch\(|requests\.)'
found=0
while IFS= read -r f; do
  case $f in *.md | "") continue ;; esac
  added=$(git diff "$base"...HEAD -- "$f" | grep '^+' | grep -v '^+++')
  if grep -Eq "$runaway" <<<"$added"; then echo "runaway: $f"; found=1; fi
  if grep -Eq "$security" <<<"$added"; then echo "security: $f"; found=1; fi
done <<<"$files"
[ "$found" = 1 ] || echo "no trigger in the diff"
