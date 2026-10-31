#!/usr/bin/env bash
# What pr-guard must and must not stop, driven the way Claude Code drives it: a
# JSON payload on stdin, and an exit status. 0 means allowed, 2 means refused.
# The forge is stood in for by tiny tea, gh and plane scripts on PATH, and HOME
# points at a scratch folder so a real allowance is never spent.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pr-guard.sh"
[[ -x "$hook" ]] || { echo "pr-guard test: no hook at $hook" >&2; exit 1; }

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin" "$scratch/home/.claude"

cat >"$scratch/bin/tea" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "api user") echo '{"login":"me","full_name":"Me Myself"}' ;;
  "pulls list") cat "$PR_GUARD_TEST_PULLS" ;;
  *) exit 1 ;;
esac
EOF
cat >"$scratch/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2" == "pr list" ]] && cat "$PR_GUARD_TEST_GH"
EOF
# `plane show --json KEY` answers from tickets.json, a map of key to created_at.
# A key it does not hold fails, as the tracker does.
cat >"$scratch/bin/plane" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2" == "show --json" ]] || exit 1
jq -e --arg k "$3" '.[$k] // empty | {created_at: .}' "$PR_GUARD_TEST_TICKETS"
EOF
chmod +x "$scratch/bin/tea" "$scratch/bin/gh" "$scratch/bin/plane"
export PATH="$scratch/bin:$PATH" HOME="$scratch/home"
export PR_GUARD_TEST_PULLS="$scratch/pulls.json" PR_GUARD_TEST_GH="$scratch/gh.json"
export PR_GUARD_TEST_TICKETS="$scratch/tickets.json"
export CLAUDE_PLUGIN_OPTION_GUARD_PR=true
unset CLAUDE_PLUGIN_OPTION_GUARD_PR_IGNORE_HEADS
echo '{}' >"$scratch/tickets.json"

# One repository on a feature branch, one on main, one with a GitHub remote.
repo() {
  git init -q -b main "$scratch/$1"
  git -C "$scratch/$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init
  [[ $2 == main ]] || git -C "$scratch/$1" switch -q -c "$2"
}
repo feature feat/one
repo trunk main
repo hub feat/one
git -C "$scratch/hub" remote add origin https://github.com/o/r.git

failed=0

# SESSION goes in the payload as the session ID, TRANSCRIPT as the transcript path.
run() {
  local cwd=$1 tool=$2 input=$3
  printf '{"tool_name":"%s","cwd":"%s","session_id":"%s","transcript_path":"%s","tool_input":%s}' \
    "$tool" "$cwd" "${SESSION:-}" "${TRANSCRIPT:-}" "$input" \
    | "$hook" >/dev/null 2>&1 && echo 0 || echo $?
}
cmd() { printf '{"command":%s}' "$(printf '%s' "$1" | jq -Rs .)"; }

expect() {
  local want=$1 cwd=$2 command=$3 got
  got=$(run "$scratch/$cwd" Bash "$(cmd "$command")")
  [[ $got == "$want" ]] || { echo "FAIL want $want, got $got: ($cwd) $command"; failed=1; }
}

# Mine on feat/one, and somebody else's on their branch.
echo '[{"index":"7","head":"feat/one","author":"me"},{"index":"8","head":"theirs","author":"Someone Else"}]' >"$scratch/pulls.json"
echo '[{"number":7,"headRefName":"feat/one"}]' >"$scratch/gh.json"

# The option is off unless set to true or 1: everything passes.
CLAUDE_PLUGIN_OPTION_GUARD_PR='' expect 0 feature 'tea pr create --base main --head feat/two'
CLAUDE_PLUGIN_OPTION_GUARD_PR=false expect 0 feature 'gs stack submit'
CLAUDE_PLUGIN_OPTION_GUARD_PR=false expect 0 feature 'gh pr edit 7 --body "Co-Authored-By: Claude"'
CLAUDE_PLUGIN_OPTION_GUARD_PR=1 expect 2 feature 'tea pr create --base main --head feat/two'

# Untouched: reads, lists, and anything that is not a forge or git-spice.
expect 0 feature 'tea pr list'
expect 0 feature 'tea pulls 7 --comments'
expect 0 feature 'gh pr view 7 --comments'
expect 0 feature 'gs log short'
expect 0 feature 'git push'

# Updating the branch that already owns the open pull request.
expect 0 feature 'tea pr create --base main --head feat/one'
expect 0 feature 'gs branch submit'
expect 0 feature 'gh pr create --fill'

# A second pull request beside mine, by every door.
expect 2 feature 'tea pr create --base main --head feat/two'
expect 2 feature 'tea pulls create --head=feat/two'
expect 2 feature 'gh pr create --head feat/two'
expect 2 feature 'gs branch submit --branch feat/two'
expect 2 feature 'gs bs --branch feat/two'
expect 2 feature "tea api -X POST -d '{}' repos/o/r/pulls"
expect 2 trunk 'cd ../feature && tea pr create --head feat/two'

# Somebody else's open pull request is not mine to count.
echo '[{"index":"8","head":"theirs","author":"Someone Else"}]' >"$scratch/pulls.json"
expect 0 feature 'tea pr create --base main --head feat/two'

# Gitea names an author by full name when the account has one.
echo '[{"index":"9","head":"feat/one","author":"Me Myself"}]' >"$scratch/pulls.json"
expect 2 feature 'tea pr create --head feat/two'

# A stack, opened or submitted.
expect 2 feature 'gs stack submit'
expect 2 feature 'gs ss'
expect 2 feature 'gs upstack submit'
expect 2 feature 'gs branch create feat/two'
expect 2 feature 'gs bc feat/two'
expect 0 trunk 'gs branch create feat/two'

# With a session ID, one effort is one open pull request. Session A opens
# feat/a, so A's next pull request is refused while feat/a is open, and
# session B, another effort, opens its own.
echo '[{"index":"8","head":"theirs","author":"Someone Else"}]' >"$scratch/pulls.json"
SESSION=A expect 0 feature 'tea pr create --base main --head feat/a --title "Fix the cache (PLAT-1)"'
echo '[{"index":"10","head":"feat/a","author":"me","title":"Fix the cache (PLAT-1)"}]' >"$scratch/pulls.json"
SESSION=A expect 0 feature 'tea pr create --base main --head feat/a'
SESSION=A expect 2 feature 'tea pr create --base main --head feat/a2 --title "More (PLAT-9)"'
SESSION=A expect 2 feature "tea api -X POST -d '{}' repos/o/r/pulls"
SESSION=B expect 0 feature 'tea pr create --base main --head feat/b --title "Unrelated (GAME-2)"'

# An open pull request that names a ticket refuses another one naming it, from
# any session, whether the ticket is in the title or the branch name.
SESSION=C expect 2 feature 'tea pr create --base main --head feat/c --title "Two tickets (GAME-3, PLAT-1)"'
SESSION=C expect 2 feature 'tea pr create --base main --head plat-1-follow-up'
SESSION=C expect 0 feature 'tea pr create --base main --head feat/c --title "Other (PLAT-11)"'

# A second pull request from one session passes when it names a ticket filed
# before the session started (its transcript's first timestamp), and that no
# other open pull request names.
printf '%s\n' '{"type":"summary"}' '{"type":"user","timestamp":"2026-10-30T12:00:00.000Z"}' >"$scratch/transcript.jsonl"
echo '{"PLAT-5":"2026-10-29T09:00:00+01:00","PLAT-6":"2026-10-30T14:00:00+01:00"}' >"$scratch/tickets.json"
export TRANSCRIPT="$scratch/transcript.jsonl"
SESSION=A expect 0 feature 'tea pr create --base main --head feat/a5 --title "Older ticket (PLAT-5)"'
SESSION=A expect 2 feature 'tea pr create --base main --head feat/a6 --title "Filed mid-session (PLAT-6)"'
SESSION=A expect 2 feature 'tea pr create --base main --head feat/a7 --title "No ticket at all"'
SESSION=A expect 2 feature 'tea pr create --base main --head feat/a8 --title "Unknown to the tracker (PLAT-7)"'
SESSION=A expect 2 feature 'tea pr create --base main --head feat/a9 --title "Already in flight (PLAT-1)"'
TRANSCRIPT="$scratch/missing.jsonl" SESSION=A expect 2 feature 'tea pr create --base main --head feat/a10 --title "Older ticket (PLAT-5)"'
# No tracker on PATH: no exception.
mkdir "$scratch/notracker"
for t in jq git cat grep awk sed tr head date timeout comm sort cut mkdir rm basename dirname env bash tea; do
  ln -s "$(command -v "$t")" "$scratch/notracker/$t" 2>/dev/null
done
PATH="$scratch/notracker" SESSION=A expect 2 feature 'tea pr create --base main --head feat/a5b --title "Older ticket (PLAT-5)"'
unset TRANSCRIPT

# Once A's pull request is gone, A opens the next one.
echo '[]' >"$scratch/pulls.json"
SESSION=A expect 0 feature 'tea pr create --base main --head feat/a2 --title "More (PLAT-9)"'

# Heads under an ignored prefix never count, with or without a session. With
# the option empty, the same heads count.
echo '[{"index":"11","head":"depot/2","author":"me","title":"Depot changes (PLAT-1)"}]' >"$scratch/pulls.json"
echo '[{"number":12,"headRefName":"depot/2","title":"Depot"}]' >"$scratch/gh.json"
expect 2 feature 'tea pr create --base main --head feat/two'
expect 2 feature 'gh pr create --head feat/two'
export CLAUDE_PLUGIN_OPTION_GUARD_PR_IGNORE_HEADS="bot/ depot/"
expect 0 feature 'tea pr create --base main --head feat/two'
SESSION=D expect 0 feature 'tea pr create --base main --head feat/d --title "Fix (PLAT-1)"'
expect 0 feature 'gh pr create --head feat/two'
echo '[{"index":"13","head":"other/x","author":"me","title":"Other"}]' >"$scratch/pulls.json"
expect 2 feature 'tea pr create --base main --head feat/two'
unset CLAUDE_PLUGIN_OPTION_GUARD_PR_IGNORE_HEADS

# A forge that cannot answer is not a forge that said "none".
rm -f "$scratch/pulls.json"
expect 2 feature 'tea pr create --head feat/two'

# No AI credit in text sent to the forge, inline or through a body file.
printf 'Fixes the thing.\n' >"$scratch/clean.md"
printf 'Fixes the thing.\n\nGenerated with [Claude Code](https://claude.com/claude-code)\n' >"$scratch/footer.md"
printf 'Fixes the thing.\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' >"$scratch/trailer.md"
expect 0 feature "tea comment 7 \"\$(cat $scratch/clean.md)\""
expect 2 feature "tea comment 7 \"\$(cat $scratch/footer.md)\""
expect 2 feature "tea pr edit 7 -d \"\$(cat $scratch/trailer.md)\""
expect 2 feature "gh pr edit 7 --body-file $scratch/footer.md"
expect 2 feature "gh issue comment 7 -F $scratch/trailer.md"
expect 2 feature 'gh pr edit 7 --body "Done. Generated with Claude Code"'
expect 0 feature 'gh pr edit 7 --body "Generated with the parser"'

# GitHub's own stacks count the same way.
expect 2 hub 'gh stack submit --auto'
expect 2 hub 'gh stack link 7 8'
expect 2 hub 'gh stack add feat/two'
expect 2 hub 'gh stack init feat/one feat/two'
expect 0 hub 'gh stack view --json'
expect 0 hub 'gh stack sync'

# Only the user mints an allowance.
expect 2 feature 'touch ~/.claude/pr-guard-allow'
got=$(run "$scratch/feature" Write '{"file_path":"'"$HOME"'/.claude/pr-guard-allow","content":""}')
[[ $got == 2 ]] || { echo "FAIL Write of the allowance was not refused (exit $got)"; failed=1; }

# One allowance lets one refused command through, then it is spent.
touch "$HOME/.claude/pr-guard-allow"
expect 0 feature 'gs stack submit'
[[ ! -e $HOME/.claude/pr-guard-allow ]] || { echo "FAIL the allowance was not spent"; failed=1; }
expect 2 feature 'gs stack submit'

# On GitHub, git-spice never stacks, and the refusal leaves the allowance
# unspent for `gh stack`.
touch "$HOME/.claude/pr-guard-allow"
expect 2 hub 'gs stack submit'
expect 2 hub 'gs branch create feat/two'
[[ -e $HOME/.claude/pr-guard-allow ]] || { echo "FAIL git-spice on GitHub spent the allowance"; failed=1; }
expect 0 hub 'gh stack submit --auto'
expect 2 hub 'gh stack submit --auto'

# A moved config folder moves the allowance with it.
mkdir -p "$scratch/config"
touch "$scratch/config/pr-guard-allow"
CLAUDE_CONFIG_DIR="$scratch/config" expect 0 feature 'gs stack submit'
[[ ! -e $scratch/config/pr-guard-allow ]] || { echo "FAIL the moved allowance was not spent"; failed=1; }

# A missing jq turns the guard off with one line on stderr.
mkdir "$scratch/nojq"
for t in cat grep git env bash; do ln -s "$(command -v "$t")" "$scratch/nojq/$t"; done
msg=$(printf '{}' | PATH="$scratch/nojq" "$(command -v bash)" "$hook" 2>&1 >/dev/null)
[[ $msg == *"jq or git is missing"* ]] || { echo "FAIL missing jq printed: '$msg'"; failed=1; }

# Every refusal that takes an allowance spends exactly one.
allowed() { # cwd command
  touch "$HOME/.claude/pr-guard-allow"
  expect 0 "$1" "$2"
  [[ ! -e $HOME/.claude/pr-guard-allow ]] || { echo "FAIL the allowance was not spent: $2"; failed=1; rm -f "$HOME/.claude/pr-guard-allow"; }
}
echo '[{"index":"7","head":"feat/one","author":"me"}]' >"$scratch/pulls.json"
allowed feature 'tea pr create --base main --head feat/two'
allowed hub 'gh stack init feat/one feat/two'
allowed feature 'gs branch create feat/two'
rm -f "$scratch/pulls.json"
allowed feature 'tea pr create --head feat/two'
echo '[{"index":"10","head":"feat/a","author":"me","title":"Fix the cache (PLAT-1)"}]' >"$scratch/pulls.json"
SESSION=C allowed feature 'tea pr create --base main --head plat-1-again'
SESSION=A allowed feature 'tea pr create --base main --head feat/a3'

# A pull request this session never opened doesn't make the next one a second.
echo '[{"index":"14","head":"feat/z","author":"me","title":"Other work"}]' >"$scratch/pulls.json"
SESSION=A expect 0 feature 'tea pr create --base main --head feat/a4'

# A quoted branch is the branch, so updating mine passes.
echo '[{"index":"7","head":"feat/one","author":"me"}]' >"$scratch/pulls.json"
expect 0 feature 'tea pr create --base main --head "feat/one"'
expect 0 feature "tea pr create --base main --head 'feat/one'"
expect 2 feature 'tea pr create --base main --head "feat/two"'

# The repository a cd names, quoted or under ~, is the one judged.
expect 2 trunk 'cd "../feature" && tea pr create --head feat/two'
expect 2 trunk "cd '../feature' && tea pr create --head feat/two"
expect 2 trunk 'cd ~/../feature && tea pr create --head feat/two'
expect 0 trunk "cd $scratch/nowhere && tea pr create --head feat/two"
got=$(run "$scratch/gone" Bash "$(cmd 'tea pr create --head feat/two')")
[[ $got == 0 ]] || { echo "FAIL a cwd that is gone: exit $got"; failed=1; }

# A body file named through $HOME, ~ or the session ID is still read.
cp "$scratch/footer.md" "$HOME/f.md"; mkdir -p "$scratch/feature/sid"; cp "$scratch/footer.md" "$scratch/feature/sid/f.md"
expect 2 feature 'gh pr edit 7 --body-file $HOME/f.md'
expect 2 feature 'gh pr edit 7 --body-file ${HOME}/f.md'
expect 2 feature 'gh pr edit 7 --body-file ~/f.md'
SESSION=sid expect 2 feature 'gh pr edit 7 --body-file $CLAUDE_CODE_SESSION_ID/f.md'
SESSION=sid expect 2 feature 'gh pr edit 7 --body-file ${CLAUDE_CODE_SESSION_ID}/f.md'

# A repository's own bin/plane is the tracker it asks first.
mkdir -p "$scratch/feature/bin"
printf '%s\n' '#!/usr/bin/env bash' 'echo "{\"created_at\":\"2026-10-01T00:00:00Z\"}"' >"$scratch/feature/bin/plane"
chmod +x "$scratch/feature/bin/plane"
echo '[{"index":"10","head":"feat/a","author":"me","title":"Fix the cache (PLAT-1)"}]' >"$scratch/pulls.json"
TRANSCRIPT="$scratch/transcript.jsonl" SESSION=A expect 0 feature 'tea pr create --base main --head feat/a11 --title "Only bin/plane knows it (PLAT-77)"'
rm -rf "$scratch/feature/bin"

# Out of scope: a commit message file, and a raw read of the pulls API.
expect 0 feature "git commit -F $scratch/trailer.md"
expect 0 feature 'tea api repos/o/r/pulls'

if [[ $failed -eq 0 ]]; then echo "pr-guard test: all cases pass"; fi
exit "$failed"
