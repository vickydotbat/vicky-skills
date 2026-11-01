#!/usr/bin/env bash
# approved-spec: the examples the user set for pr-guard on 2026-11-01: an
# effort keeps one pull request, opened once, so CI runs once. A follow-up
# opens only when it is stacked on the session's open pull request, labelled
# stacked, and that pull request is big enough or the follow-up says it is
# separate work. A stack stays at a few pull requests, and no refusal hands the
# user a command. Each example runs on a GitHub and a Gitea repository, with a
# stand-in forge that lists the session's open pull requests.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pr-guard.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin" "$scratch/data/pr-guard-sessions"
# The stand-in forges list what $OPEN holds: one "head" per open pull request.
cat >"$scratch/bin/gh" <<'FAKE'
#!/usr/bin/env bash
[ "$1 $2" = "pr list" ] || exit 1
n=6; for h in $OPEN; do n=$((n + 1)); printf '{"number":%s,"headRefName":"%s","title":"T"}\n' "$n" "$h"; done | jq -s .
FAKE
cat >"$scratch/bin/tea" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "api user") echo '{"login":"me"}' ;;
  "pulls list") n=6; for h in $OPEN; do n=$((n + 1)); printf '{"index":"%s","head":"%s","author":"me","title":"T"}\n' "$n" "$h"; done | jq -s . ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$scratch/bin/gh" "$scratch/bin/tea"
export PATH="$scratch/bin:$PATH" HOME="$scratch/home" CLAUDE_PLUGIN_DATA="$scratch/data" \
  CLAUDE_PLUGIN_OPTION_GUARD_PR=true CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_MIN_LINES=200 \
  CLAUDE_PLUGIN_OPTION_GUARD_PR_STACK_LIMIT=3
unset CLAUDE_CONFIG_DIR

# A repository on <forge> (hub or gitea) whose session pull requests are the
# branches named after <lines>, each changing that many lines, stacked in
# order, with the work checked out on a new branch above the last.
repo() { # <name> <forge> <lines> <branch>...
  local name=$1 dir="$scratch/$1" forge=$2 lines=$3 url b
  shift 3
  git init -q -b main "$dir"
  git -C "$dir" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init
  [ "$forge" = hub ] && url=https://github.com/o/r.git || url=https://forge.example/o/r.git
  git -C "$dir" remote add origin "$url"
  git -C "$dir" update-ref refs/remotes/origin/main main
  git -C "$dir" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  for b in "$@"; do
    git -C "$dir" switch -q -c "$b"
    seq "$lines" | sed "s|^|$b |" >"$dir/${b//\//-}.txt"
    git -C "$dir" add "${b//\//-}.txt"
    git -C "$dir" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m "$b"
    printf '%s %s\n' "$url" "$b" >>"$scratch/data/pr-guard-sessions/s-$name"
  done
  git -C "$dir" switch -q -c feat/next
}
for forge in hub gitea; do
  repo "big-$forge" $forge 300 feat/one
  repo "small-$forge" $forge 40 feat/one
  repo "full-$forge" $forge 300 feat/one feat/two feat/three
done
git init -q -b main "$scratch/fresh-hub"
git -C "$scratch/fresh-hub" remote add origin https://github.com/o/r.git
git init -q -b main "$scratch/fresh-gitea"
git -C "$scratch/fresh-gitea" remote add origin https://forge.example/o/r.git

# Prints the exit status, then everything the hook said. <repo> is also the
# session, so each repository's record is its own session's.
run() { # <repo> <open heads> <command>
  local out status
  out=$(jq -nc --arg c "$3" --arg d "$scratch/$1" --arg s "s-$1" \
    '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, session_id: $s, tool_input: {command: $c}}' |
    OPEN="$2" bash "$hook" 2>&1)
  status=$?
  printf '%s\n%s' "$status" "$out"
}
# The same pull request, opened with gh on GitHub or tea on Gitea.
create() { # <forge> <flags: base, label, body>
  local base=$2 label=$3 body=$4
  if [ "$1" = hub ]; then
    printf 'gh pr create --title Next --body %q%s%s' "$body" "${base:+ --base $base}" "${label:+ --label $label}"
  else
    printf 'tea pr create --title Next --description %q%s%s' "$body" "${base:+ --base $base}" "${label:+ --labels $label}"
  fi
}
status() { head -1 <<<"$1"; }
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1 ($forge)"; fail=1; fi; }

for forge in hub gitea; do
  r=$(run "big-$forge" feat/one "$(create $forge "" "" "A small fix")")
  check "E1: a minor change goes on the open pull request, and the refusal names its branch" \
    '[ "$(status "$r")" = 2 ] && grep -q "feat/one" <<<"$r"'
  e1=$r

  r=$(run "fresh-$forge" "" "$(create $forge "" "" "The work")")
  check "E2: the first pull request opens" '[ "$(status "$r")" = 0 ]'

  r=$(run "big-$forge" feat/one "$(create $forge feat/one stacked "The next chunk")")
  check "E3: a follow-up stacked on a 300-line pull request, labelled stacked, opens" '[ "$(status "$r")" = 0 ]'

  r=$(run "small-$forge" feat/one "$(create $forge feat/one stacked "The next chunk")")
  check "E4: a follow-up on a 40-line pull request is refused, with a steer to commit on its branch" \
    '[ "$(status "$r")" = 2 ] && grep -q "feat/one" <<<"$r"'
  e4=$r

  r=$(run "small-$forge" feat/one "$(create $forge feat/one stacked "Separate work: a different feature")")
  check "E5: a follow-up that says why it stands apart skips the minimum" '[ "$(status "$r")" = 0 ]'

  r=$(run "big-$forge" feat/one "$(create $forge feat/one "" "The next chunk")")
  check "E6: a stacked follow-up without the stacked label is refused, with a steer to add it" \
    '[ "$(status "$r")" = 2 ] && grep -qi "label" <<<"$r"'
  e6=$r

  r=$(run "full-$forge" "feat/one feat/two feat/three" "$(create $forge feat/three stacked "The next chunk")")
  check "E7: a fourth pull request on a stack of three is refused, with a steer to the top branch" \
    '[ "$(status "$r")" = 2 ] && grep -q "feat/three" <<<"$r"'
  e7=$r

  check "E8: no refusal names a file or command for the user to run" \
    'out=$(printf "%s\n" "$e1" "$e4" "$e6" "$e7"); ! grep -qiE "touch|pr-guard-allow|in (your|their) own terminal|ask the user to (run|create)" <<<"$out"'
done
exit $fail
