#!/usr/bin/env bash
# prose_strip empties the value of a title, message or body flag in a command
# that carries prose, reading quotes as the shell does, and leaves the rest.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../plugins/vicky-skills/scripts/prose-strip.sh
. "$root/plugins/vicky-skills/scripts/prose-strip.sh"
fail=0
is() { local got; got=$(prose_strip "$2"); if [ "$got" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got [$got], want [$3]"; fail=1; fi; }
same() { is "$1" "$2" "$2"; }
is "a pull request title and body are emptied" 'gh pr create --title "a b" -b "c"' 'gh pr create --title "" -b ""'
is "a tag message is emptied" "git tag -m 'x y' v1" "git tag -m \"\" v1"
is "a tea pull request title is emptied" 'tea pr create --title "x"' 'tea pr create --title ""'
is "an issue comment body is emptied" 'gh issue comment 3 --body "x"' 'gh issue comment 3 --body ""'
same "a tea list is no prose carrier" 'tea pr list --title "x"'
same "another tool's commit is no prose carrier" 'foo commit -m "x"'
same "another tool's pr create is no prose carrier" 'foo pr create -t "x"'
same "another tea is no prose carrier" 'tee pr create -t "x"'
same "gh pr merge is no prose carrier" 'gh pr merge 5 -t "x"'
is "a flag with = is emptied" 'gh pr create --title="a b" --draft' 'gh pr create --title="" --draft'
same "a flag with = elsewhere stays" 'foo --title="a b"'
same "a flag with = holding a substitution stays" 'git commit --message="$(id)"'
is "only the flag's own value is emptied" 'gh pr create --title "x" more' 'gh pr create --title "" more'
is "a new segment starts its own command" 'git status; gh pr create -t "x"' 'git status; gh pr create -t ""'
same "a flag after the segment ends is not the carrier's" 'git commit -a; foo -m "x"'
is "an escaped quote stays inside the value" 'git commit -m "a \"b\" c" -q' 'git commit -m "" -q'
same "an escaped quote outside a carrier stays as written" 'echo "a \"b\""'
is "a dollar sign that runs nothing is prose" 'git commit -m "price $5"' 'git commit -m ""'
is "a bracket is prose" 'git commit -m "a (b)"' 'git commit -m ""'
is "a quoted flag still reads as the flag" 'git commit "-m" "x"' 'git commit "-m" ""'
same "an escaped space stays" 'echo a\ b'
same "an unquoted value holding a substitution stays" 'git commit -m x$(id)'
same "an unquoted value holding a backtick stays" 'git commit -m a`id`'
same "a double-quoted value holding a backtick stays" 'git commit -m "a`id`"'
is "an unquoted dollar sign that runs nothing is prose" 'git commit -m price$5' 'git commit -m ""'
is "an unquoted bracket ends the segment" 'git commit -m a(b)' 'git commit -m ""(b)'
same "unbalanced quotes print the command unchanged" 'git commit -m "open'
same "a flag inside another quoted string is not read" "echo 'foo -m \"' ; gh pr merge 5 ; echo '\"'"
same "ssh's -t is no message" "ssh host -t 'gh pr merge 5'"
same "ANSI-C quoting prints the command unchanged" "git commit -m \$'x\\'' ; gh pr merge 1"
exit $fail
