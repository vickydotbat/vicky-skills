#!/usr/bin/env bash
# parked-state.sh gives each .todo line a verdict from the state of the pull
# requests and tickets it names, so sup offers no finished work. gh and tea are
# stubs on PATH and tickets are files, so no test reaches a real tracker.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/plugins/vicky-skills/skills/housekeeping/sup/scripts/parked-state.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if grep -qxF -- "$2" <<<"$3"; then echo "ok   $1"; else echo "FAIL $1: want line '$2' in: $3"; fail=1; fi; }
mkdir -p "$dir/bin" "$dir/t"
cat > "$dir/bin/tea" <<EOF
#!/usr/bin/env bash
n=\${2##*/}; cat "$dir/pr-\$n" 2>/dev/null
EOF
cat > "$dir/bin/gh" <<EOF
#!/usr/bin/env bash
cat "$dir/gh-\$3" 2>/dev/null
EOF
chmod +x "$dir/bin/"*
repo() { local r="$dir/$1"; git init -q -b main "$r"; git -C "$r" remote add origin "$2"
  mkdir -p "$r/docs/agents"; echo "| Read, whole | \`cat $dir/t/<key>\` |" > "$r/docs/agents/issue-tracker.md"; echo "$r"; }
run() { (cd "$1" && PATH="$dir/bin:$PATH" bash "$script" 2>&1); }
echo '{"merged":true,"state":"closed"}' > "$dir/pr-10"
echo '{"merged":false,"state":"open"}' > "$dir/pr-11"
echo '{"merged":false,"state":"closed"}' > "$dir/pr-12"
printf 'ABC-1 t\nstate: Done\n' > "$dir/t/ABC-1"
printf 'ABC-2 t\nstate: In Progress\n' > "$dir/t/ABC-2"
printf 'ABC-3 t\nno state line\n' > "$dir/t/ABC-3"
printf 'ABC-4 t\n  status: done, said a comment\nstate: In Progress\n' > "$dir/t/ABC-4"
r=$(repo forge git@forge.example:o/r.git)
cat > "$r/.todo" <<'EOF'
# springboard start
N1 press Done on the page
# springboard end
- Mark !10 ready, then time the sweep (ABC-2)
- Ship it after !10 (ABC-1)
- Rebase !11 (ABC-2)
- Answer the journal interview (Journal #25)
- Read ABC-3 again
- Close !12
- Redo !12 (ABC-2)
- Read ABC-4
- Chart the rewrite
- Tidy ABC-2 alone
- Land !11, then !11 again
- Handoff: !11 (2026-01-01)
EOF
out=$(run "$r")
check "a merged pull request with its ticket still open is its own verdict" "merged-ticket-open: - Mark !10 ready, then time the sweep (ABC-2) [!10 merged, ABC-2 open]" "$out"
check "every ref finished is done" "done: - Ship it after !10 (ABC-1) [!10 merged, ABC-1 done]" "$out"
check "an open pull request keeps the line open" "open: - Rebase !11 (ABC-2) [!11 open, ABC-2 open]" "$out"
check "a bare #n is never read as a pull request" "unread: - Answer the journal interview (Journal #25) [#25 unread]" "$out"
check "a ticket with no state line is unread" "unread: - Read ABC-3 again [ABC-3 unread]" "$out"
check "a pull request closed unmerged keeps its line" "open: - Close !12 [!12 closed]" "$out"
check "a closed unmerged pull request beside an open ticket is never called merged" "open: - Redo !12 (ABC-2) [!12 closed, ABC-2 open]" "$out"
check "a status line in a comment, indented, is not the ticket's state" "open: - Read ABC-4 [ABC-4 open]" "$out"
check "a line with no ref says so" "no ref: - Chart the rewrite" "$out"
check "an open ticket with no pull request is open" "open: - Tidy ABC-2 alone [ABC-2 open]" "$out"
check "a ref named twice is read once" "open: - Land !11, then !11 again [!11 open]" "$out"
if grep -qE 'springboard|N1|Handoff' <<<"$out"; then echo "FAIL springboard and Handoff lines are skipped: $out"; fail=1; else echo "ok   springboard and Handoff lines are skipped"; fi
rm "$dir/pr-10"
check "a pull request it cannot read keeps the line" "unread: - Ship it after !10 (ABC-1) [!10 unread, ABC-1 done]" "$(run "$r")"
g=$(repo gh https://github.com/o/r.git)
echo '- Land PR 7 (ABC-1)' > "$g/.todo"; echo MERGED > "$dir/gh-7"
check "on GitHub gh reads the pull request" "done: - Land PR 7 (ABC-1) [!7 merged, ABC-1 done]" "$(run "$g")"
n=$(repo none git@forge.example:o/n.git)
out=$(run "$n"); code=$?
[ -z "$out" ] && [ "$code" = 0 ] && echo "ok   no .todo prints nothing and exits 0" || { echo "FAIL no .todo prints nothing and exits 0: $code $out"; fail=1; }
mkdir -p "$dir/plain"; out=$(run "$dir/plain"); code=$?
[ -z "$out" ] && [ "$code" = 0 ] && echo "ok   outside a repo it prints nothing and exits 0" || { echo "FAIL outside a repo it prints nothing and exits 0: $code $out"; fail=1; }
exit $fail
