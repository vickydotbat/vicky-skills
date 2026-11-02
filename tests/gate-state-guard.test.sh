#!/usr/bin/env bash
# The gate-state guard refuses a message whose first line is the gate line
# when a pull request that line names has already merged or closed, and lets
# every other message through: an open pull request, no reference, a gate
# line below the first, a lookup that fails or hangs, a missing tool, the
# option off. Fake gh and tea answer from files named <owner>_<repo>_<n>.json.
set -euo pipefail

jqpath=$(command -v jq)
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/gate-state-guard.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin" "$scratch/prs"
for forge in gh tea; do
  cat >"$scratch/bin/$forge" <<'FAKE'
#!/usr/bin/env bash
echo "$(basename "$0") $*" >>"$FAKE_LOG"
[[ "${FAKE_HANG:-}" == 1 ]] && sleep 30
[[ "$1" == api ]] || exit 1
f="$FAKE_PRS/$(basename "$0")_$(sed -E 's#^repos/([^/]+)/([^/]+)/pulls/([0-9]+)$#\1_\2_\3#' <<<"$2").json"
[[ -f "$f" ]] || { echo '{"message":"Not Found"}'; exit 1; }
cat "$f"
FAKE
  chmod +x "$scratch/bin/$forge"
done
pr() { # <forge> <owner> <repo> <n> <state> <merged> [time]
  printf '{"state":"%s","merged":%s,"merged_at":"%s","closed_at":"%s"}\n' "$5" "$6" "${7:-}" "${7:-}" >"$scratch/prs/$1_$2_$3_$4.json"
}
pr gh ana skills 84 open false
pr gh ana skills 81 closed true 2026-11-02T10:32:39Z
pr gh ana skills 70 closed false 2026-11-01T09:00:00Z
pr gh ana other 81 open false
pr gh ana other 5 closed true 2026-11-02T08:00:00Z
pr tea team codebase 1466 closed true 2026-11-02T10:36:58Z
pr tea team platform 521 closed true 2026-11-02T10:35:28Z
pr tea team codebase 12 open false

git init -q "$scratch/gh-repo"; git -C "$scratch/gh-repo" remote add origin git@github.com:ana/skills.git
git init -q "$scratch/tea-repo"; git -C "$scratch/tea-repo" remote add origin ssh://git@forge.example:2222/team/codebase.git
mkdir -p "$scratch/plain"

mkdir -p "$scratch/path"
for tool in bash env jq cat grep sed head tr rm ln git timeout sleep basename dirname; do ln -s "$(command -v "$tool")" "$scratch/path/$tool"; done
ln -s "$scratch/bin/gh" "$scratch/path/gh"; ln -s "$scratch/bin/tea" "$scratch/path/tea"
export PATH="$scratch/path" FAKE_PRS="$scratch/prs" FAKE_LOG="$scratch/log" CLAUDE_PLUGIN_OPTION_GUARD_GATE_STATE=true
failed=0

check() { # <name> <want exit> <want in stderr, or empty> <cwd> <message> [tool]
  local payload rc=0 err
  payload=$(jq -nc --arg cwd "$4" --arg m "$5" --arg t "${6:-SendUserMessage}" \
    '{hook_event_name:"PreToolUse",tool_name:$t,cwd:$cwd,tool_input:{message:$m}}')
  err=$(bash "$hook" <<<"$payload" 2>&1 >/dev/null) || rc=$?
  [[ $rc == "$2" ]] || { echo "FAIL $1: exit $rc, wanted $2 ($err)"; failed=1; return 0; }
  if [[ -n "$3" ]]; then
    grep -qF -- "$3" <<<"$err" || { echo "FAIL $1: stderr lacks '$3': $err"; failed=1; }
  elif [[ $2 == 0 && -n "$err" ]]; then
    echo "FAIL $1: spoke on a pass: $err"; failed=1
  fi
  return 0
}
gh=$scratch/gh-repo tea=$scratch/tea-repo
gate='🚪 Waiting on you:'

check "a merged PR is refused" 2 "ana/skills#81 merged at 2026-11-02T10:32:39Z" "$gh" "$gate merge #81"
check "the refusal steers to a re-read" 2 "Re-read the state" "$gh" "$gate merge #81"
check "the refusal names its hook" 2 "gate-state-guard: the gate line names a pull request that is no longer open:" "$gh" "$gate merge #81"
check "a missing folder passes" 0 "" "$scratch/gone" "$gate merge #81"
check "a closed PR is refused" 2 "ana/skills#70 closed at 2026-11-01T09:00:00Z" "$gh" "$gate review #70"
check "an open PR passes" 0 "" "$gh" "$gate merge #84"
check "open and merged: the refusal names the merged one" 2 "ana/skills#81 merged" "$gh" "$gate merge #84, then #81"
out=$(jq -nc --arg cwd "$gh" --arg m "$gate merge #84, then #81" '{tool_name:"SendUserMessage",cwd:$cwd,tool_input:{message:$m}}' | bash "$hook" 2>&1 || true)
grep -q '#84' <<<"$out" && { echo "FAIL the refusal names the open PR: $out"; failed=1; }
check "a repo-named PR on GitHub" 2 "ana/other#5 merged" "$gh" "$gate merge other#5"
check "an owner/repo PR" 2 "ana/other#5 merged" "$gh" "$gate merge ana/other#5"
check "the named repo answers first, so the checkout's PR of that number is never read" 0 "" "$gh" "$gate merge other#81"
check "Gitea !N in the checkout's repo" 2 "team/codebase#1466 merged at 2026-11-02T10:36:58Z" "$tea" "$gate review !1466"
check "Gitea 'repo !N' names a sibling repo" 2 "team/platform#521 merged" "$tea" "$gate review sow-codebase !1466 and platform !521"
check "a word stuck to #N that is no repo falls back to the checkout" 2 "ana/skills#81 merged" "$gh" "$gate merge PR#81"
check "a pulls/N path" 2 "team/codebase#1466 merged" "$tea" "$gate see pulls/1466"
check "a pull request link" 2 "team/platform#521 merged" "$gh" "$gate review https://forge.example/team/platform/pulls/521"
check "a GitHub link" 2 "ana/other#5 merged" "$tea" "$gate merge https://github.com/ana/other/pull/5"
check "an open Gitea PR passes" 0 "" "$tea" "$gate review !12"
check "no reference passes" 0 "" "$gh" "$gate pick a colour"
check "a gate line below the first passes" 0 "" "$gh" "Done.
$gate merge #81"
check "a merged PR in the body below the gate line passes" 0 "" "$gh" "$gate merge #84
#81 merged earlier."
check "an ordinary message passes" 0 "" "$gh" "#81 merged as abc123."
check "another tool passes" 0 "" "$gh" "$gate merge #81" Bash
check "outside a repository a bare #N passes" 0 "" "$scratch/plain" "$gate merge #81"
check "an unknown PR passes" 0 "" "$gh" "$gate merge #999"
: >"$FAKE_LOG"
FAKE_HANG=1 check "a hung lookup passes" 0 "" "$gh" "$gate merge #81"
CLAUDE_PLUGIN_OPTION_GUARD_GATE_STATE=false check "the option off passes" 0 "" "$gh" "$gate merge #81"
CLAUDE_PLUGIN_OPTION_GUARD_GATE_STATE=1 check "the option as 1 is on" 2 "merged" "$gh" "$gate merge #81"
: >"$FAKE_LOG"
CLAUDE_PLUGIN_OPTION_GUARD_GATE_STATE=false check "the option off looks nothing up" 0 "" "$gh" "$gate merge #81"
[[ -s "$FAKE_LOG" ]] && { echo "FAIL the option off still looked up: $(cat "$FAKE_LOG")"; failed=1; }
rm "$scratch/path/gh"
check "gh missing passes" 0 "" "$gh" "$gate merge #81"
ln -s "$scratch/bin/gh" "$scratch/path/gh"
payload=$(jq -nc --arg cwd "$gh" --arg m "$gate merge #81" '{tool_name:"SendUserMessage",cwd:$cwd,tool_input:{message:$m}}')
rm "$scratch/path/jq"
rc=0; bash "$hook" <<<"$payload" 2>/dev/null || rc=$?
[[ $rc == 0 ]] || { echo "FAIL jq missing exits $rc"; failed=1; }
ln -s "$jqpath" "$scratch/path/jq"
rc=0; bash "$hook" <<<'not json' 2>/dev/null || rc=$?
[[ $rc == 0 ]] || { echo "FAIL bad json exits $rc"; failed=1; }

if [[ $failed -eq 0 ]]; then echo "ok   gate-state-guard refuses a gate line that names a merged or closed pull request, nothing else"; fi
exit "$failed"
