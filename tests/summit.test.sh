#!/usr/bin/env bash
# summit.sh's own decisions beyond the approved examples: refused input, a
# missing data folder or repository, the line with and without a last
# session, and the record kept per repo.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
summit="$root/plugins/vicky-skills/scripts/summit.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/a" "$fx/b" "$fx/plain" "$fx/data"
git -C "$fx/a" init -q; git -C "$fx/b" init -q
export CLAUDE_PLUGIN_DATA="$fx/data" CLAUDE_PROJECT_DIR="$fx/a"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { bash "$summit" "$@" 2>"$fx/err"; }

check "no subcommand prints the usage and exits 2" 'run >/dev/null; [ $? = 2 ] && grep -q "usage: summit.sh" "$fx/err"'
check "record with one count is refused" 'run record 3 >/dev/null; [ $? = 2 ] && grep -q "usage: summit.sh record" "$fx/err"'
check "record with four counts is refused" 'run record 1 2 3 >/dev/null; [ $? = 2 ]'
check "a count that is not a whole number is refused" 'run record 3 x >/dev/null; [ $? = 2 ] && grep -q "whole numbers, got .x." "$fx/err" && [ ! -e "$fx/data/summit" ]'
check "a negative count is refused" 'run record -1 2 >/dev/null; [ $? = 2 ]'
check "show before any count says so and fails" 'run show >/dev/null; [ $? = 1 ] && grep -q "nothing counted yet" "$fx/err"'
check "today before any count fails quietly" '[ -z "$(run today)" ] && ! run today'
check "with no data folder it refuses" '[ "$(CLAUDE_PLUGIN_DATA= bash "$summit" record 1 1 2>&1)" = "summit: no plugin data folder" ]'
mkdir -p "$fx/plugins/cache/mkt/plug/1.0/scripts"; cp "$summit" "$fx/plugins/cache/mkt/plug/1.0/scripts/"
check "an installed copy with no data folder set finds its own" 'CLAUDE_PLUGIN_DATA= bash "$fx/plugins/cache/mkt/plug/1.0/scripts/summit.sh" record 2 1 >/dev/null && [ -n "$(ls "$fx/plugins/data/plug-mkt/summit")" ]'
check "outside a repository it refuses" 'CLAUDE_PROJECT_DIR="$fx/plain" bash "$summit" show 2>&1 | grep -q "not in a repository"'
check "record prints the summit line" '[ "$(run record 10 5)" = "summit: 30 days: +10 / −5, C" ]'
check "record keeps the day and counts" '[ "$(cat "$fx"/data/summit/*)" = "$(printf "%s\t10\t5" "$(date +%F)")" ]'
check "today prints the kept 30-day part" '[ "$(run today)" = "30 days: +10 / −5, C" ]'
check "with no last session the since counts are left out" '[ "$(run show 4 9)" = "summit: 30 days: +10 / −5, C" ]'
date -d '2 days ago' -Iseconds > "$fx/a/.git/springboard-last-session"
check "with a last session the since counts lead the line" '[ "$(run show 4 9)" = "summit: Since $(date -d "2 days ago" +%a): 4 opened, 9 closed · 30 days: +10 / −5, C" ]'
check "show with a bad since count is refused" 'run show 4 x >/dev/null; [ $? = 2 ]'
check "since prints the weekday of the last session" '[ "$(run since)" = "$(date -d "2 days ago" +%a)" ]'
date -d '7 days ago' -Iseconds > "$fx/a/.git/springboard-last-session"
check "a week ago shows as day and month" '[ "$(run since)" = "$(date -d "7 days ago" "+%-d %b")" ]'
check "since with no data folder still answers" '[ "$(CLAUDE_PLUGIN_DATA= bash "$summit" since)" = "$(date -d "7 days ago" "+%-d %b")" ]'
check "another repo keeps its own record" '[ "$(CLAUDE_PROJECT_DIR="$fx/b" bash "$summit" today)" = "" ] && CLAUDE_PROJECT_DIR="$fx/b" bash "$summit" record 1 1 >/dev/null && [ "$(run today)" = "30 days: +10 / −5, C" ] && [ "$(ls "$fx/data/summit" | wc -l)" = 2 ]'
check "a count kept yesterday does not count for today" 'sed -i "1s/^[0-9-]*/$(date -d yesterday +%F)/" "$fx"/data/summit/*; ! run today >/dev/null'
exit $fail
