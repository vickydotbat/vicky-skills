#!/usr/bin/env bash
# shellcheck disable=SC2016 # single quotes keep $VARS for the hook to expand
# post-body-guard.sh: the decisions the approved examples leave out: a missing
# python3, bad input, a command that is no post, gh api --input, and the
# setting off in the shell wrapper itself.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
hook="$root/plugins/vicky-skills/scripts/post-body-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
git init -q -b main "$scratch/r"; git -C "$scratch/r" remote add origin git@github.com:acme/widgets.git
run() { jq -n --arg c "$1" --arg d "$scratch/r" '{cwd:$d,tool_input:{command:$c}}' | env "${@:2}" "$hook" >/dev/null 2>"$scratch/err"; echo $?; }
check() { if grep -qF -- "$1" "$scratch/err"; then echo "ok   $2"; else echo "FAIL $2"; fail=1; fi; }
expect() { if [ "$1" = "$2" ]; then echo "ok   $3"; else echo "FAIL $3: want $1, got $2: $(head -2 "$scratch/err")"; fail=1; fi; }
ns=nix/store
hm=home
expect 0 "$(run 'ls -la')" "a command with no gh or tea passes"
expect 0 "$(run 'git log --oneline')" "git passes"
expect 0 "$(run 'gh pr list --state all')" "gh pr list is no post"
expect 2 "$(run 'gh api repos/acme/widgets/issues/3/comments --input body.json')" "gh api --input is refused"
expect 0 "$(run 'gh api repos/acme/widgets/pulls/3')" "gh api with no body passes"
expect 2 "$(run "tea issues create -t t -d '/$ns/x'")" "tea issues create with a leak is refused"
expect 2 "$(run "gh pr edit 3 --body 'unterminated")" "a post whose quoting does not parse is refused"
expect 0 "$(run "echo 'unterminated")" "a broken command that is no post passes"
expect 0 "$(run "gh pr edit 3 --body '/$ns/x'" CLAUDE_PLUGIN_OPTION_GUARD_POST_BODY=false)" "the setting off passes in the wrapper"
mkdir -p "$scratch/bin"; for t in bash cat grep jq env; do ln -s "$(command -v $t)" "$scratch/bin/$t"; done
expect 2 "$(run "gh pr edit 3 --body hi" PATH="$scratch/bin")" "without python3 a post is refused"
check python3 "the refusal names python3"
expect 0 "$(run "ls" PATH="$scratch/bin")" "without python3 a command that is no post passes"
git init -q -b main "$scratch/forge"; git -C "$scratch/forge" remote add origin git@forge.example.org:team/app.git
printf 'Built /%s/x\n' "$ns" > "$scratch/forge/host.md"; printf 'clean\n' > "$scratch/host.md"
printf '# #1641 Other\n' > "$scratch/other.md"
rin() { jq -n --arg c "$1" --arg d "$scratch/$2" '{cwd:$d,tool_input:{command:$c}}' | "$hook" >/dev/null 2>"$scratch/err"; echo $?; }
expect 2 "$(rin "cd forge && gh pr edit 3 -R acme/widgets --body-file host.md" .)" "a cd moves the body file with it"
expect 2 "$(rin "cd forge
gh pr edit 3 -R acme/widgets --body-file host.md" .)" "a cd on its own line moves the body file too"
expect 2 "$(rin "gh pr edit --unknown 306 -F $scratch/other.md" r)" "a boolean flag before the number leaves the number read"
printf '# #306 Own\n' > "$scratch/own306.md"
expect 0 "$(rin "gh pr edit -t 1641 306 -F $scratch/own306.md" r)" "a title value is never read as the number"
printf '# #3 Own\n' > "$scratch/own.md"
expect 2 "$(rin "tea pr edit --repo team/app 1641 --description-file $scratch/own.md" forge)" "tea reads the number after a repo value"
expect 2 "$(run "tea pr edit 3 --description-file $scratch/leak.md" )" "a missing tea description file is refused"
printf 'Built /%s/x\n' "$ns" > "$scratch/leak.md"
expect 2 "$(rin "tea pr edit 3 --description-file $scratch/leak.md" forge)" "a leaking tea description file is refused"
expect 2 "$(rin "tea comment 3 -d '/$ns/x'" forge)" "tea comment -d with a leak is refused"
expect 2 "$(run "gh pr comment 3 --body hi,/$ns/x")" "an unquoted body is read whole"
expect 2 "$(run "gh pr edit 3 --body")" "a body flag with no value is refused"
expect 0 "$(run 'gh api repos/acme/widgets/issues/3 -f title=hi')" "gh api with only other fields passes"
expect 2 "$(run 'gh api repos/acme/widgets/issues/3/comments --raw-field=body=hi')" "gh api --raw-field=body= is refused"
expect 0 "$(run 'echo api -f body=x')" "the word api without gh is no post"
expect 0 "$(run 'command -v gh')" "gh as the last word is no post"
expect 0 "$(run 'echo comment x; command -v tea')" "tea as the last word is no post"
expect 0 "$(run "echo \"gh 'x")" "a broken command that names gh and is no post passes"
expect 2 "$(run "gh pr edit 3 --body '/$ns/x'")" "a leak gets the refusal header"
check 'post-body-guard: refused' "the refusal opens with the guard's name"
check 'Rewrite the body with repo-relative paths' "the refusal says what to do"
expect 2 "$(run "gh pr edit 3 --body 'x")" "a post with broken quoting is refused"
check '--body-file' "a quoting refusal steers to --body-file"
expect 0 "$(rin "cd forge
cd ..
gh pr edit 3 -R acme/widgets --body-file host.md" .)" "a cd back out on its own line moves the body file back"
expect 0 "$(rin "cd forge && cd .. && gh pr edit 3 -R acme/widgets --body-file host.md" .)" "a cd back out after && moves the body file back"
expect 0 "$(run "cd && gh pr comment 3 --body hi")" "a bare cd is no crash"
expect 2 "$(rin "gh pr edit < /dev/null 306 -F $scratch/other.md" r)" "a redirect before the number leaves the number read"
expect 0 "$(rin "gh pr edit -B 1641 306 -F $scratch/own306.md" r)" "a gh-only value flag is never read as the number"
expect 0 "$(rin "tea pr list --state all '/$ns/x'" forge)" "tea pr list is no post, whatever its words"
expect 0 "$(run "gh pr comment 3 '/$ns/x' --body hi")" "gh takes no body from a second word, so it is not read"
expect 0 "$(run "cat > $scratch/notes.md <<'EOF'
Don't run gh pr view, run gh pr edit 3 --body \"\$(cat y)\" from /$ns/x
EOF")" "here-doc text is data, never a post"
expect 2 "$(run "cat > $scratch/notes.md <<'EOF'
plain
EOF
gh pr edit 3 --body '/$ns/x'")" "a post after a here-doc is still read"
printf 'clean\n' > "$scratch/clean.md"
expect 0 "$(run 'gh pr edit 3 --body-file $SCRATCH_DIR/clean.md' SCRATCH_DIR="$scratch")" "a body file under a set variable is read"
expect 2 "$(run 'gh pr edit 3 --body-file $NO_SUCH_VAR/clean.md')" "a body file under an unset variable is refused"
check 'literal path' "the refusal asks for the literal path"
expect 2 "$(run "printf x > $scratch/clean.md && gh pr edit 3 --body-file $scratch/clean.md")" "a body file written in the same command is refused"
check 'written earlier' "the refusal says the file is written in the same command"
expect 2 "$(run "echo x | tee $scratch/clean.md; gh pr edit 3 --body-file $scratch/clean.md")" "a body file written by tee in the same command is refused"
expect 0 "$(run "cat $scratch/clean.md && gh pr edit 3 --body-file $scratch/clean.md")" "a body file only read in the same command passes"
expect 0 "$(run "tea comment 3 \"\$(cat $scratch/clean.md)\"")" "tea comment with a clean cat of a file passes"
expect 2 "$(run "tea comment 3 \"\$(cat $scratch/leak.md)\"")" "tea comment with a leaking cat of a file is refused"
check 'names a path' "a cat of a file is read as the body"
expect 2 "$(run "gh pr edit 3 --body \"\$(<$scratch/leak.md)\"")" "a body read with \$(<file) is checked"
expect 2 "$(run "tea comment 3 \"\$(cat $scratch/leak.md | head)\"")" "a substitution that is more than a cat is refused"
check 'command substitution' "the refusal names the substitution"
check 'cat FILE' "the steer names tea's file route"
expect 2 "$(run "cat > $scratch/hd.md <<'EOF'
Built /$ns/x
EOF
gh pr edit 3 --body-file $scratch/hd.md")" "a here-doc written then posted is checked as the body"
check 'names a path' "the here-doc text is what is checked"
expect 0 "$(run "cat > $scratch/hd.md <<'EOF'
All clear
EOF
gh pr edit 3 --body-file $scratch/hd.md")" "a clean here-doc written then posted passes"
expect 2 "$(run "cat > $scratch/hd.md <<EOF
Built \$X
EOF
gh pr edit 3 --body-file $scratch/hd.md")" "an unquoted here-doc that expands is refused"
check 'written earlier' "an expanding here-doc is never read as text"
expect 2 "$(run "cat >> $scratch/clean.md <<'EOF'
more
EOF
gh pr edit 3 --body-file $scratch/clean.md")" "a here-doc appended to a body file is refused"
expect 2 "$(run "x=\"\$(echo y)\" gh pr edit 3 --body \"\$(cat <<'EOF'
hi
EOF
)\"; cat > $scratch/hd.md <<'EOF'
All clear
EOF
gh pr edit 3 --body-file $scratch/hd.md")" "a here-doc inside quotes trusts no here-doc text"
expect 0 "$(run "S=$scratch; gh pr edit 3 --body-file \$S/clean.md")" "a body file under a variable set in the command is read"
expect 2 "$(run "S=\$(mktemp -d); gh pr edit 3 --body-file \$S/clean.md")" "a variable set from a substitution is refused"
expect 0 "$(run "S=$scratch && cd \$S/r && gh pr edit 3 --body-file ../clean.md")" "a cd under a set variable moves the checkout"
expect 2 "$(run "tea comment 3 \"\$(cat \$NO_SUCH_VAR/x.md)\"")" "a cat of a path under an unset variable is refused"
check 'expand' "a cat under an unset variable is refused for the variable"
expect 0 "$(run 'tea comment 3 "$(cat ${SCRATCH_DIR}/clean.md)"' SCRATCH_DIR="$scratch")" "a cat of a path under a set variable is read"
expect 0 "$(run "tea comment 3 'Run \`make\` and \$HOME stays as typed'")" "backticks and a dollar in single quotes are text"
expect 0 "$(run "gh pr comment 3 --body \"Run \\\`make\\\` now\"")" "escaped backticks in double quotes are text"
expect 2 "$(run "tea comment 3 'Built /$ns/x in \`make\`'")" "a leak beside a code span is still refused"
expect 2 "$(run "tea comment 3 \"\$(cat '$scratch/leak.md')\"")" "a cat of a quoted path is read as the body"
check 'names a path' "the quoted path's file is what is checked"
expect 2 "$(run "tea comment 3 \"\$(cat '$scratch'/leak.md)\"")" "a cat of a partly quoted path is read as the body"
check 'names a path' "the partly quoted path's file is what is checked"
expect 0 "$(run "cat > $scratch/hd2.md <<'EOF'
Costs \$5
EOF
gh pr edit 3 --body-file $scratch/hd2.md")" "a quoted here-doc holding a dollar is read as text"
expect 0 "$(run "S=$scratch; cat > \$S/hd3.md <<'EOF'
All clear
EOF
gh pr edit 3 --body-file \$S/hd3.md")" "a here-doc written under a set variable is read as the body"
expect 2 "$(run "S=$scratch; sed -i s/a/b/ \$S/clean.md; gh pr edit 3 --body-file \$S/clean.md")" "a body file edited under a set variable in the same command is refused"
check 'written earlier' "the edit under a variable is seen"
expect 2 "$(run "gh pr edit 3 --title 'x' --body \"\$(date)\"")" "a substitution after a closed single quote is refused"
expect 2 "$(run "gh pr comment 3 --body x \\")" "a command ending in a backslash is refused as broken quoting"
check 'quoting' "the trailing backslash gets the quoting refusal"
expect 0 "$(run "gh pr comment 3 --body \"see /$hm/\\\$USER/x\"")" "an escaped dollar stays a dollar"
expect 2 "$(run "gh pr comment 3 --body \"at /$hm/\\\`u\\\`/x\"")" "an escaped backtick stays a backtick"
expect 2 "$(run "gh pr comment 3 --body \"it's \`date\`\"")" "an apostrophe inside double quotes opens no single quote"
expect 0 "$(run "gh pr edit 3 --title \"a\" --body 'Run \`make\`'")" "single quotes after a closed double quote still hold text"
printf 'clean\n' > "$scratch/d\$x.md"
expect 0 "$(run "gh pr edit 3 --body-file '$scratch/d\$x.md'")" "a body file whose name holds a dollar is read"
expect 2 "$(run "echo \"\$(cat <<'EOF'
hi
EOF
)\"; cat > $scratch/hd4.md <<'EOF'
Built /$ns/x
EOF
gh pr edit 3 --body-file $scratch/hd4.md")" "after a here-doc inside quotes, no here-doc text is trusted"
expect 2 "$(run "S=\$(mktemp -d); gh pr edit 3 --body-file \$S/clean.md")" "a variable set from a substitution is refused for the variable"
check 'expand' "the refusal names the variable"
expect 2 "$(run "S=\"\$(mktemp -d)\"; gh pr edit 3 --body-file \$S/clean.md")" "a variable set from a quoted substitution is refused"
check 'expand' "the quoted substitution's variable is named"
expect 2 "$(run "S=\`mktemp -d\`; gh pr edit 3 --body-file \$S/clean.md")" "a variable set from backticks is refused"
check 'expand' "the backtick variable is named"
printf '/%s/a\n' "$ns" "$ns" "$ns" "$ns" "$ns" "$ns" "$ns" "$ns" > "$scratch/many.md"
expect 2 "$(run "gh pr edit 3 --body-file $scratch/many.md")" "a body with eight leaks is refused"
check 'and 2 more' "the refusal shows six problems and counts the rest"
mkdir -p "$scratch/nogit"; for t in bash cat jq env python3; do ln -s "$(command -v $t)" "$scratch/nogit/$t"; done
expect 0 "$(run "gh pr comment 3 --body hi" PATH="$scratch/nogit")" "without git a clean post still passes"
expect 0 "$(run "gh pr comment 3 --repo acme/w --body hi" PATH="$scratch/nogit")" "without git a post with --repo still passes"
lk="/$hm/zed/x/"
expect 2 "$(run "gh pr create --title 'fix $lk' --body ok")" "a leaking title is refused"
expect 2 "$(run "tea pr create -t '$lk' -d ok")" "a leaking tea title is refused"
expect 2 "$(run "bash -c 'gh pr comment 1 --body \"$lk\"'")" "a post inside bash -c is refused"
expect 2 "$(run "eval \"gh pr comment 1 -b '$lk'\"")" "a post inside eval is refused"
expect 0 "$(run "git commit -m 'gh pr comment 1 --body text'")" "a commit message that names a post passes"
expect 0 "$(run "bash watch.sh 'gh pr checks 3 --json bucket'")" "a quoted read-only gh command passes"
expect 0 "$(run "for c in 'gh pr comment 1 -b x'; do echo \"\$c\"; done")" "post commands listed as a loop's data pass"
expect 2 "$(run "for b in a; do bash -c 'gh pr comment 1 -b x'; done")" "a post inside bash -c in a loop body is refused"
expect 2 "$(run "ssh host 'gh api repos/o/r/issues/1/comments -f body=x'")" "a gh api write inside ssh is refused"
expect 0 "$(run "ssh host 'gh api repos/o/r/pulls/1'")" "a gh api read inside ssh passes"
expect 0 "$(run "gh pr review 3 -c -b ok")" "a review with its comment switch and a clean body passes"
expect 2 "$(run "bash -c \"gh pr comment 1 -b 'x\"")" "a quoted post whose own quoting breaks is refused"
expect 0 "$(run "bash -c 'echo \"a b\"'")" "a quoted command with spaced words and no post passes"
expect 2 "$(run "bash -c \"bash -c 'gh pr comment 1 -b x'\"")" "a post two shells deep is refused"
expect 2 "$(run "gh pr comment 1 -b 'see /srv/zed/x'" USER=zed)" "a path through the user's name is refused"
expect 0 "$(run "B=hello; gh pr comment 1 --body \"\$B\"")" "a body from a clean set variable passes"
expect 0 "$(run "gh pr edit 3 --title '# #5 x'")" "a title that looks like a heading is no other item's text"
expect 0 "$(run "gh -R /$hm/zed/x/ api repos/o/r")" "a gh global flag's value is no api field"
expect 2 "$(run "B='$lk'; gh pr comment 1 --body \"\$B\"")" "a body from a set variable is checked"
expect 2 "$(run "gh pr comment 1 --body \"\$UNSET_X\"")" "a body from an unknown variable is refused"
expect 2 "$(run "gh pr comment 1 -b \"\$HOME/x\"")" "a body naming HOME through a variable is refused"
expect 0 "$(run "gh pr comment 1 -b 'costs \$5'")" "a single-quoted dollar is text"
expect 2 "$(run 'gh pr comment 1 --body $'\''/ho\155e/zed/x/'\''')" "an ANSI-C quoted body is refused as unreadable"
expect 2 "$(run "gh pr comment 1 -b'$lk'")" "a short body flag with its value glued on is read"
expect 2 "$(run "gh pr comment 1 -F$scratch/many.md")" "a short body-file flag with its value glued on is read"
expect 2 "$(run "gh -R a/b pr comment 1 --body '$lk'")" "a gh global flag before the verb hides no post"
expect 2 "$(run "gh pr comment 1 \\
 -b '$lk'")" "a backslash-newline keeps the next line's flags"
expect 2 "$(run "gh pr comment 1 --body-file /dev/stdin")" "a body file from stdin is refused"
expect 2 "$(run "G=gh; \$G pr comment 1 -b '$lk'")" "gh named by a variable is still read"
expect 2 "$(run "gh issue close 3 --comment '$lk'")" "a closing comment is checked"
expect 2 "$(run "gh pr review 3 -c -b '$lk'")" "a review's comment switch leaves its body read"
expect 2 "$(run "gh pr reopen 3 -c '$lk'")" "a reopening comment is checked"
expect 2 "$(run "gh pr merge 3 --squash -b '$lk'")" "a merge commit body is checked"
expect 2 "$(run "gh pr merge 3 --squash --subject '$lk'")" "a merge commit subject is checked"
expect 2 "$(run "gh release create v1 --notes '$lk'")" "release notes are checked"
expect 2 "$(run "gh issue new -b '$lk'")" "gh issue new is a post"
expect 2 "$(run "tea pr approve 1 '$lk'")" "a tea approval comment is checked"
expect 2 "$(run "gh api graphql -f query='mutation{addComment(input:{body:\"$lk\"})}'")" "a graphql field with a leak is refused"
expect 2 "$(run "gh pr comment 1 -b '/$hm//zed/x'")" "a doubled slash hides no home path"
expect 2 "$(run "gh pr comment 1 -b 'see /root/x'")" "root's home is a path into this machine"
expect 2 "$(run "gh pr comment 1 -b 'open file:///$hm/zed/x/y'")" "a file URL to a home path is refused"
expect 0 "$(run "gh pr comment 1 -b 'use ^[[:alpha:]] here'")" "a regex character class is no terminal code"
expect 2 "$(run "gh pr comment 1 -b 'see ^[[1m bold'")" "a caret-escaped colour code is a terminal code"
expect 0 "$(run "gh pr comment 1 -b 'see /usr/lib/x.so'" USER=lib)" "a short system user name is no path"
printf 'not json' | "$hook" >/dev/null 2>&1; rc=$?
expect 0 "$rc" "bad input passes without a traceback"
exit $fail
