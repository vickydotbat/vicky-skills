#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034,SC2329 # each check is a string check() evals: it reads code, a, b, c1-c3, told and silent there
# approved-spec: the examples approved for the chart "Merged-branch-guard after
# 302", stars M1, M2 and M3. Each check is named after its example. The guard
# runs on real repositories, merged the way a forge squash-merges and deletes
# the branch, with fake gh and tea and a git that counts origin's calls.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/merged-branch-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
export CLAUDE_PLUGIN_DATA="$scratch/data" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; sed 's/^/     /' "$scratch/out" "$scratch/err" 2>/dev/null; fail=1; fi; }
gi() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }
realgit=$(command -v git)
mkdir "$scratch/bin"
# git logs each ls-remote to $scratch/calls, then runs the real git.
printf '#!/usr/bin/env bash\n[ "$1" = ls-remote ] && echo ls-remote >> "%s/calls"\nexec "%s" "$@"\n' "$scratch" "$realgit" > "$scratch/bin/git"
# tea: $TEA_USER is "fail", "empty" or a login; the user has no open pull request.
cat > "$scratch/bin/tea" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2" = "api user" ]; then
  case $TEA_USER in fail) exit 1 ;; empty) echo '{}' ;; *) echo "{\"login\":\"$TEA_USER\"}" ;; esac
  exit 0
fi
[ "$1 $2" = "pulls list" ] && { echo '[{"head":"other","author":"you"}]'; exit 0; }
exit 1
EOF
chmod +x "$scratch/bin/git" "$scratch/bin/tea"
export PATH="$scratch/bin:$PATH" TEA_USER=me
n=0
session() { n=$((n + 1)); jq -n --arg d "$1" --arg s "start$n" '{hook_event_name:"SessionStart",source:"startup",session_id:$s,cwd:$d}' |
  "$hook" >"$scratch/out" 2>"$scratch/err"; }
cmd() { jq -n --arg d "$1" --arg c "$2" --arg s "$3" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:$s,cwd:$d,tool_input:{command:$c}}' |
  "$hook" >"$scratch/out" 2>"$scratch/err"; }
told() { jq -e --arg w "$1" '.hookSpecificOutput.additionalContext | contains($w)' "$scratch/out" >/dev/null 2>&1; }
silent() { [ ! -s "$scratch/out" ]; }
age() { find "$CLAUDE_PLUGIN_DATA" -type f -exec touch -d '11 minutes ago' {} +; }

# make <dir> <url>: a bare origin, a clone on topic pushed, its url shown as <url>.
make() {
  local rem="$1.rem" seed="$1.seed"
  git init -q --bare -b main "$rem"
  git clone -q "$rem" "$seed" 2>/dev/null; gi "$seed" commit -q --allow-empty -m one; gi "$seed" push -q origin main
  git clone -q "$rem" "$1" 2>/dev/null
  gi "$1" config remote.origin.url "$2"; gi "$1" config url."$rem".insteadOf "$2"
  gi "$1" checkout -q -b topic; echo a > "$1/a"; gi "$1" add a; gi "$1" commit -q -m topic-a
  gi "$1" push -q -u origin topic 2>/dev/null
}
merge() { local seed="$1.seed"
  gi "$seed" fetch -q origin topic; gi "$seed" merge -q --squash FETCH_HEAD >/dev/null
  gi "$seed" commit -q -m "topic (#1)"; gi "$seed" push -q origin main; gi "$seed" push -q origin --delete topic 2>/dev/null; }

# M1: a Gitea checkout on a merged branch.
g="$scratch/gitea"; make "$g" https://gitea.example/owner/repo; merge "$g"
TEA_USER=fail session "$g"
check "M1 E1: given a checkout on a Gitea remote stands on a merged branch, and tea api user fails, when a session starts there, then the hint says to ask the forge, and never that no pull request is open" \
  'told "Ask the forge which pull request of yours is open here" && ! told "No pull request of yours is open here"'
TEA_USER=empty session "$g"
check "M1 E2: given the same checkout, and tea api user answers with no login, when a session starts there, then the hint says to ask the forge" \
  'told "Ask the forge which pull request of yours is open here"'
TEA_USER=me session "$g"
check "M1 E3: given the same checkout, tea api user answers, and the user has no open pull request, when a session starts there, then the hint says no pull request is open, as today" \
  'told "No pull request of yours is open here"'

# M2: a branch live at the first command, merged later.
m="$scratch/mid"; make "$m" https://github.com/owner/mid
cmd "$m" ls m2
check "M2 setup: the first command on a live branch is not told" 'silent'
: > "$scratch/calls"
cmd "$m" ls m2; cmd "$m" ls m2; cmd "$m" ls m2
check "M2 E3: given the branch is still live, when several commands run in that checkout within 10 minutes of the last check, then origin is asked no more than once in those 10 minutes" \
  '[ "$(wc -l < "$scratch/calls")" -le 1 ]'
merge "$m"; age
cmd "$m" ls m2; code=$?
check "M2 E1: given a session's first command in a checkout ran while its branch was live, and the branch then merges, when a later command runs there 10 minutes or more after the last check, then the command runs, and the agent is told the branch is finished" \
  '[ $code = 0 ] && told "is finished"'
age; cmd "$m" ls m2; a=$(wc -c < "$scratch/out"); cmd "$m" ls m2; b=$(wc -c < "$scratch/out")
check "M2 E2: given the agent was told once in that checkout this session, when more commands run there, then nothing more is said" '[ "$a" = 0 ] && [ "$b" = 0 ]'

# M2 E4: origin can't answer at the first command, and its record says live.
u="$scratch/unreach"; make "$u" https://github.com/owner/unreach
gi "$u" config url."$scratch/nowhere".insteadOf https://github.com/owner/unreach
gi "$u" config --unset url."$u.rem".insteadOf
cmd "$u" ls m4
check "M2 E4 setup: origin can't answer and the record says live, so nothing is said" 'silent'
merge "$u"; gi "$u" config --unset url."$scratch/nowhere".insteadOf; gi "$u" config url."$u.rem".insteadOf https://github.com/owner/unreach
age; cmd "$u" ls m4
check "M2 E4: given origin could not answer at the first command, when a later command runs past the 10 minutes, and origin now says the branch is gone, then the agent is told the branch is finished" 'told "is finished"'

# M3: what counts as a commit or push.
three="$scratch/three"; make "$three" https://github.com/owner/three; merge "$three"
cmd "$three" 'git log --grep commit' m3a; code=$?
check "M3 E1: given a checkout on a merged branch, when the session's first command there is git log --grep commit, then the command runs, and the agent gets the hint, not a refusal" \
  '[ $code = 0 ] && told "is finished"'
cmd "$three" 'git status # push later' m3b; c1=$?
cmd "$three" 'git log --oneline -- push' m3c; c2=$?
check "M3 E2: given the same checkout, when the command is git status # push later or git log --oneline -- push, then the command runs, with no refusal" \
  '[ $c1 = 0 ] && [ $c2 = 0 ]'
cmd "$three" "git -C $three commit -m x" m3d; c1=$?
cmd "$three" 'git -c core.x=y push' m3e; c2=$?
cmd "$three" 'echo hi; git commit -m x' m3f; c3=$?
check "M3 E3: given the same checkout, when the command is git -C <dir> commit -m x, git -c core.x=y push or echo hi; git commit -m x, then it is refused, as today" \
  '[ $c1 = 2 ] && [ $c2 = 2 ] && [ $c3 = 2 ]'
exit $fail
