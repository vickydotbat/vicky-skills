#!/usr/bin/env bash
# shellcheck disable=SC2016 # the commands are literal text the hook reads, never run
# Approved examples for post-body-guard, ticked on the drafts page. The hook
# refuses a pull request or issue post whose body leaks a host or a path into
# this machine, or carries another item's text, and never asks.
# The history fixture holds every body and comment posted to this repository
# before the hook; refresh it with gh pr list and gh issue list --state all
# --json number,body,comments.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
hook="$root/plugins/vicky-skills/scripts/post-body-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
export USER=posttester HOME="$scratch/fakehome"
mkdir -p "$HOME"
mkrepo() { git init -q -b main "$scratch/$1"; git -C "$scratch/$1" remote add origin "$2"; }
mkrepo gh git@github.com:acme/widgets.git
mkrepo forge git@forge.example.org:team/app.git
opt=true hosts=""
# expect <exit> <label> <repo> <command>
expect() {
  local want=$1 label=$2 dir=$scratch/$3 cmd=$4 got
  got=$(jq -n --arg c "$cmd" --arg d "$dir" '{cwd:$d,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_POST_BODY=$opt CLAUDE_PLUGIN_OPTION_POST_GUARD_HOSTS=$hosts "$hook" 2>"$scratch/err" >/dev/null; echo $?)
  if [ "$got" = "$want" ]; then echo "ok   $label"; else echo "FAIL $label: want $want, got $got: $(head -3 "$scratch/err")"; fail=1; fi
}
says() { if grep -qF -- "$1" "$scratch/err"; then echo "ok   $2"; else echo "FAIL $2: stderr lacks $1"; fail=1; fi; }
body() { printf '%b' "$1" > "$scratch/body.md"; }
bf="$scratch/body.md"

# Given a pull request body file that holds terminal colour or link codes, as a pasted `tea pr view` or `gh pr view` does
# When the agent runs gh pr edit with that body file
# Then the command is refused before it posts, naming the line, and nothing reaches the forge
body '## Status\n\n\033]8;id=1;https://example.com/x\007link\033]8;;\007 done\n'
expect 2 "E1 terminal link codes are refused" gh "gh pr edit 306 --body-file $bf"
says "line 3" "E1 the refusal names the line"
body '## Status\n\n\033[1mbold\033[0m\n'
expect 2 "E1 terminal colour codes are refused" gh "gh pr edit 306 --body-file $bf"

# Given the same body with the codes stripped and no other hit
# When the agent runs gh pr edit with it
# Then it posts
body '## Status\n\nlink done\n'
expect 0 "E2 the same words without codes pass" gh "gh pr edit 306 --body-file $bf"

# Given a body whose first line is the heading of another pull request, such as # #1641 when posting to #306
# When the agent runs gh pr edit 306 with it
# Then the command is refused, naming both numbers
body '  # #1641 WIP: Another feature entirely\n\n## Status\n'
expect 2 "E3 another item's heading is refused" gh "gh pr edit 306 --body-file $bf"
says "#1641" "E3 names the body's number"; says "#306" "E3 names the target's number"

# Given a body that opens # #306, or opens with no number at all
# When the agent runs gh pr edit 306 with it
# Then it posts
body '# #306 ran.sh caps its output\n\n## Status\n'
expect 0 "E4 its own number passes" gh "gh pr edit 306 --body-file $bf"
body '## Status\n\nFixes the cap, as #1641 once did.\n'
expect 0 "E4 a body with no heading number passes" gh "gh pr edit 306 --body-file $bf"

# Given a checkout whose origin is on forge.example.org
# When the agent posts to a GitHub repository, through --repo, a body naming forge.example.org
# Then the command is refused, naming the host
body '## Status\n\nSee https://forge.example.org/team/app/pulls/3\n'
expect 2 "E5 the checkout's forge host posted to GitHub is refused" forge "gh pr edit 306 --repo acme/widgets --body-file $bf"
says "forge.example.org" "E5 names the host"
body '## Status\n\nThe runner on FORGE.EXAMPLE.ORG was down.\n'
expect 2 "E5 the host in capitals is refused" forge "gh pr comment 306 -R acme/widgets --body-file $bf"

# Given the same checkout
# When the agent posts to its own repository on forge.example.org a body naming forge.example.org
# Then it posts
body '## Status\n\nSee https://forge.example.org/team/app/pulls/3\n'
expect 0 "E6 the same forge passes" forge "tea pr edit 3 --description-file $bf"
expect 0 "E6 tea's inline description on the same forge passes" forge "tea pr edit 3 -d 'See forge.example.org/team/app'"

# Given the setting post_guard_hosts names forge.example.org
# When the agent posts to any repository a body naming forge.example.org, from any folder
# Then the command is refused, naming the host
hosts="other.example.net forge.example.org"
body '## Status\n\nMirrors forge.example.org nightly.\n'
expect 2 "E7 a listed host is refused from a GitHub checkout" gh "gh pr edit 306 --body-file $bf"
says "forge.example.org" "E7 names the host"
mkdir -p "$scratch/plain"
expect 2 "E7 a listed host is refused outside any checkout" plain "gh pr edit 306 -R acme/widgets --body-file $bf"
expect 2 "E7 a listed host is refused on its own forge too" forge "tea pr edit 3 -d 'Mirrors forge.example.org'"
hosts=""

# Given a body naming the home folder, another user's home or the Nix store
# When the agent posts it to a pull request or issue
# Then the command is refused, naming the line
h=home; ns=nix/store
body "## Status\n\nRan from $HOME/work\n"
expect 2 "E8 the home folder is refused" gh "gh pr edit 306 --body-file $bf"
says "line 3" "E8 names the line"
body "Logs in /$h/someone/logs\n"
expect 2 "E8 another user's home is refused" gh "gh issue comment 3 --body-file $bf"
body "Built /$ns/abc-foo/bin/foo\n"
expect 2 "E8 the Nix store is refused" gh "gh pr comment 306 --body-file $bf"
u=Users; body "The guard refuses /$h/<name>/ and /$u/<name>/ paths.\n"
expect 0 "E8 a placeholder path passes" gh "gh pr edit 306 --body-file $bf"

# Given a body naming ran.sh, checklist.py, SKILL.md and a link to github.com
# When the agent posts it to its own GitHub repository
# Then it posts
body '## Summary\n\nran.sh, checklist.py and SKILL.md change. See https://github.com/acme/widgets/pull/305 and docs.example.md.\n'
expect 0 "E9 file names and GitHub links pass" gh "gh pr edit 306 --body-file $bf"

# Given a post whose body comes from $(...), stdin, a here-doc or gh api -f body=
# When the agent runs it
# Then the command is refused, steering it to write the body to a file and pass --body-file
expect 2 "E10 a body from \$(...) is refused" gh 'gh pr edit 306 --body "$(cat notes.md)"'
says "--body-file" "E10 steers to --body-file"
expect 2 "E10 a body from backticks is refused" gh 'gh pr comment 306 -b "`cat notes.md`"'
expect 2 "E10 a body file of - is refused" gh 'cat notes.md | gh pr edit 306 --body-file -'
expect 2 "E10 a here-doc body is refused" gh "gh pr create --title t --body-file - <<'EOF'
text
EOF"
expect 2 "E10 gh api with a body field is refused" gh 'gh api repos/acme/widgets/issues/3/comments -f body=hello'
expect 2 "E10 a missing body file is refused" gh "gh pr edit 306 --body-file $scratch/nothing.md"
expect 0 "E10 an inline literal body with no hit passes" gh "gh pr comment 306 --body 'Merged, thanks.'"

# Given a leaking body
# When it goes through gh pr create, gh pr edit, gh pr comment, gh issue create, gh issue edit, gh issue comment, tea pr edit -d or --description, or tea comment
# Then each one is refused
body "Built /$ns/abc-foo\n"
leak="/$ns/abc-foo"
expect 2 "E11 gh pr create" gh "gh pr create --draft --title t --body-file $bf"
expect 2 "E11 gh pr edit" gh "gh pr edit 306 -F $bf"
expect 2 "E11 gh pr comment" gh "gh pr comment 306 --body-file=$bf"
expect 2 "E11 gh issue create" gh "gh issue create -t t -b '$leak'"
expect 2 "E11 gh issue edit" gh "gh issue edit 3 --body '$leak'"
expect 2 "E11 gh issue comment" gh "gh issue comment 3 --body-file $bf"
expect 2 "E11 tea pr edit -d" forge "tea pr edit 3 -d '$leak' </dev/null"
expect 2 "E11 tea pr edit --description" forge "tea pulls edit 3 --description='$leak'"
expect 2 "E11 tea comment" forge "tea comment 3 '$leak'"
expect 2 "E11 a post after cd into a checkout" plain "cd $scratch/gh && gh pr edit 306 --body-file $bf"
expect 2 "E11 a post behind env and timeout" gh "GH_PAGER= timeout 30 gh pr edit 306 --body-file $bf"
expect 0 "E11 gh pr view is no post" gh "gh pr view 306 --json body"

# Given any refusal above
# When the agent adds a marker or comment to the body or command
# Then it is still refused; only the setting guard_post_body set to false turns the hook off
body "Built /$ns/abc-foo # local-path-ok post-body-ok\n"
expect 2 "E12 a marker in the body is still refused" gh "gh pr edit 306 --body-file $bf"
expect 2 "E12 a comment on the command is still refused" gh "gh pr edit 306 --body-file $bf # post-body-ok"
opt=false; expect 0 "E12 the setting false lets it post" gh "gh pr edit 306 --body-file $bf"
opt=0;     expect 0 "E12 the setting 0 lets it post" gh "gh pr edit 306 --body-file $bf"
opt=true

# Given every pull request body and comment already posted to this repository
# When each is run through the hook as a post
# Then none is refused
n=0 bad=0
while IFS= read -r line; do
  jq -r .body <<<"$line" > "$bf"; num=$(jq -r .n <<<"$line"); n=$((n+1))
  got=$(jq -n --arg c "gh pr comment $num --body-file $bf" --arg d "$scratch/gh" '{cwd:$d,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_POST_BODY=true "$hook" 2>&1 >/dev/null) || { bad=$((bad+1)); echo "  refused #$num: $(head -1 <<<"$got")"; }
done < <(gzip -dc "$root/tests/fixtures/post-history.jsonl.gz")
if [ "$n" -gt 400 ] && [ "$bad" = 0 ]; then echo "ok   E13 none of $n posted bodies is refused"; else echo "FAIL E13 $bad of $n posted bodies refused"; fail=1; fi

exit $fail
