#!/usr/bin/env bash
# approved-spec: a machine's load decides no mutant's verdict. Each check runs
# the runner on a copy of the repo, with a small probe.sh as its subject.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
. "$root/tests/lib/mutation-probe.sh"

# Given a mutant its tests cannot tell from the real script
# When the pass runs while every core is busy, and its tests take twice their usual time
# Then the mutant survives, as it does on an idle machine
# Every mutant's run takes 12 s of waiting, as a test starved of CPU does.
setup ml1 ': "$x"' '[ $n -gt 1 ] && sleep 12; bash "$hook"'
out=$(pass)
check "ML1 a busy machine kills no mutant" 'grep -qE "^script $probe: 0/[1-9]" <<<"$out"'

# Given a mutant that makes the script wait forever without working
# When the pass runs
# Then the pass stops its test, counts the mutant killed, and names it hung in its output
setup ml3 '[ "$x" = 1 ] || sleep 1000 # mutant-ok delete: the line only sleeps' 'bash "$hook"'
out=$(MUTATE_HOOKS_CEILING=4 pass)
check "ML3 a mutant that waits forever is named hung" \
  'grep -qE "^script $probe: ([0-9]+)/\1$" <<<"$out" && grep -qE "^hung $probe:3: " <<<"$out"'
exit $fail
