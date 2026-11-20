#!/usr/bin/env bash
# summit.sh's own decisions beyond the approved examples: the usage, a missing
# repository, the stamp, a record kept per repo, a count that
# fails on one side only, and summit-obsidian.sh's rules.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
summit="$scripts/summit.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/a/docs/agents" "$fx/b/docs/agents" "$fx/plain"
git -C "$fx/a" init -q; git -C "$fx/b" init -q
export CLAUDE_PROJECT_DIR="$fx/a"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { bash "$summit" "$@" 2>"$fx/err"; }
auto() { echo '{}' | run auto; }
doc() { printf 'Summit count: `%s`\n' "$1" > "$fx/a/docs/agents/issue-tracker.md"; }

check "no subcommand prints the usage and exits 2" 'run >/dev/null; [ $? = 2 ] && grep -q "usage: summit.sh" "$fx/err"'
check "show before any count says so and fails" 'run show >/dev/null; [ $? = 1 ] && grep -q "nothing counted yet" "$fx/err"'
check "outside a repository it refuses, exit 2" 'CLAUDE_PROJECT_DIR="$fx/plain" bash "$summit" show 2>"$fx/err"; [ $? = 2 ] && grep -q "not in a repository" "$fx/err"'
doc 'echo 2 1'
rm -f "$fx/a/.git/summit-last-session"
check "auto prints nothing and exits 0" '[ -z "$(auto)" ] && [ ! -s "$fx/err" ]'
check "auto stamps when the session began" '[ -s "$fx/a/.git/summit-last-session" ]'
check "the next session counts since that stamp" 'auto; run show | grep -q "^summit: Since $(date +%a): 2 opened, 1 closed · 30 days: +2 / −1, C$"'
date -d '9 days ago' -Iseconds > "$fx/a/.git/summit-last-session"
check "a week or more ago shows as day and month" 'auto; run show | grep -q "^summit: Since $(date -d "9 days ago" "+%-d %b"): "'
check "the 30 days count from the date 30 days ago" 'doc "echo \$SUMMIT_SINCE 1 >&2; [ \$SUMMIT_SINCE = $(date -d "30 days ago" +%F) ] && echo 5 5 || echo 1 1"; auto; run show | grep -q "30 days: +5 / −5, B$"'
check "a since count that fails leaves only the 30 days" 'doc "case \$SUMMIT_SINCE in *T*) false ;; *) echo 3 0 ;; esac"; auto; [ "$(run show)" = "summit: 30 days: +3 / −0, C" ]'
check "a 30-day count that fails keeps nothing, and exits 0" 'doc "case \$SUMMIT_SINCE in *T*) echo 1 1 ;; *) exit 3 ;; esac"; auto && ! run show >/dev/null'
check "a count with a third number is refused" 'doc "echo 1 2 3"; auto; ! run show >/dev/null'
check "a negative count is refused" 'doc "echo -1 2"; auto; ! run show >/dev/null'
check "the doc line needs its backticks" 'printf "Summit count: echo 1 1\n" > "$fx/a/docs/agents/issue-tracker.md"; auto; ! run show >/dev/null'
check "no tracker doc keeps nothing, and exits 0" 'rm -f "$fx/a/docs/agents/issue-tracker.md"; auto && ! run show >/dev/null'
check "another repo keeps its own record" 'doc "echo 4 4"; auto; printf "Summit count: \x60echo 9 1\x60\n" > "$fx/b/docs/agents/issue-tracker.md"; echo "{}" | CLAUDE_PROJECT_DIR="$fx/b" bash "$summit" auto; run show | grep -q "+4 / −4" && CLAUDE_PROJECT_DIR="$fx/b" bash "$summit" show | grep -q "+9 / −1"'

obs="$scripts/summit-obsidian.sh"; v="$fx/vault"; mkdir -p "$v"
since=$(date -d '2 days ago' -Iseconds)
note() { printf -- '---\n%s\n---\n' "$2" > "$v/$1.md"; }
note "$(date -d '1 day ago' +%Y%m%d%H%M%S) New" "status: open"
note "$(date -d '3 days ago' +%Y%m%d%H%M%S) Older" "status: open"
note "$(date -d '40 days ago' +%Y%m%d%H%M%S) Closed today" "status: done
closed: $(date +%F)"
note "$(date -d '40 days ago' +%Y%m%d%H%M%S) Closed long ago" "status: done
closed: $(date -d '20 days ago' +%F)"
note "$(date -d '40 days ago' +%Y%m%d%H%M%S) Done undated" "status: done"
note "No stamp" "status: open"
touch -d '30 days ago' "$v/"*Older.md "$v/"*"long ago.md"
check "obsidian counts new notes by name and closed by date or change" '[ "$(SUMMIT_SINCE="$since" bash "$obs" "$v")" = "1 2" ]'
touch -d '30 days ago' "$v/"*undated.md
check "an undated done note counts only when it changed since" '[ "$(SUMMIT_SINCE="$since" bash "$obs" "$v")" = "1 1" ]'
check "obsidian with no folder fails" '! SUMMIT_SINCE="$since" bash "$obs" "$fx/none" 2>/dev/null'
check "obsidian with no time fails" '! bash "$obs" "$v" 2>/dev/null'
check "obsidian with a time it cannot read fails" '! SUMMIT_SINCE=someday bash "$obs" "$v" 2>/dev/null'
mkdir -p "$fx/empty"
check "obsidian with no notes counts none" '[ "$(SUMMIT_SINCE="$since" bash "$obs" "$fx/empty")" = "0 0" ]'
exit $fail
