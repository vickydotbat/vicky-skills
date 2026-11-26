#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# shellcheck disable=SC2154 # fail is set by the fixture the fork fixture sources
# The fork tidy's edges: URL forms, the fork's default branch, what the tidy
# line and the sweep's line say, and the sweep's own safety: its scratch
# folder, a failed push, and a fork whose parent cannot be read after another.
set -u
# shellcheck source=lib/gitea-fork-fixture.sh
. "$(dirname "$0")/lib/gitea-fork-fixture.sh"
. "$root/plugins/vicky-skills/scripts/fork-tidy.sh"
for u in https://github.com/a/b.git https://github.com/a/b/ git@github.com:a/b.git ssh://git@github.com/a/b; do
  check "forge_of reads $u" '[ "$(forge_of "$u")" = "gh - a/b" ]'
done
check "forge_of says nothing for a host with no tea login" '[ -z "$(PATH="$dir/tea:$PATH" forge_of https://example.invalid/a/b.git)" ]'
printf '[{"name":"gt","url":"https://git.example.invalid","user":"me","ssh_host":"ssh.example.invalid"}]\n' > "$dir/tea-logins"
check "forge_of names the tea login for a Gitea URL" '[ "$(PATH="$dir/tea:$PATH" forge_of https://git.example.invalid/a/b.git)" = "tea gt a/b" ]'
check "forge_of matches a tea login's ssh host" '[ "$(PATH="$dir/tea:$PATH" forge_of ssh://git@ssh.example.invalid:2222/a/b.git)" = "tea gt a/b" ]'
check "each fake forge shadows the other forge's real tool, so no test reaches a real fork" '[ -x "$dir/gh/tea" ] && [ -x "$dir/tea/gh" ]'
check "url_parts says nothing for a local path" '[ -z "$(url_parts /srv/a/b.git)" ]'

fsetup; on_main; git -C "$dir/fork.git" config receive.denyDeleteCurrent ignore; echo "main MERGED $(git -C "$dir/fork.git" rev-parse main)" >> "$dir/prs"
run >/dev/null
check "a pull request from the fork's own main never deletes it" 'on fork.git main'
fsetup; fbranch fork.git feat; land feat; on_main
out=$(run)
check "the tidy line names the fork branch that went" 'seen "$out" | grep -q "Gone: fork/feat"'
fsetup; fbranch fork.git feat; echo "feat OPEN $(git -C "$dir/fork.git" rev-parse feat)" >> "$dir/prs"; on_main
out=$(run)
check "an open pull request's branch is not called unmerged" '! seen "$out" | grep -q unmerged'
fsetup; fbranch fork.git a1; fbranch fork.git b2; on_main
out=$(run)
check "two unmerged branches are both named" 'seen "$out" | grep -qF "Kept unmerged: a1, b2."'

fsetup
out=$(runsweep)
check "a sweep with nothing to do says so" '[ "$out" = "me/proj: nothing to tidy." ]'
fsetup; fbranch fork.git feat; land feat
out=$(runsweep)
check "the sweep names the branch that went" 'grep -qF "me/proj: Gone: feat." <<<"$out"'
fsetup; : > "$dir/repos"
out=$(runsweep); st=$?
check "with no forks the sweep says so and exits 1" '[ $st = 1 ] && grep -q "found no forks" <<<"$out"'
fsetup; mkdir -p "$dir/tmp"
TMPDIR="$dir/tmp" runsweep >/dev/null
check "the sweep removes its scratch folder" '[ -z "$(ls -A "$dir/tmp")" ]'
TMPDIR="$dir/nope" runsweep >/dev/null; st=$?
check "with no scratch folder the sweep exits 1" '[ $st = 1 ]'
fsetup; (cd "$dir/repo" && runsweep >/dev/null)
check "the sweep leaves the folder it runs in alone" '[ -z "$(git -C "$dir/repo" for-each-ref refs/f refs/p)" ]'
for side in fork.git origin.git; do
  fsetup; fbranch fork.git feat; land feat; git -C "$dir/$side" symbolic-ref HEAD refs/heads/nope
  out=$(runsweep)
  check "a $side with no default branch is not compared" 'on fork.git feat && grep -q "could not compare" <<<"$out"'
done
fsetup; main_moves; printf '#!/bin/sh\nexit 1\n' > "$dir/fork.git/hooks/pre-receive"; chmod +x "$dir/fork.git/hooks/pre-receive"
out=$(runsweep)
check "a refused push of the default branch is named" 'grep -q "could not be brought up" <<<"$out"'
# A second fork whose parent cannot be read never acts on the first fork's pull requests.
fsetup; fbranch fork.git feat; land feat; git clone -q --bare "$dir/fork.git" "$dir/two.git"
git config --file "$dir/gitconfig" url."$dir/two.git".insteadOf https://github.com/me/two.git
echo "me/two me gone/two" >> "$dir/repos"
runsweep >/dev/null
check "a fork whose parent cannot be read keeps a branch another fork's merge names" 'on two.git feat'

exit "$fail"
