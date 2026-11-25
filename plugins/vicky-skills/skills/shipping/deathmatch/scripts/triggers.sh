#!/usr/bin/env bash
# triggers.sh <fixed-point> [pull request body file]: names the opponents the
# diff since the fixed point reaches, one per line: "fight: <angle>" or
# "out of reach: <angle>" for each core angle, then each triggered one
# ("runaway: <file>", "security: <file>"), or "no trigger in the diff".
# Intent and Standards always fight. Holds and Simplicity fight a diff that
# changes a file other than Markdown. Cause fights when a commit or the body
# claims a fix. Claims fights a body with a Proof section. Triggers read only
# added lines, and a Markdown file never triggers.
# triggers.sh --rerun <verdict commit> [body file]: a follow-up since a verdict.
# When the diff since it changes only Markdown, Intent, Standards and Claims
# can fight, and Standards reads only the commits since the verdict: in this
# kind of repo the skills are Markdown, and Standards is the angle that reads
# their rules. With no commit since the verdict, only Intent fights. Each "out
# of reach" line then ends with its reason in brackets.
set -u
rerun=0
[ "${1:-}" = --rerun ] && { rerun=1; shift; }
base=${1:?usage: triggers.sh [--rerun] <fixed-point> [body file]}
body=${2:-}
say() {
  if [ "$2" = 1 ] && [ -n "${4:-}" ]; then echo "fight: $1 ($4)"
  elif [ "$2" = 1 ]; then echo "fight: $1"
  elif [ "$rerun" = 1 ]; then echo "out of reach: $1 ($3)"
  else echo "out of reach: $1"; fi
}
files=$(git diff --name-only "$base"...HEAD)
code=0
[ -n "$files" ] && grep -qv '\.md$' <<<"$files" && code=1 # mutant-ok: grep -vv inverts once, as -v does
fix=0
{ git log --format=%B "$base"..HEAD; [ -n "$body" ] && cat "$body" 2>/dev/null; } | grep -qiE '\b(fix(es|ed)?|bug|regression)\b' && fix=1
proof=0
[ -n "$body" ] && grep -qE '^## Proof' "$body" 2>/dev/null && proof=1
std=1 scope=
if [ "$rerun" = 1 ]; then
  scope="only the commits since $base"
  # Nothing new since the verdict: every angle but Intent rests on it.
  if [ -z "$files" ]; then
    say intent 1
    for a in standards holds simplicity cause claims; do say "$a" 0 "no commit since the verdict for $base"; done
    echo "no trigger in the diff"; exit 0
  fi
fi
say intent 1
say standards "$std" "" "$scope"
say holds "$code" "no file other than Markdown changed"
say simplicity "$code" "no file other than Markdown changed"
say cause "$fix" "no commit or body line claims a fix"
say claims "$proof" "the body has no Proof section"
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
