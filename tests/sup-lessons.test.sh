#!/usr/bin/env bash
# The command sup gives for its Lessons part, run on a scratch repo: one line
# per Engraved trailer since the point, and none from a plain commit or an
# older one.
set -u
sup="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/sup/SKILL.md"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
gi() { git -C "$scratch" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
cmd=$(grep -o "git log --since=<that point> [^\`]*" "$sup")
[ -n "$cmd" ] || { echo "FAIL sup gives no Lessons command"; exit 1; }
git init -q "$scratch"
GIT_COMMITTER_DATE='2026-01-01T10:00:00' gi commit -q --allow-empty -m "old rule" -m "Engraved: an old snag"
gi commit -q --allow-empty -m "first rule" -m "Engraved: a red check"
gi commit -q --allow-empty -m "plain work"
gi commit -q --allow-empty -m "second rule" -m "Engraved: a wrong claim"
out=$(cd "$scratch" && eval "${cmd//<that point>/2026-06-01}")
if [ "$(wc -l <<<"$out")" = 2 ] && grep -q "Engraved: a red check" <<<"$out" && grep -q "Engraved: a wrong claim" <<<"$out"; then
  echo "ok   two lessons since the point, one line each"
else echo "FAIL want two Engraved lines, got: $out"; fail=1; fi
gi commit -q --allow-empty -m "only plain"
out=$(cd "$scratch" && eval "${cmd//<that point>/2099-01-01}")
[ -z "$out" ] && echo "ok   no lesson since the point prints nothing" || { echo "FAIL want nothing, got: $out"; fail=1; }
exit $fail
