#!/usr/bin/env bash
# PreToolUse hook (SendUserMessage): refuses a message whose first line is the
# gate line, "🚪 Waiting on you: <what>", when a pull request that line names
# has already merged or closed. A gate reported from memory once asked the
# user to merge two pull requests she had already merged.
# It reads #N, !N, repo#N, owner/repo#N, "repo !N", pulls/N and pull request
# links. A repo name that doesn't resolve falls back to the checkout's repo.
# It looks each one up with gh on GitHub and tea elsewhere, and lets the
# message through on any lookup it can't finish. Off unless the plugin option
# guard_gate_state is true.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_GATE_STATE:-}" in true | 1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
[[ "$(jq -r '.tool_name // ""' <<<"$payload" 2>/dev/null)" == SendUserMessage ]] || exit 0
first=$(jq -r '.tool_input.message // ""' <<<"$payload" | head -n1)
[[ "$first" == '🚪 Waiting on you:'* ]] || exit 0
cd "$(jq -r '.cwd // "."' <<<"$payload")" 2>/dev/null || exit 0
origin=$(git remote get-url origin 2>/dev/null)
origin=${origin%.git}
rest=${origin%/*}
here="${rest##*[/:]}/${origin##*/}"
forge=tea
[[ "$origin" == *github.com[:/]* ]] && forge=gh

# state <forge> <owner/repo> <n> prints "open", "merged at T" or "closed at T",
# and fails when the lookup does.
state() {
  json=$(timeout 3 "$1" api "repos/$2/pulls/$3" </dev/null 2>/dev/null) || return 1
  jq -er 'if .merged == true then "merged at \(.merged_at)" elif .state == "closed" then "closed at \(.closed_at)" elif .state == "open" then "open" else empty end' <<<"$json" 2>/dev/null
}
hits=""
# look <forge> <n> <owner/repo>...: the first repo that answers decides.
look() {
  local f=$1 n=$2 r s
  for r in "${@:3}"; do
    s=$(state "$f" "$r" "$n") || continue
    [[ $s == open || $hits == *"$r#$n "* ]] || hits+="  $r#$n $s"$'\n'
    return
  done
}

while read -r host path n; do
  f=tea
  [[ $host == github.com ]] && f=gh
  look "$f" "$n" "$path"
done < <(grep -oE 'https?://[^ /]+/[^ /]+/[^ /]+/pulls?/[0-9]+' <<<"$first" | sed -E 's#^https?://([^/]+)/([^/]+/[^/]+)/pulls?/([0-9]+)$#\1 \2 \3#')

line=$(sed -E 's#https?://[^ ]+##g' <<<"$first")
if [[ -n "$origin" ]]; then
  for m in $(grep -oE 'pulls/[0-9]+' <<<"$line"); do look "$forge" "${m#pulls/}" "$here"; done
  while read -r m; do
    n=${m##*[#!]}
    pre=${m%[#!]*}
    pre=${pre% }
    case $pre in
      */*) look "$forge" "$n" "$pre" "$here" ;;
      ?*) look "$forge" "$n" "${here%/*}/$pre" "$here" ;;
      *) look "$forge" "$n" "$here" ;;
    esac
  done < <(sed -E 's#pulls/[0-9]+##g' <<<"$line" | grep -oE '([A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)? ?)?[#!][0-9]+')
fi

[[ -n "$hits" ]] || exit 0
{
  echo "gate-state-guard: the gate line names a pull request that is no longer open:"
  printf '%s' "$hits"
  echo "Re-read the state of each pull request you name, then report the merge in place of the gate, or name only what still waits."
} >&2
exit 2
